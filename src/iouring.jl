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
const IO_URING_TRANSFER_REQUEST = unsigned(1 << 62)

io_uring_poll_key(fd) = unsigned(IO_URING_POLL_REQUEST |
                                 Base.cconvert(Cint, fd.fd))

io_uring_transfer_key(fd) = unsigned(IO_URING_TRANSFER_REQUEST |
                                     Base.cconvert(Cint, fd.fd))

io_uring_key_fd(key) = unsafe_trunc(Cint, key)

#FIXME what if two tasks are waiting for the same file descriptor.
# (possibly from two different UnixIO.FD objects).
# Need to handle this in `q.dict` ?

"""
Register `fd` to wake up `io_uring_wait_cqe` on `event`:
"""
@db 4 function register_for_events(q::IOURingQueue, fd)
    key = io_uring_poll_key(fd)
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
    key = io_uring_poll_key(fd)
    @dblock q.ring_lock begin
        sqe = io_uring_get_sqe(q.ring)
        @assert sqe != C_NULL
        io_uring_prep_cancel64(sqe, key, 0)
        sqe.user_data = 0
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
    
    if user_data == 0 || res == -C.ECANCELED
        # Ignore cancelation requests and canceled requests
    elseif res ∈ (-C.ENOENT, -C.EALREADY)
        @show res, user_data
        @assert false
        @db 1 "io_uring_wait_cqe -> $(errname(-res))" res user_data
    elseif res < 0
        msg = "io_uring_cqe.res = $res"
        @db 1 msg res user_data
        systemerror(msg, 0 - res)
    else
        fd = get_weak_fd(io_uring_key_fd(user_data))
        if fd == nothing
            @db 1 "⚠️ fd not found" res user_data
#            @error "Ignoring io_uring_wait_cqe() notification " *
#                   "for unknown FD (already deleted?)." res user_data
        elseif user_data & IO_URING_POLL_REQUEST != 0
            if (@atomic fd.nwaiting) > 0
                f(res, fd)
            end
        elseif user_data & IO_URING_TRANSFER_REQUEST != 0
            @db 2 "read $(res) -> notify($fd)"
            @dblock fd.ready notify(fd.ready, res);
            # Wake: `raw_transfer(fd, ::IOURingTransfer, ...)`
        else
            @assert false
        end
    end
end


function raw_transfer(fd, ::TransferAPI{:IOURing}, ::Out, buf, count)
    # FIXME
    C.write(fd, buf, count)
end


@inline @db 1 function raw_transfer(fd, ::TransferAPI{:IOURing},
                                    dir::AnyDirection, buf, fd_offset, count)
    if ismissing(fd_offset)
        fd_offset = unsigned(-1)
    end

#FIXME  test for multiple waiting readers on single FD - io_uring async transfer

    @dblock fd.ready begin

        @dblock io_uring_queue.ring_lock begin
            sqe = io_uring_get_sqe(io_uring_queue.ring)
            if dir == In()
                io_uring_prep_read(sqe, fd, buf, count, fd_offset);
            else
                io_uring_prep_write(sqe, fd, buf, count, fd_offset);
            end
            sqe.user_data = io_uring_transfer_key(fd)
            n = io_uring_submit(io_uring_queue.ring)
            # FIXME don't share ring between threads
            # https://github.com/axboe/liburing/issues/109#issuecomment-1166378978
            @assert n == 1 || n < 0
            n == 1 || systemerror("io_uring_submit()", 0 - n)
        end

        @db return wait(fd.ready)
    end
end
