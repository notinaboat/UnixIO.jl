"""
# Polling

FIXME
 - consider @noinline and @nospecialize, @noinline
 - specify types on kw args? check compiler log of methods generated
"""


"""
Tuple that matches the memory layout of C `struct pollfd`."
"""
const PollFDTuple = Tuple{fieldtypes(C.pollfd)...}


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
    cvector::Vector{PollFDTuple}
    cvector_is_stale::Bool
    wakeup_pipe::Vector{Cint}
    lock::Threads.SpinLock
end


const poll_queue = PollQueue(Set{UnixFD}(),
                             [],
                             true,
                             [],
                             Threads.SpinLock())

function poll_queue_init()

    # Pipe for asking `poll(2)` to return before timeout.
    poll_queue.wakeup_pipe = wakeup_pipe()

    # Global Task to run `poll(2)`.
    Threads.@spawn poll_task(poll_queue)

    if Sys.islinux()
        epoll_queue_init()
    end
end

function wakeup_pipe()
    wakeup_pipe = fill(Cint(-1), 2)
    @cerr C.pipe(wakeup_pipe)
    for fd in wakeup_pipe
        fcntl_setfl(fd, C.O_NONBLOCK)
    end                                  ;@db 3 "wakeup_pipe() -> $wakeup_pipe"
    wakeup_pipe
end


"""
Write a byte to the pipe to wake up `poll(2)` before its timeout.
"""
function wakeup_poll(q::PollQueue)                       ;@db 3 "wakeup_poll()"
    @cerr C.write(q.wakeup_pipe[2], Ref(0), 1)
end


"""
Wait for an event to occur on `fd`. 
"""
function wait_for_event(fd::UnixFD)                  ;@dbf 3 :wait_for_event fd
    Base.assert_havelock(fd)

    fd.nwaiting += 1
    try
        register_for_events(fd)              ;@db 3 "$(fd.nwaiting) waiting..."
        wait(fd)
    finally 
        fd.nwaiting -= 1
    end                                                                 ;@dbr 3
    nothing
end

wait_for_event(::UnixFD{SleepEvents}) = Base.sleep(0.01)


function register_for_events(fd::UnixFD{PollEvents})
                                                 @dbf 3 :register_for_events fd
    @dblock poll_queue.lock begin
        push!(poll_queue.set, fd)
        poll_queue.cvector_is_stale = true
        wakeup_poll(poll_queue)
    end                                                                 ;@dbr 3
    nothing
end


"""
Run `poll_wait()` in a loop.
"""
function poll_task(q)                                         @dbf 1 :poll_task

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
                    fd.isdead = true   ;@db 1 "💥$(db_c(events,"POLL")) -> $fd"
                end
                @dblock q.lock delete!(q.set, fd)
                if fd.nwaiting <= 0
                    @db 0 "$(db_c(events,"POLL")) -> $fd None Waiting!"
                else
                    @lock fd notify(fd)  ;@db 3 "$(db_c(events,"POLL")) -> $fd"
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


@noinline function gc_safe_poll(fds, nfds, timeout_ms)
    old_state = @ccall jl_gc_safe_enter()::Int8
    n = C.poll(fds, nfds, timeout_ms)
    @ccall jl_gc_safe_leave(old_state::Int8)::Cvoid
    return n
end


"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
Return false if the queue is empty.
"""
function poll_wait(f::Function, q::PollQueue, default_timeout_ms)
                                                              @dbf 6 :poll_wait
    # Build vector of `struct pollfd`.
    v = q.cvector
    if q.cvector_is_stale;
        resize!(v, length(q.set) + 1)
        for (i, fd) in enumerate(q.set)
            v[i] = (fd.fd, poll_event_type(fd), 0)
        end
        v[end] = (q.wakeup_pipe[1], C.POLLIN, 0)
        q.cvector_is_stale = false
        @db 3 "rebuild cvector: $v"
    end

    # Wait for events
    timeout_ms = next_timer_deadline_ms(default_timeout_ms)
    @db 6 "C.poll $timeout_ms ms vl=$(length(v))"
    n = @cerr allow=C.EINTR gc_safe_poll(v, length(v), timeout_ms)
    @db 6 "C.poll -> $n $v"

    # Check for write to wakeup pipe.
    fd, events, revents = v[end]
    if revents != 0                            ;@db 5 "poll_wait() got wakeup!"
        @assert fd == q.wakeup_pipe[1]
        C.read(fd, Ref(0), 1)
    end

    # Check poll vector for events.
    del = Int[]
    for i in 1:length(v)-1
        fd, events, revents = v[i]
        if revents != 0
            push!(del, i)
            ufd = lookup_unix_fd(fd)
            @assert ufd != nothing
            f(revents, ufd)
        end
    end                                                       ;@db 6 "del=$del"
    deleteat!(v, del)                                             ;@db 6 "v=$v"

    # Check for timeouts.
    notify_timers()                                                ;@dbr 6 "👍"
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
    fd::Cint
    set::Set{UnixFD}
    cvector::Vector{epoll_event}
    lock::Threads.SpinLock
end

const epoll_queue = EPollQueue(-1,
                               Set{UnixFD}(),
                               Vector{epoll_event}(undef, 10),
                               Threads.SpinLock())

function epoll_queue_init()

    @assert Sys.ARCH != :x86_64 """
        FIXME: UnixIO does not support epoll on x86_64!
        `struct epoll_event` has `__attribute__((packed))` on x86.
        See https://git.io/JCGMK and https://git.io/JCGDz
    """
    @assert C.EPOLLIN == C.POLLIN
    @assert C.EPOLLOUT == C.POLLOUT
    @assert C.EPOLLHUP == C.POLLHUP
    @assert C.EPOLLNVAL == C.POLLNVAL

    # Global FD interface to Linux epoll(7).
    epoll_queue.fd = @cerr C.epoll_create1(C.EPOLL_CLOEXEC)

    # Global Task to run `epoll_wait(7)`.
    Threads.@spawn poll_task(epoll_queue)
end



"""
Add, modify or delete epoll target FDs.
See [epoll_ctl(7)(https://man7.org/linux/man-pages/man7/epoll_ctl.7.html)
"""
function epoll_ctl(fd, op, events, data=fd)
    e = [epoll_event(events, data)]
    GC.@preserve e @cerr C.epoll_ctl(epoll_queue.fd, op, fd, pointer(e))
end

epoll_ctl(fd::UnixFD, op, events) =
    epoll_ctl(fd.fd, op, events, pointer_from_objref(fd))


"""
Register `fd` to wake up `epoll_wait(7)` on `event`:
"""
function register_for_events(fd::UnixFD{EPollEvents})
    @dblock epoll_queue.lock begin
        push!(epoll_queue.set, fd)
        epoll_ctl(fd, C.EPOLL_CTL_ADD, poll_event_type(fd))
    end
end

poll_event_type(::ReadFD) = C.POLLIN
poll_event_type(::WriteFD) = C.POLLOUT


"""
Call `epoll_wait(7)` to wait for events.
Call `f(events, fd)` for each event.
"""
function poll_wait(f::Function, q::EPollQueue, timeout_ms)
    v = q.cvector
    n = @cerr allow=C.EINTR gc_safe_epoll_wait(q.fd, v, length(v), timeout_ms)
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


@noinline function gc_safe_epoll_wait(epfd, events, maxevents, timeout_ms)
    old_state = @ccall jl_gc_safe_enter()::Int8
    n = C.epoll_wait(epfd, events, maxevents, timeout_ms)
    @ccall jl_gc_safe_leave(old_state::Int8)::Cvoid
    return n
end


# End of file: poll.h
