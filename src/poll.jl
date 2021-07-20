"""
# Polling
"""

const MAX_POLL_FD_COUNT = 1000

"""
Global queue of file descriptors to poll.

`register_for_events()` puts new FDs in `set`.

`poll_task()` calls `poll_wait(::PollQueue)`.

`poll_wait(::PollQueue)` passes `cvector` (containing C `struct pollfd`s) to
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html) to wait
for IO activity.

`register_for_events()` uses `wakeup_pipe` to wake `poll(2)` when there is
a new FD to wait for.
"""
mutable struct PollQueue
    set::Set{UnixFD}
    fdvector::Vector{C.pollfd}
    wakeup_pipe::Vector{Cint}
    lock::Threads.SpinLock
end

const poll_queue = PollQueue(Set{UnixFD}(),
                             fill(C.pollfd(), MAX_POLL_FD_COUNT),
                             [],
                             Threads.SpinLock())


@db function poll_queue_init()

    # Check that fdvector does not get reallocated when emptied and refilled.
    fdvector_p = pointer(poll_queue.fdvector)
    empty!(poll_queue.fdvector)
    for i in 1:MAX_POLL_FD_COUNT
        push!(poll_queue.fdvector, C.pollfd(1,2,3))
    end
    empty!(poll_queue.fdvector)
    @assert pointer(poll_queue.fdvector) == fdvector_p

    # Pipe for asking `poll(2)` to return before timeout.
    poll_queue.wakeup_pipe = wakeup_pipe()
    push!(poll_queue.fdvector,
          C.pollfd(poll_queue.wakeup_pipe[1], C.POLLIN, 0))

    # Global Task to run `poll(2)`.
    Threads.@spawn poll_task(poll_queue)              ;@db "@spawn poll_task()"

    if Sys.islinux()
        epoll_queue_init()
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
end


"""
Wait for an event to occur on `fd`.
"""
@db 3 function wait_for_event(fd::UnixFD)
    Base.assert_havelock(fd)

    fd.nwaiting += 1
    try
        register_for_events(fd)              ;@db 3 "$(fd.nwaiting) waiting..."
        wait(fd)
    finally
        fd.nwaiting -= 1
    end
    nothing
end

wait_for_event(::UnixFD{SleepEvents}) = Base.sleep(0.01)


@db 2 function register_for_events(fd::UnixFD{T, PollEvents}) where T
    @nospecialize
    @dblock poll_queue.lock begin
        push!(poll_queue.set, fd)
        push!(poll_queue.fdvector, C.pollfd(fd, poll_event_type(fd), 0))
        wakeup_poll(poll_queue)                               ;@db 5 poll_queue
    end
    nothing
end


"""
Run `poll_wait()` in a loop.
"""
@db 1 function poll_task(q)

    if Threads.threadid() == 1
        @warn """
              UnixIO.poll_task() is running on thread No. 1!
              Other Tasks on thread 1 may be blocked for up to 100ms while
              poll_task() is waiting for IO.
              Consider increasing JULIA_NUM_THREADS (`julia --threads N`).
              """
        timeout_ms = 100
    else
        timeout_ms = 10000
    end

    while true
        try
            poll_wait(q, timeout_ms) do events, fd
                if events & (C.POLLHUP | C.POLLNVAL) != 0
                    #=  fd.isdead = true =#;
                    @db 1 "$(db_c(events,"POLL")) -> $fd 💥"
                end
                @dblock q.lock delete!(q.set, fd)
                if fd.nwaiting <= 0
                    @db 1 "$(db_c(events,r"POLL[A-Z]")) -> $fd None Waiting!"
                else
                    @db 2 "$(db_c(events,r"POLL[A-Z]")) -> notify($fd)"
                    @dblock fd notify(fd);
                end
            end
        catch err
            notify_error(q.set, err)
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        yield()
    end
    @assert false
end

function notify_error(fds, err)
    for fd in fds
        @lock fd Base.notify_error(fd.ready, err)
    end
end


gc_safe_poll(fds, nfds, timeout_ms) = @gc_safe C.poll(fds, nfds, timeout_ms)



