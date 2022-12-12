"""
# Polling
"""

"""
Global queue of file descriptors to poll.

`register_for_events()` puts new FDs in `fd_new`.

`poll_task()` calls `poll_wait(::PollQueue)`.

`poll_wait(::PollQueue)` copies new FDs from `fd_new` to `poll_vector`
then passes `poll_vector` (containing C `struct pollfd`s) to
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html) to wait
for IO activity.

`register_for_events()` uses `wakeup_pipe` to wake `poll(2)` when there is
a new FD waiting in `fd_new`.
"""
struct PollQueue
    fd_new::Channel{FD}
    fd_del::Channel{FD}
    fd_vector::Vector{FD}
    poll_vector::Vector{C.pollfd}
    wakeup_pipe::Vector{Cint}
end

const poll_queue = PollQueue(Channel{FD}(Inf),
                             Channel{FD}(Inf),
                             [],
                             [],
                             [])


@db function poll_queue_init()

    # Pipe for asking `poll(2)` to return before timeout.
    copy!(poll_queue.wakeup_pipe, wakeup_pipe())
    fd = poll_queue.wakeup_pipe[1]
    push!(poll_queue.poll_vector, C.pollfd(fd, C.POLLIN, 0))
    push!(poll_queue.fd_vector, FD{In}(fd))

    # Global Task to run `poll(2)`.
    Threads.@spawn poll_task(poll_queue)              ;@db "@spawn poll_task()"

    if Sys.islinux()
        epoll_queue_init()
        io_uring_queue_init()
    end
end

function wakeup_pipe()
    wakeup_pipe = fill(Cint(-1), 2)
    @cerr C.pipe(wakeup_pipe)
    for fd in wakeup_pipe
        fcntl_setfl(fd, C.O_NONBLOCK)
    end
    return wakeup_pipe
end


"""
Write a byte to the pipe to wake up `poll(2)` before its timeout.
"""
function wakeup_poll(q::PollQueue);                       @db 3 "wakeup_poll()"
    @cerr C.write(q.wakeup_pipe[2], Ref(0), 1)
    nothing
end


"""
Wait for an event to occur on `fd`.
"""
@db 2 function wait_for_event(queue, fd::FD; deadline=Inf)
    assert_havelock(fd)

#    @info "wait_for_event" fd

    timer = register_timer(deadline) do
        @dblock fd notify(fd, :timeout)
    end
    fd.nwaiting += 1
    event = try
        register_for_events(queue, fd)
        @db 2 "$(fd.nwaiting) waiting for $fd..."
        wait(fd.ready) # Wait for: `poll_task()`
    finally
        close(timer)
        @assert fd.nwaiting > 0
        fd.nwaiting -= 1
        if fd.nwaiting == 0
            unregister_for_events(queue, fd)
        end
    end
    @db 2 return event "Ready: $fd"
end


@db 4 function register_for_events(q::PollQueue, fd)
    put!(q.fd_new, fd)
    wakeup_poll(q)                                           ;@db 5 poll_queue
end


@db 4 function unregister_for_events(q::PollQueue, fd)
    put!(q.fd_del, fd)
    wakeup_poll(q)
end


"""
Run `poll_wait()` in a loop.
"""
@db 1 function poll_task(q)

    if Threads.threadid() == 1
        @warn "UnixIO.poll_task() is running on thread No. 1!\n" *
              "Other Tasks on thread 1 may be blocked for up to 100ms while " *
              "poll_task() is waiting for IO.\n" *
              "Consider increasing JULIA_NUM_THREADS (`julia --threads N`)."

        timeout_ms = 100
    else
        timeout_ms = 60_000
    end

    while true
        try
            poll_wait(q, timeout_ms) do events, fd
                if events & (C.POLLHUP | C.POLLNVAL) != 0
                    fd.gothup = true
                    @db 1 "$(db_c(events,"POLL")) -> $fd 💥"
                end
                if fd.nwaiting <= 0
                    @db 1 "$(db_c(events,r"POLL[A-Z]")) -> $fd None Waiting!"
                else
                    @db 2 "$(db_c(events,r"POLL[A-Z]")) -> notify($fd)"
                    @dblock fd notify(fd, events); # Wake: `wait_for_event()`
                end
            end
        catch err
            notify_error(q, err)
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        yield()
    end
    @assert false
end


function notify_error(q::PollQueue, err)
    for fd in q.fd_vector
        @lock fd.ready Base.notify_error(fd.ready, err)
    end
