"""
# Polling

1) Seperate read/write FDs.

2) Separate timeouts from polling?
 - Provide a generic cancel method
 - Use timer to cancel

3) Share task / wakeup pipe between poll/epoll
 - Share task, run one or the other poll function.
 - use the same wakeup method as epoll
 - need a lock around epoll_set ?
 - remove Channel from poll implementation?
 - Sort poll set in timeout order?

3) keep partial results on timeout ? 
 - timeout should be like temporary eof?

4) keep poll request active for duration of multi-call read
 - or keep poll request active for some brief time, 

5) Later...

 - consider @noinline and @nospecialize
 - specify types on kw args? check compiler log of methods generated
 - epoll not faster if most file descriptors are active?

"""


"""
Tuple that matches the memory layout of C `struct pollfd`."
"""
const PollFDTuple = Tuple{fieldtypes(C.pollfd)...}


"""
Global queue of file descriptors to poll.

`poll_wait()` puts new FDs in `channel`.

`poll_task()` takes FDs from the `channel` and puts them in the `queue`
and calls `poll(::PollQueue)`.

`poll(::PollQueue)` passes `cvector` (containing C `struct pollfd`s) to
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html) to wait
for IO activity.

`poll_wait()` uses `wakeup_pipe` to wake `poll(2)` early when there is
a new FD to wait for.
"""
mutable struct PollQueue
    channel::Channel{UnixFD}
    set::Set{UnixFD}
    cvector::Vector{PollFDTuple}
    wakeup_pipe::Vector{Cint}
    task::Union{Nothing,Task}
end


const poll_queue = PollQueue(Channel{UnixFD}(0),Set{UnixFD}(), [], [], nothing)

function poll_queue_init()

    # Global Task to run `poll(2)`.
    poll_queue.task = Threads.@spawn poll_task(poll_queue)

    # Pipe for asking `poll(2)` to return before timeout.
    poll_queue.wakeup_pipe = wakeup_pipe()

    if Sys.islinux()
        epoll_init()
    end
end

function wakeup_pipe()
    wakeup_pipe = fill(Cint(-1), 2)
    r = C.pipe(wakeup_pipe)
    r != -1 || throw(ccall_error(:pipe))
    for fd in wakeup_pipe
        fcntl_setfl(fd, C.O_NONBLOCK)
    end
    wakeup_pipe
end


"""
Write a byte to the pipe to wake up `poll(2)` before its timeout.
"""
wakeup(q::PollQueue) = C.write(q.wakeup_pipe[2], Ref(0), 1)

"""
    poll_wait(fd, event, deadline)

Wait for `event` to occur on `fd`.
See [poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)
for event types.
"""
function poll_wait(fd::UnixFD, event)

    if enable_dumb_polling[]
        sleep(0.01)
        return
    end

    lock(fd.ready)
    try
        enable_epoll[] ? epoll_register(fd, event) :
                         poll_register(fd, event)
        wait(fd.ready)
        @assert (fd.events & event) == 0
    finally
        unlock(fd.ready)
    end
end
const enable_dumb_polling = Ref(false)
const enable_epoll = Ref(false)
wait_for_read_event(fd) = poll_wait(fd, C.POLLIN)
wait_for_write_event(fd) = poll_wait(fd, C.POLLOUT)


function poll_register(fd::UnixFD, event)
    fd.events |= event
    push!(poll_queue.channel, fd)
    wakeup(poll_queue)
end


"""
Run `poll(queue)` while there are entries in the `queue`.
"""
function poll_task(q)

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
            while isready(q.channel) || isempty(q.set)
                fd = take!(q.channel)
                push!(q.set, fd)
                empty!(q.cvector)
            end
            @assert !isempty(q.set)
            poll(q, timeout_ms)

        catch err
            notify_error(q.set, err)
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        yield()
    end
end

function notify_error(cs, err)
    for c in cs
        @asynclog "UnixIO.notify_error()" begin
            lock(c)
            Base.notify_error(c, err)
            unlock(c)
        end
    end
