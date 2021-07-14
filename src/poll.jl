# Polling


"""
Tuple that matches the memory layout of C `struct pollfd`."
"""
const PollFDTuple = Tuple{fieldtypes(C.pollfd)...}


"""
PollFD: an `fd` to poll, `events` to wait for and a `Condition` to notify.
"""
mutable struct PollFD
    fd::Cint
    events::Cshort
    ready::Threads.Condition
    deadline::Float64
end

Base.show(io::IO, fd::PollFD) = print(io, "PollFD($(fd.fd), $(fd.events))")


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
    channel::Channel{PollFD}
    queue::Vector{PollFD}
    cvector::Vector{PollFDTuple}
    wakeup_pipe::Vector{Cint}
    task::Union{Nothing,Task}
end


const poll_queue = PollQueue(Channel{PollFD}(0),[], [], [], nothing)

function poll_queue_init()

    # Global Task to run `poll(2)`.
    poll_queue.task = Threads.@spawn poll_task(poll_queue)

    # Pipe for asking `poll(2)` to return before timeout.
    poll_queue.wakeup_pipe = wakeup_pipe()
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
        if enable_epoll[]
            epoll_register(fd, event)
            wait(fd.ready)
            @assert (fd.events & event) == 0
        else
            pfd = PollFD(fd.fd, event, fd.ready, fd.deadline)
            push!(poll_queue.channel, pfd)
            wakeup(poll_queue)
            wait(fd.ready)
        end
    finally
        unlock(fd.ready)
    end
end
const enable_dumb_polling = Ref(false)
const enable_epoll = Ref(false)
wait_for_read_event(fd) = poll_wait(fd, C.POLLIN)
wait_for_write_event(fd) = poll_wait(fd, C.POLLOUT)


"""
Run `poll(queue)` while there are entries in the `queue`.
"""
function poll_task(q)

    @info "UnixIO.poll_task() on thread $(Threads.threadid())"

    if Threads.threadid() == 1
        @warn """
              UnixIO.poll_task() is running on thread No. 1!
              Other Tasks on thread 1 may be blocked for up to 100ms while
              poll_task() is waiting for IO.
              Consider increasing JULIA_NUM_THREADS (`julia --threads N`).
              """
        timeout_ms = 100
    else
        timeout_ms = 1000
    end
    while true
        try
            while isready(q.channel) || isempty(q.queue)
                fd = take!(q.channel)
                @assert find_poll_fd(q.queue, fd.fd, fd.events) == nothing
                push!(q.queue, fd)
            end
            @assert !isempty(q.queue)
            poll(q, timeout_ms)

        catch err
            for fd in q.queue
                lock(fd.ready)
                Base.notify_error(fd.ready, err)
                unlock(fd.ready)
            end
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        yield()
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
    vector_length = length(q.queue) + 1
    resize!(q.cvector, vector_length)
    for (i, fd) in enumerate(q.queue)
        q.cvector[i] = (fd.fd, fd.events, 0)
    end
    q.cvector[end] = (q.wakeup_pipe[1], C.POLLIN, 0)

    # Wait for events
    timeout_ms = deadline_timeout_ms(q.queue, default_timeout_ms)
    n = C.poll(q.cvector, vector_length, timeout_ms)
    if n == -1 && Base.Libc.errno() != C.EINTR
        throw(ccall_error(:poll, q.cvector, vector_length, timeout_ms))
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
            i::Int = find_poll_fd(q.queue, fd, revents)
            ready = q.queue[i].ready #FIXME same notification for read/write
            lock(ready)
            deleteat!(q.queue, i)
            notify(ready)
            unlock(ready)
        end
    end

    # Check for timeouts.
    if timeout_ms < default_timeout_ms
        poll_check_timeouts(q.queue)
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


find_poll_fd(queue, fd, events) = findfirst(queue) do x
    x.fd == fd && (                                # fd matches and...
      ((events & x.events) != 0) ||                # events match or...
      ((events & ~(C.POLLIN | C.POLLOUT)) != 0)    # unexpected event type
    )
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

    global epoll_fd
    epoll_fd = C.epoll_create1(C.EPOLL_CLOEXEC)
    epoll_fd != -1 || throw(ccall_error(:epoll_create1))

    global epoll_wakeup_pipe
    epoll_wakeup_pipe = wakeup_pipe()
    epoll_add(epoll_wakeup_pipe[1], C.EPOLLIN)

    # Global Task to run `epoll_wait(7)`.
    Threads.@spawn epoll_task()
end


"""
Write a byte to the pipe to wake up `poll(2)` before its timeout.
"""
epoll_wakeup() = C.write(epoll_wakeup_pipe[2], Ref(0), 1)


struct epoll_event
    events::UInt32
    data::UInt64
end

epoll_ctl(fd::UnixFD, op, events) =
    epoll_ctl(fd.fd, op, events, pointer_from_objref(fd))

function epoll_ctl(fd, op, events, data=fd)
    #@info "epoll_ctl($fd, $op, $events, $data)"
    global epoll_fd
    e = [epoll_event(events, data)]
    r = GC.@preserve e C.epoll_ctl(epoll_fd, op, fd, pointer(e))
    r != -1 || throw(ccall_error(:epoll_ctl, op, fd))
end

epoll_add(fd, events=fd.events) = epoll_ctl(fd, C.EPOLL_CTL_ADD, events)
epoll_mod(fd, events=fd.events) = epoll_ctl(fd, C.EPOLL_CTL_MOD, events)
epoll_del(fd)                   = epoll_ctl(fd, C.EPOLL_CTL_DEL,      0)


function epoll_register(fd, events) 
    #@info "epoll_register($fd, $events)"
    if fd.events == 0
        fd.events = events
        @assert !(fd in epoll_set)
        push!(epoll_set, fd)
        epoll_add(fd)
    else
        fd.events |= events
        @assert fd in epoll_set
        epoll_mod(fd)
    end
    epoll_wakeup()
    #@info "epoll_wakeup!"
end


function epoll_wait(f::Function, timeout_ms)
    v = Vector{epoll_event}(undef, 10)
    while true
        n = C.epoll_wait(epoll_fd, v, length(v), timeout_ms)
        #@info "epoll n = $n"
        if n >= 0
            for i in 1:n
                if v[i].data == epoll_wakeup_pipe[1]
                    #@info "epoll_woken!"
                    C.read(epoll_wakeup_pipe[1], Ref(0), 1)
                else
                    p = Ptr{Cvoid}(UInt(v[i].data))
                    f((v[i].events, unsafe_pointer_to_objref(p)))
                end
            end
            return
        end
        if Base.Libc.errno() != C.EINTR
            throw(ccall_error(:epoll_wait))
        end
    end
end

const epoll_set = Set{UnixFD}()

function epoll_task()

    @info "UnixIO.epoll_task() on thread $(Threads.threadid())"

    default_timeout_ms = 10000

    while true
        try
            timeout_ms = deadline_timeout_ms(epoll_set, default_timeout_ms)

            #@info "epoll_wait..."
            epoll_wait(timeout_ms) do x

               events, fd = x

                #@info "epoll found $events, $fd"
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
            #@info "epoll done"

            # Check for timeouts.
            if timeout_ms < default_timeout_ms
                poll_check_timeouts(epoll_set)
            end

        catch err
            for fd in epoll_set
                lock(fd.ready)
                Base.notify_error(fd.ready, err)
                unlock(fd.ready)
            end
            exception=(err, catch_backtrace())
            @error "Error in epoll_task()" exception
        end
        yield()
    end
end

# End of file: poll.h