end


gc_safe_poll(fds, nfds, timeout_ms) = @gc_safe C.poll(fds, nfds, timeout_ms)


"""
- Update `poll_vector` based on `fd_del` and `fd_new`.
- Wait for events.
- Call `f(events, fd)` for each event.
"""
@db 4 function poll_wait(f::Function, q::PollQueue, timeout_ms::Int)

    fdv = q.fd_vector                                         
    pollv = q.poll_vector                                         
    timeout_ms = next_timer_deadline_ms(timeout_ms)
    @db 4 " [ poll($timeout_ms ms)..."

    # Remove old entries from fd_vector and poll_vector.
    while !isempty(q.fd_del)
        fd = take!(q.fd_del)
        i = findfirst(isequal(fd), fdv)
        if i != nothing                                        ;@db 4 "del $fd"
            deleteat!(pollv, i)
            deleteat!(fdv, i)
        end
    end

    # Add new entries to fd_vector and poll_vector.
    while !isempty(q.fd_new)
        fd = take!(q.fd_new)                                   ;@db 4 "add $fd"
        pushfirst!(fdv, fd)
        pushfirst!(pollv, C.pollfd(fd, poll_event_type(fd), 0))
    end

    # Wait for events
    n = @cerr(allow=C.EINTR,
              gc_safe_poll(pollv, length(pollv), timeout_ms))          ;@db 5 n
                                                                   ;@db 4 pollv
    # Check poll vector for events.
    indexes_to_delete = Int[]
    for (i, e) in enumerate(pollv)
        if e.revents != 0
            if e.fd == q.wakeup_pipe[1]
                C.read(q.wakeup_pipe[1], Ref(0), 1)        ;@db 4 "got wakeup!"
            else
                push!(indexes_to_delete, i)
                @assert RawFD(e.fd) == fdv[i].fd
                f(e.revents, fdv[i])
            end
        end
    end
    deleteat!(pollv, indexes_to_delete)           ;@db 6 indexes_to_delete pollv
    deleteat!(fdv, indexes_to_delete)

    # Check for timeouts.
    notify_timers()
    nothing
end

poll_event_type(::FD{In}) = C.POLLIN
poll_event_type(::FD{Out}) = C.POLLOUT

# Linux io_uring(7)
# https://manpages.debian.org/unstable/liburing-dev/io_uring.7.en.html
#
# FIXME see : https://discourse.julialang.org/t/io-uring-support/48666

if Sys.islinux()

using LibURing
using LibURing:
    io_uring_submit,
    io_uring_get_sqe,
    io_uring_prep_read,
    io_uring_prep_write,
    io_uring_prep_poll_add,
    io_uring_prep_poll_multishot,
    io_uring_prep_poll_remove,
    io_uring_wait_cqe,
    io_uring_cqe_seen

gc_safe_io_uring_wait_cqe(ring, cqe) = 
    @gc_safe io_uring_wait_cqe(ring, cqe)

mutable struct IOURingQueue
    ring::Ref{LibURing.io_uring}
    dict::Dict{Int,FD}
    lock::Threads.SpinLock
end

const io_uring_queue = IOURingQueue(Ref{LibURing.io_uring}(),
                                    Dict{Int,FD}(),
                                    Threads.SpinLock())