"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
Return false if the queue is empty.
"""
@db 4 function poll_wait(f::Function, q::PollQueue, timeout_ms::Int)

    # Wait for events
    v = q.fdvector                                         
    timeout_ms = next_timer_deadline_ms(timeout_ms)
    @db 4 " [ poll($timeout_ms ms)..."
    n = @cerr(allow=C.EINTR, gc_safe_poll(v, length(v), timeout_ms))   ;@db 5 n
                                                                       ;@db 3 v
    # Check poll vector for events.
    del = Int[]
    for (i, e) in enumerate(v)
        if e.revents != 0
            if e.fd == q.wakeup_pipe[1]
                C.read(q.wakeup_pipe[1], Ref(0), 1)        ;@db 4 "got wakeup!"
            else
                push!(del, i)
                fd = lookup_unix_fd(e.fd)
                @assert fd != nothing "Can't find UnixFD for $e!" *
                                      " (Need wakeup_poll() in close?)"
                f(e.revents, fd)
            end
        end
    end
    @dblock q.lock deleteat!(v, del)                               ;@db 6 del v

    # Check for timeouts.
    notify_timers()
    nothing
end



# Linux epoll(7)             https://man7.org/linux/man-pages/man7/epoll.7.html


"""
See `struct epoll_event` in "sys/epoll.h"
"""
struct epoll_event
    events::UInt32
    data::UInt64
end


"""
See PollQueue above.
"""
mutable struct EPollQueue
    fd::RawFD
    set::Set{UnixFD}
    cvector::Vector{epoll_event}
    lock::Threads.SpinLock
end

const epoll_queue = EPollQueue(RawFD(-1),
                               Set{UnixFD}(),
                               Vector{epoll_event}(undef, 10),
                               Threads.SpinLock())

@db function epoll_queue_init()

    @assert Sys.ARCH != :x86_64 """
        FIXME: UnixIO does not support epoll on x86_64!
        `struct epoll_event` has `__attribute__((packed))` on x86.
        See https://git.io/JCGMK and https://git.io/JCGDz
    """
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
function epoll_ctl(fd, op, events, data=fd)
    e = [epoll_event(events, data)]
    GC.@preserve e @cerr(allow=EBADF, #FIXME ?
                         C.epoll_ctl(epoll_queue.fd, op, fd, pointer(e)))
end

epoll_ctl(fd::UnixFD, op, events) =
    epoll_ctl(fd.fd, op, events, pointer_from_objref(fd))


"""
Register `fd` to wake up `epoll_wait(7)` on `event`:
"""
@db 4 function register_for_events(fd::UnixFD{T, EPollEvents}) where T
    @dblock epoll_queue.lock begin
        if fd ∉ epoll_queue.set
            push!(epoll_queue.set, fd)
            epoll_ctl(fd, C.EPOLL_CTL_ADD, poll_event_type(fd))
        end
    end
end

poll_event_type(::ReadFD) = C.POLLIN
poll_event_type(::WriteFD) = C.POLLOUT


"""
Call `epoll_wait(7)` to wait for events.
Call `f(events, fd)` for each event.
"""
@db 6 function poll_wait(f::Function, q::EPollQueue, timeout_ms::Int)
    v = q.cvector
    n = @cerr(allow=C.EINTR,
              gc_safe_epoll_wait(q.fd, v, length(v), timeout_ms))
    if n >= 0
        for i in 1:n
            p = Ptr{Cvoid}(UInt(v[i].data))
            fd = unsafe_pointer_to_objref(p)
            epoll_ctl(fd, C.EPOLL_CTL_DEL, 0)
            f(v[i].events, fd)
        end
    end
    nothing
end


gc_safe_epoll_wait(epfd, events, maxevents, timeout_ms) = 
    @gc_safe C.epoll_wait(epfd, events, maxevents, timeout_ms)



# Pretty Printing.


Base.show(io::IO, fd::C.pollfd) =
    print(io, "(", fd.fd, ", ", fd.events, ", ", fd.revents, ")")


Base.show(io::IO, q::PollQueue) =
    dbprint(io, "(", q.set, ", ", q.fdvector,
                     (islocked(q.lock) ? ", 🔒" : ())...,
                ")")



# End of file: poll.h
