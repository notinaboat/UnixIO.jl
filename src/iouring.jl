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
    io_uring_wait_cqe,
    io_uring_cqe_seen

gc_safe_io_uring_wait_cqe(ring, cqe) = 
    @gc_safe io_uring_wait_cqe(ring, cqe)

mutable struct IOURingQueue
    ring::Ref{LibURing.io_uring}
    dict::Dict{UInt,FD}
    lock::Threads.SpinLock
end

const io_uring_queue = IOURingQueue(Ref{LibURing.io_uring}(),
                                    Dict{UInt,FD}(),
                                    Threads.SpinLock())

waiting_fds(q::IOURingQueue) = @dblock q.lock collect(values(q.dict))

@db function io_uring_queue_init()

    LibURing.io_uring_queue_init(10 #= Queue depth =#, io_uring_queue.ring, 0);
    
    Threads.@spawn poll_task(io_uring_queue)
end


const IO_URING_POLL_REQUEST = unsigned(1 << 63)
const IO_URING_TRANSFER_REQUEST = unsigned(1 << 62)

io_uring_poll_key(fd) = unsigned(IO_URING_POLL_REQUEST |
                                 Base.cconvert(Cint, fd.fd))

io_uring_transfer_key(fd) = unsigned(IO_URING_TRANSFER_REQUEST |
                                     Base.cconvert(Cint, fd.fd))

#FIXME what if two tasks are waiting for the same file descriptor.
# (possibly from two different UnixIO.FD objects).
# Need to handle this in `q.dict` ?

"""
Register `fd` to wake up `io_uring_wait_cqe` on `event`:
"""
@db 4 function register_for_events(q::IOURingQueue, fd)
    key = io_uring_poll_key(fd)
    @dblock q.lock begin
        if !haskey(q.dict, key)
            q.dict[key] = fd
            sqe = io_uring_get_sqe(q.ring)
            @assert sqe != C_NULL
            io_uring_prep_poll_add(sqe, fd.fd, poll_event_type(fd))
            sqe.user_data = key
            n = io_uring_submit(q.ring)
            n == 1 || systemerror("io_uring_prep_poll_add()", 0 - n)
        else
            @db 2 "Already registered!"
        end
    end
end


@db 4 function unregister_for_events(q::IOURingQueue, fd)
    @dblock q.lock delete!(q.dict, io_uring_poll_key(fd))
end
    

@db 4 function poll_wait(f::Function, q::IOURingQueue, timeout_ms::Int)
    cqeref = Ref{Ptr{LibURing.io_uring_cqe}}()
    @cerr gc_safe_io_uring_wait_cqe(q.ring, cqeref)
    cqe = cqeref[]
    res = unsafe_load(cqe.res)
    user_data = unsafe_load(cqe.user_data)
    io_uring_cqe_seen(q.ring, cqe)
    
    if res ∈ (-C.ENOENT, -C.ECANCELED, -C.EALREADY)
        @db 1 "io_uring_wait_cqe -> $(errname(-res))" res user_data
    elseif res < 0
        msg = "io_uring_cqe.res = $res"
        @db 1 msg res user_data
        systemerror(msg, 0 - res)
    else
        fd = nothing
        @dblock q.lock begin
            fd = get(q.dict, user_data, nothing)
        end
        if fd == nothing
            @db 1 "⚠️ fd not found" res user_data
#            @error "Ignoring io_uring_wait_cqe() notification " *
#                   "for unknown FD (already deleted?)." res user_data
        elseif user_data & IO_URING_POLL_REQUEST != 0
            f(res, fd)
        elseif user_data & IO_URING_TRANSFER_REQUEST != 0
            @db 2 "read $(res) -> notify($fd)"
            @dblock fd notify(fd, res);
            # Wake: `raw_transfer(fd, ::IOURingTransfer, ...)`
        end
    end
end


function raw_transfer(fd, ::IOURingTransfer, ::Out, buf, count)
    # FIXME
    C.write(fd, buf, count)
end


@db 1 function raw_transfer(fd, ::IOURingTransfer, ::In,  buf, count)

    key = io_uring_transfer_key(fd)

    @dblock io_uring_queue.lock begin
        @require !haskey(io_uring_queue.dict, key)
        io_uring_queue.dict[key] = fd
    end

    try
        sqe = io_uring_get_sqe(io_uring_queue.ring)
        io_uring_prep_read(sqe, fd, buf, count, unsigned(-1) #= offset =#);
        sqe.user_data = key
        n = io_uring_submit(io_uring_queue.ring)
        n == 1 || systemerror("io_uring_prep_read()", 0 - n)

        @db return @dblock fd wait(fd.ready)

    finally
        @dblock io_uring_queue.lock delete!(io_uring_queue.dict, key)
    end
end
