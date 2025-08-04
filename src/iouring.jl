"""
# Polling
"""


# Linux io_uring(7)
# https://manpages.debian.org/unstable/liburing-dev/io_uring.7.en.html
#
# FIXME see : https://discourse.julialang.org/t/io-uring-support/48666

using LibURing
using LibURing:
    io_uring_submit,
    io_uring_get_sqe,
    io_uring_prep_read,
    io_uring_prep_write,
    io_uring_prep_poll_add,
    io_uring_prep_cancel64,
    io_uring_wait_cqe,
    io_uring_cqe_seen

gc_safe_io_uring_wait_cqe(ring, cqe) = 
    @gc_safe io_uring_wait_cqe(ring, cqe)

mutable struct IOURingQueue
    ring::Ref{LibURing.io_uring}
    ring_lock::Threads.SpinLock
end

const io_uring_queue = IOURingQueue(Ref{LibURing.io_uring}(),
                                    Threads.SpinLock())

@db function io_uring_queue_init()

    LibURing.io_uring_queue_init(10 #= Queue depth =#, io_uring_queue.ring, 0);
    
    Threads.@spawn poll_task(io_uring_queue)
end

IOTraits._wait(fd::FD, ::WaitAPI{:IOURing}; deadline=Inf) =
    wait_for_event(io_uring_queue, fd; deadline)

const IO_URING_POLL_REQUEST = unsigned(1 << 63)
const IO_URING_OBJREF_REQUEST = unsigned(1 << 62)
const IO_URING_CANCEL_REQUEST = unsigned(1 << 61)
const IO_URING_KEY_MASK = ~(IO_URING_POLL_REQUEST |
                            IO_URING_OBJREF_REQUEST |
                            IO_URING_CANCEL_REQUEST)

function io_uring_key(key_flag, key_data)
    p = UInt64(pointer_from_objref(key_data))
    @assert (p & IO_URING_KEY_MASK) == p
    unsigned(key_flag | p)
end
                           

function io_uring_key_fd(key)
    @assert "not used ?"
    p = user_data & IO_URING_KEY_MASK
    unsafe_pointer_to_objref(Ptr{Nothing}(p))
end

#FIXME what if two tasks are waiting for the same file descriptor.
# (possibly from two different UnixIO.FD objects).
# Need to handle this in `q.dict` ?

"""
Register `fd` to wake up `io_uring_wait_cqe` on `event`:
"""
@db 4 function register_for_events(q::IOURingQueue, fd)
    #FIXME hack...
    if (@atomic fd.state) == FD_READY
        sleep(0.1)
    end

    @fd_state fd (FD_READY, FD_TIMEOUT, FD_IDLE) => FD_WAITING
    key = io_uring_key(IO_URING_POLL_REQUEST, fd)
    @dblock q.ring_lock begin
        sqe = io_uring_get_sqe(q.ring)
        @assert sqe != C_NULL
        io_uring_prep_poll_add(sqe, fd.fd, poll_event_type(fd))
        sqe.user_data = key
        n = io_uring_submit(q.ring)
        @assert n == 1 || n < 0
        n == 1 || systemerror("io_uring_prep_poll_add()", 0 - n)
    end
    nothing
end


@db 4 function unregister_for_events(q::IOURingQueue, fd)
    assert_havelock(fd.ready)
    # FIXME this logic is duplicated in poll.jl -- need a shared layer?
    old_state, ok = @atomicreplace fd.state FD_WAITING => FD_CANCELLING
    if old_state == FD_READY
        @fd_state fd FD_READY => FD_CANCELED
    else
        key = io_uring_key(IO_URING_POLL_REQUEST, fd)
        io_uring_cancel(q, key)
        #debug_write("IOUring: unregister_for_events($fd) waiting for cancelation...\n")
        res = wait(fd.ready)
        #debug_write("IOUring: unregister_for_events($fd) done: $res\n")
    end
    nothing
end


function io_uring_cancel(q::IOURingQueue, key_to_cancel::UInt64)
    p = key_to_cancel & IO_URING_KEY_MASK
    request_key = p | IO_URING_CANCEL_REQUEST;
    @dblock q.ring_lock begin
        sqe = io_uring_get_sqe(q.ring)
        @assert sqe != C_NULL
        io_uring_prep_cancel64(sqe, key_to_cancel, 0)
        sqe.user_data = request_key
        n = io_uring_submit(q.ring)
        @assert n == 1 || n < 0
        n == 1 || systemerror("io_uring_prep_cancel64()", 0 - n)
    end
    nothing
end
    

@db 4 function poll_wait(f::Function, q::IOURingQueue, timeout_ms::Int)
    #FIXME timeout_ms is ignored
    cqeref = Ref{Ptr{LibURing.io_uring_cqe}}()
    n = gc_safe_io_uring_wait_cqe(q.ring, cqeref)
    n == 0 || systemerror("io_uring_wait_cqe()", 0 - n)
    cqe = cqeref[]
    res = unsafe_load(cqe.res)
    user_data = unsafe_load(cqe.user_data)
    io_uring_cqe_seen(q.ring, cqe)

    if (user_data & ~IO_URING_KEY_MASK) ∉ (IO_URING_OBJREF_REQUEST,
                                           IO_URING_POLL_REQUEST,
                                           IO_URING_CANCEL_REQUEST)
        error("IOURing: unrecognised CQE user_data!")
    end
    p = user_data & IO_URING_KEY_MASK
    user_obj = unsafe_pointer_to_objref(Ptr{Nothing}(p))

    # FIXME needed ? or handled by poll_task()?
    #if res == -C.ECANCELED
    #    @fd_state fd FD_CANCELLING => FD_CANCELED
    #end

    if user_data & IO_URING_OBJREF_REQUEST != 0
#        debug_write("IOUring poll_wait(): objref res = $res $(constant_name(-res; prefix="E")) $user_obj\n")
        @dblock user_obj notify(user_obj, res);
    elseif user_data & IO_URING_POLL_REQUEST != 0
#        debug_write("IOUring poll_wait(): poll request ! $res\n")
        f(res, user_obj)
    elseif user_data & IO_URING_CANCEL_REQUEST != 0
        if res ∈ (0, -C.ENOENT)
            #debug_write("IOUring poll_wait(): canceled! $user_obj\n")
            #@dblock user_obj notify(user_obj, :canceled)
        elseif res == -C.EALREADY
            fd = user_obj
            @fd_state fd FD_CANCELLING => FD_WAITING
            #debug_write("IOUring poll_wait(): cancel failed EALREADY ($res) $user_obj\n");
            #@dblock user_obj notify(user_obj, :not_canceled)
        else
            msg = "io_uring_prep_cancel64() -> io_uring_cqe.res = $res"
            @db 1 msg res user_data
            systemerror(msg, 0 - res)
        end
    else
        @assert false
    end
end


@inline @db 1 function raw_transfer(fd, ::TransferAPI{:IOURing},
                                    dir::AnyDirection, buf, fd_offset, count,
                                    deadline)
    if ismissing(fd_offset)
        fd_offset = unsigned(-1)
    end

    #FIXME  test for multiple waiting readers on single FD - io_uring async transfer

    # FIXME don't share ring between threads ?
    # https://github.com/axboe/liburing/issues/109#issuecomment-1166378978
    # https://github.com/axboe/liburing/issues/926#issuecomment-1686678750
    #
    @fd_state fd FD_IDLE => FD_TRANSFERING

    res = nothing

    t0 = time()

    GC.@preserve fd @dblock fd.ready try

        key = io_uring_key(IO_URING_OBJREF_REQUEST, fd)
        
        timer = register_timer(deadline) do
            @dblock fd.ready notify(fd.ready, nothing)
        end

        @dblock io_uring_queue.ring_lock begin
            sqe = io_uring_get_sqe(io_uring_queue.ring)
            if dir == In()
                io_uring_prep_read(sqe, fd, buf, count, fd_offset);
            else
                io_uring_prep_write(sqe, fd, buf, count, fd_offset);
            end
            sqe.user_data = key
            n = io_uring_submit(io_uring_queue.ring)
            @assert n == 1 || n < 0
            n == 1 || systemerror("io_uring_submit()", 0 - n)
        end

        try 
            res = wait(fd.ready)
            if !isnothing(res) && res < 0
                errno(-res)
                res = Cint(-1)
            end

        finally
            if res == nothing
                assert_havelock(fd.ready)
                @fd_state fd FD_TRANSFERING => FD_CANCELLING
                io_uring_cancel(io_uring_queue, key)
                #debug_write("IOUring: raw_transfer($fd) waiting for cancelation...\n")
                res = wait(fd.ready)
                #debug_write("IOUring: raw_transfer($fd) " *
                #            "res=$res $(typeof(res)) $(time() -t0)\n")
                if fd.state == FD_CANCELED
                    res = Cint(-1)
                    errno(-C.ECANCELED)
                end
#                FIXME test case for cancelation 
#                @fd_state fd FD_CANCELED => FD_IDLE
            end
        end

    finally
        # FIXME hack
        @atomic fd.state = FD_IDLE
    end

    @ensure fd.state == FD_IDLE
    @ensure res isa Cint
    @db 1 return res
end