@db function io_uring_queue_init()

    LibURing.io_uring_queue_init(10 #= Queue depth =#, io_uring_queue.ring, 0);
    
    Threads.@spawn io_uring_task(io_uring_queue)
end


@db 4 function _io_uring_read(q::IOURingQueue, fd)

    sqe = io_uring_get_sqe(q.ring)
#    io_uring_prep_read(sqe, fd.fd<
#                        void *buf,
#                        unsigned nbytes,
#                        __u64 offset);
#
#
end

const IO_URING_POLL_REQUEST = (1 << 63)
const IO_URING_READ_REQUEST = (1 << 62)

#FIXME what if two tasks are waiting for the same file descriptor.
# (possibly from two different UnixIO.FD objects).
# Need to handle this in `q.dict` ?

"""
Register `fd` to wake up `io_uring_wait_cqe` on `event`:
"""
@db 4 function register_for_events(q::IOURingQueue, fd)
    fdkey = IO_URING_POLL_REQUEST | Base.cconvert(Cint, fd.fd)
    @dblock q.lock begin
        if !haskey(q.dict, fdkey)
            q.dict[fdkey] = fd
            sqe = io_uring_get_sqe(q.ring)
            @assert sqe != C_NULL
            #io_uring_prep_poll_multishot(sqe, fd.fd, poll_event_type(fd))
            io_uring_prep_poll_add(sqe, fd.fd, poll_event_type(fd))
            sqe.user_data = fdkey
            n = io_uring_submit(q.ring)
            n == 1 || systemerror("io_uring_prep_poll_multishot()", 0 - n)
        else
            @db 2 "Already registered!"
        end
    end
end

@db 4 function unregister_for_events(q::IOURingQueue, fd)
    fdkey = IO_URING_POLL_REQUEST | Base.cconvert(Cint, fd.fd)
    @dblock q.lock begin
        # FIXME if haskey(q.dict, fd.fd)
            delete!(q.dict, fdkey)
            # FIXME sqe = io_uring_get_sqe(q.ring)
            # FIXME @assert sqe != C_NULL
            # FIXME p = Ptr{Nothing}(UInt(Base.cconvert(Cint, fd.fd)))
            # FIXME io_uring_prep_poll_remove(sqe, p)
            # FIXME n = io_uring_submit(q.ring)
            # FIXME n == 1 || systemerror("io_uring_prep_poll_remove()", 0 - n)
        # FIXME end
    end
end
    

@db 1 function io_uring_task(q)

    if Threads.threadid() == 1
        @warn "UnixIO.io_uring_task() is running on thread No. 1!\n" *
              "Other Tasks on thread 1 may be blocked for up to 100ms while " *
              "poll_task() is waiting for IO.\n" *
              "Consider increasing JULIA_NUM_THREADS (`julia --threads N`)."

        timeout_ms = 100
    else
        timeout_ms = 60_000
    end

    while true
        try
            cqe = Ref{Ptr{LibURing.io_uring_cqe}}()
            @cerr gc_safe_io_uring_wait_cqe(q.ring, cqe)
            cqe_copy = unsafe_load(cqe[])
            try
                if cqe_copy.res ∈ (-C.ENOENT, -C.ECANCELED, -C.EALREADY)
                    @db 1 "io_uring_wait_cqe -> $(errname(-cqe_copy.res))" cqe_copy
                    continue
                elseif cqe_copy.res < 0
                    msg = "io_uring_cqe.res = $(cqe_copy.res)"
                    @db 1 msg cqe_copy
                    systemerror(msg, 0 - cqe_copy.res)
                else
                    fd = nothing
                    @dblock q.lock begin
                        fd = get(q.dict, cqe_copy.user_data, nothing)
                    end
                    if fd == nothing
                        # FIXME ????
#                        @error "Ignoring io_uring_wait_cqe() notification " *
#                               "for unknown FD (already deleted?)." events rawfd
                    elseif cqe_copy.user_data & IO_URING_POLL_REQUEST != 0
                        events = cqe_copy.res
                        if events & (C.POLLHUP | C.POLLNVAL) != 0
                            fd.gothup = true
                            @db 1 "$(db_c(events,"POLL")) -> $fd 💥"
                        end
                        if events == 0
                            @db 1 "io_uring_wait_cqe -> cqe_copy.res == 0"
                        elseif fd.nwaiting <= 0
                            @db 1 "$(db_c(events,r"POLL[A-Z]")) -> $fd None Waiting!"
                        else
                            @db 2 "$(db_c(events,r"POLL[A-Z]")) -> notify($fd)"
                            @dblock fd notify(fd, events); # Wake: `wait_for_event()`
                        end
                    elseif cqe_copy.user_data & IO_URING_READ_REQUEST != 0
                        @db 2 "read $(cqe_copy.res) -> notify($fd)"
                        @dblock fd notify(fd, cqe_copy.res);
                        # Wake: `raw_transfer(fd, ::IOURingTransfer, ...)`
                    end
                end
            finally
                io_uring_cqe_seen(q.ring, cqe[]);
            end
        catch err
            notify_error(q, err)
            exception=(err, catch_backtrace())
            @error "Error in io_uring_task()" exception
        end
        yield()
    end
    @assert false
end

function notify_error(q::IOURingQueue, err)
    #FIXME ??
    @dblock q.lock begin
        for fd in values(q.dict)
            @lock fd Base.notify_error(fd.ready, err)
        end
    end
end


end # if Sys.islinux()



# Linux epoll(7)             https://man7.org/linux/man-pages/man7/epoll.7.html

if Sys.islinux()

"""
See PollQueue above.
"""
mutable struct EPollQueue
    fd::RawFD
    dict::Dict{RawFD,FD}
    cvector::Vector{C.epoll_event}
    lock::Threads.SpinLock
end

const epoll_queue = EPollQueue(RawFD(-1),
                               Dict{RawFD,FD}(),
                               Vector{C.epoll_event}(undef, 10),
                               Threads.SpinLock())

@db function epoll_queue_init()

    #=
    @assert Sys.ARCH != :x86_64 """
        FIXME: UnixIO does not support epoll on x86_64 because
        `struct epoll_event` has `__attribute__((packed))` on x86.
        See https://git.io/JCGMK and https://git.io/JCGDz
        This is not difficult to work around but is not handled yet.
    """
    =#
    @assert C.EPOLLIN == C.POLLIN
    @assert C.EPOLLOUT == C.POLLOUT
    @assert C.EPOLLHUP == C.POLLHUP

    # Global FD interface to Linux epoll(7).
    epoll_queue.fd = RawFD(@cerr C.epoll_create1(C.EPOLL_CLOEXEC))

    # Global Task to run `epoll_wait(7)`.
    Threads.@spawn poll_task(epoll_queue)
end



"""
Add, modify or delete epoll target FDs.
See [epoll_ctl(7)(https://man7.org/linux/man-pages/man7/epoll_ctl.7.html)
"""
@db 4 function epoll_ctl(fd, op, events=0, data=fd; allow=())
                                                  @db 4 fd db_c(op,"EPOLL_CTL")
    e = Ref{C.epoll_event}()
    p = Base.unsafe_convert(Ptr{C.epoll_event}, e)
    GC.@preserve e begin
        p.events = events
        p.data.fd = fd
        @cerr(allow=allow, C.epoll_ctl(epoll_queue.fd, op, fd, p))
    end
end

epoll_ctl(fd::FD, op, events=0; kw...) =
    epoll_ctl(convert(Cint, fd), op, events; kw...)


"""
Register `fd` to wake up `epoll_wait(7)` on `event`:
"""
@db 4 function register_for_events(q::EPollQueue, fd)
    @dblock q.lock begin
        if !haskey(q.dict, fd.fd)
            q.dict[fd.fd] = fd
            epoll_ctl(fd, C.EPOLL_CTL_ADD, poll_event_type(fd))
        else
            @db 2 "Already registered!"
        end
    end
end

@db 4 function unregister_for_events(q::EPollQueue, fd)
    @dblock q.lock begin
        if haskey(q.dict, fd.fd)
            delete!(q.dict, fd.fd)
            epoll_ctl(fd, C.EPOLL_CTL_DEL)#; allow=C.ENOENT)
        end
    end
end


"""
Call `epoll_wait(7)` to wait for events.
Call `f(events, fd)` for each event.
"""
@db 4 function poll_wait(f::Function, q::EPollQueue, timeout_ms::Int)
    v = q.cvector                                                 ;@db 6 q.dict
    n = @cerr(allow=C.EINTR,
              gc_safe_epoll_wait(q.fd, v, length(v), timeout_ms))    ;@db 6 n v
    if n >= 0
        for i in 1:n
            p = pointer(v, i)
            fd = nothing
            @dblock q.lock begin
                fd = get(q.dict, RawFD(unsafe_load(p.data.fd)), nothing) ;@db 6 i fd
            end
            if fd == nothing
                @error "Ignoring epoll_wait() notification v[$i] = $(v[i]) " *
                       "for unknown FD (already deleted?)." v[i] q.dict
            else
                unregister_for_events(q, fd)
                f(unsafe_load(p.events), fd)
            end
        end
    end
    nothing
end


function notify_error(q::EPollQueue, err)
    @dblock q.lock begin
        for fd in values(q.dict)
            @lock fd Base.notify_error(fd.ready, err)
        end
    end
end


gc_safe_epoll_wait(epfd, events, maxevents, timeout_ms) = 
    @gc_safe C.epoll_wait(epfd, events, maxevents, timeout_ms)

end # if Sys.islinux()


# Pretty Printing.


Base.show(io::IO, fd::C.pollfd) =
    print(io, "(", fd.fd, ", ", fd.events, ", ", fd.revents, ")")


Base.show(io::IO, q::PollQueue) =
    dbprint(io, "(", q.fd_vector, ", ", q.poll_vector, ")")



# End of file: poll.h