end


"""
Adjust timeout_ms to nearest deadline.
"""
function deadline_timeout_ms(fds, timeout_ms)
    if !isempty(fds)
        deadline = minimum(fd.deadline for fd in fds)
        dt = deadline - time()
        if dt < (timeout_ms/1000)
            timeout_ms = max(0, round(Int, dt * 1000))
        end
    end
    timeout_ms
end

"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
Return false if the queue is empty.
"""
function poll(q::PollQueue, default_timeout_ms)

    # Build vector of `struct pollfd`.
    if isempty(q.cvector)
        resize!(q.cvector, length(q.set) + 1)
        for (i, fd) in enumerate(q.set)
            q.cvector[i] = (fd.fd, fd.events, 0)
        end
        q.cvector[end] = (q.wakeup_pipe[1], C.POLLIN, 0)
    end

    # Wait for events
    timeout_ms = deadline_timeout_ms(q.set, default_timeout_ms)
    n = C.poll(q.cvector, length(q.cvector), timeout_ms)
    if n == -1 && Base.Libc.errno() != C.EINTR
        throw(ccall_error(:poll, q.cvector, length(q.cvector), timeout_ms))
    end

    # Check for write to wakeup pipe.
    fd, events, revents = q.cvector[end]
    if revents != 0
        @assert fd == q.wakeup_pipe[1]
        C.read(fd, Ref(0), 1)
    end

    # Check poll vector for events.
    for (fd, events, revents) in q.cvector[1:end-1]
        if revents != 0
            # Remove fd from queue and notify task waiting in `poll_wait()`.
            x = find_poll_fd(q.set, fd, revents)
            lock(x.ready)
            x.events &= ~events
            delete!(q.set, x)
            empty!(q.cvector)
            notify(x.ready)          #FIXME same notification for read/write
            unlock(x.ready)
        end
    end

    # Check for timeouts.
    if timeout_ms < default_timeout_ms
        poll_check_timeouts(q.set)
    end

    nothing
end

function poll_check_timeouts(fds)
    timedout = Threads.Condition[]
    now = time()
    filter!(fds) do fd
        if now > fd.deadline #FIXME same deadline for read/write
            fd.events = 0
            push!(timedout, fd.ready)
            false
        else
            true
        end
    end
    lock.(timedout)
    notify.(timedout)
    unlock.(timedout)
end


function find_poll_fd(set, fd, events)
    for x in set
        if x.fd == fd && (                             # fd matches and...
           ((events & x.events) != 0) ||               # events match or...
           ((events & ~(C.POLLIN | C.POLLOUT)) != 0))  # unexpected event type
            return x
        end
    end
    nothing
end



# Linux epoll(7)             https://man7.org/linux/man-pages/man7/epoll.7.html


function epoll_init()

    @assert Sys.ARCH != :x86_64 """
        UnixIO does not support epoll on x86_64!
        `struct epoll_event` is `packed` on x86.
        See https://git.io/JCGMK and https://git.io/JCGDz
    """
    @assert C.EPOLLIN == C.POLLIN
    @assert C.EPOLLOUT == C.POLLOUT

    # Global FD interface to Linux epoll(7).
    global epoll_fd
    epoll_fd = C.epoll_create1(C.EPOLL_CLOEXEC)
    epoll_fd != -1 || throw(ccall_error(:epoll_create1))

    # Set of UnixFDs for epoll_wait(7) to watch.
    global epoll_set
    epoll_set = Set{UnixFD}()

    # Pipe for asking `epoll_wait(7)` to return before timeout.
    global epoll_wakeup_pipe
    epoll_wakeup_pipe = wakeup_pipe()
    epoll_add(epoll_wakeup_pipe[1], C.EPOLLIN)

    # Global Task to run `epoll_wait(7)`.
    Threads.@spawn epoll_task()
end


"""
See `struct epoll_event` in "sys/epoll.h"
"""
struct epoll_event
    events::UInt32
    data::UInt64
end


"""
Add, modify or delete epoll target FDs.
See [epoll_ctl(7)(https://man7.org/linux/man-pages/man7/epoll_ctl.7.html)
"""
function epoll_ctl(fd, op, events, data=fd)
    global epoll_fd
    e = [epoll_event(events, data)]
    r = GC.@preserve e C.epoll_ctl(epoll_fd, op, fd, pointer(e))
    r != -1 || throw(ccall_error(:epoll_ctl, op, fd))
end

epoll_ctl(fd::UnixFD, op, events) =
    epoll_ctl(fd.fd, op, events, pointer_from_objref(fd))

epoll_add(fd, events=fd.events) = epoll_ctl(fd, C.EPOLL_CTL_ADD, events)
epoll_mod(fd, events=fd.events) = epoll_ctl(fd, C.EPOLL_CTL_MOD, events)
epoll_del(fd)                   = epoll_ctl(fd, C.EPOLL_CTL_DEL,      0)


"""
Register `fd` to wake up `epoll_wait(7)` on `event`:
 - Add the `event` to the `UnixFD.events` mask.
 - Call `epoll_add` or `epoll_mod` to register the event.
 - wake the currently waiting `epoll_wait(7)` call (in `epoll_task()`).
"""
function epoll_register(fd::UnixFD, event) 
    if fd.events == 0
        fd.events = event
        @assert !(fd in epoll_set)
        push!(epoll_set, fd)
        epoll_add(fd)
    else
        fd.events |= event
        @assert fd in epoll_set
        epoll_mod(fd)
    end
    # FIXME wakeup only needed for timeouts 
    # check if fd.deadline is after next wakeup?
    # or just make cancellation separate !!!!
    epoll_wakeup()
end


"""
Write a byte to the pipe to wake up `poll(2)` before its timeout.
"""
epoll_wakeup() = C.write(epoll_wakeup_pipe[2], Ref(0), 1)


"""
Call `epoll_wait(7)` to wait for events.
Call `f(events, fd)` for each event.
"""
function epoll_wait(f::Function, timeout_ms)
    v = Vector{epoll_event}(undef, 10)
    while true
        n = C.epoll_wait(epoll_fd, v, length(v), timeout_ms)
        if n >= 0
            for i in 1:n
                if v[i].data == epoll_wakeup_pipe[1]
                    C.read(epoll_wakeup_pipe[1], Ref(0), 1)
                else
                    p = Ptr{Cvoid}(UInt(v[i].data))
                    f(v[i].events, unsafe_pointer_to_objref(p))
                end
            end
            return
        end
        if Base.Libc.errno() != C.EINTR
            throw(ccall_error(:epoll_wait))
        end
    end
end


function epoll_task()

    if Threads.threadid() == 1
        @warn """
              UnixIO.epoll_task() is running on thread No. 1!
              Other Tasks on thread 1 may be blocked for up to 100ms while
              poll_task() is waiting for IO.
              Consider increasing JULIA_NUM_THREADS (`julia --threads N`).
              """
        default_timeout_ms = 100
    else
        default_timeout_ms = 10000
    end

    while true
        try
            timeout_ms = deadline_timeout_ms(epoll_set, default_timeout_ms)

            epoll_wait(timeout_ms) do events, fd
                lock(fd.ready)
                fd.events &= ~events
                if fd.events == 0
                    epoll_del(fd)
                    delete!(epoll_set, fd)
                else
                    epoll_mod(fd)
                end
                notify(fd.ready)
                unlock(fd.ready)
            end

            # Check for timeouts.
            if timeout_ms < default_timeout_ms
                poll_check_timeouts(epoll_set)
            end

        catch err
            notify_error(epoll_set, err)
            exception=(err, catch_backtrace())
            @error "Error in epoll_task()" exception
        end
        yield()
    end
end

# End of file: poll.h
