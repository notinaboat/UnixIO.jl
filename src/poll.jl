# Polling


"""
Construct a tuple that matches the memory layout of C `struct pollfd`."
"""
pollfd(fd, events) = convert(Tuple{fieldtypes(C.pollfd)...},
                             (fd, events, 0))


"""
PollFD: an `fd` to poll, `events` to wait for and a `Condition` to notify.
"""
struct PollFD
    fd::Cint
    events::Cshort
    ready::Threads.Condition
end


"""
Global queue of file descriptors to poll.
"""
const poll_queue = PollFD[]
const poll_lock = Threads.SpinLock()


"""
    poll_wait(fd, events)

Wait for `events` to occur on `fd`.
See [poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)
for event types.
"""
function poll_wait(fd::PolledUnixFD, events)
    global poll_queue

    lock(fd.ready)
    try
        # Insert a new `PollFD` in the global `poll_queue`.
        lock(poll_lock)
        isfirst = isempty(poll_queue)
        @assert findfirst(x->x.fd == fd.fd, poll_queue) == nothing
        push!(poll_queue, PollFD(fd.fd, events, fd.ready))
        unlock(poll_lock)

        # Start the polling task if needed.
        if isfirst == 1
            @async poll_task(poll_queue, poll_lock)
        end

        # Wait...
        wait(fd.ready)
    finally
        unlock(fd.ready)
    end
end


"""
Run `poll(queue)` while there are entries in the `queue`.
"""
function poll_task(queue::Vector{PollFD}, queue_lock)
    while true
        try
            poll(queue, queue_lock)
            lock(queue_lock)
            if isempty(queue)
                return
            end
        catch err
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        finally
            unlock(queue_lock)
        end
        sleep(0.01)
    end
end


"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
"""
function poll(queue::Vector{PollFD}, queue_lock)

    # Build vector of `struct pollfd`.
    lock(queue_lock)
    @assert !isempty(queue)
    v = [pollfd(fd.fd, fd.events) for fd in queue]
    unlock(queue_lock)

    # Wait for events
    timeout_ms = 10
    n = C.poll(v, length(v), timeout_ms)
    if n == -1 && Base.Libc.errno() != C.EINTR
        throw(ccall_error(:poll, v, queuelen, timeout_ms))
    end

    # Check poll vector for events.
    for (fd, events, revents) in v
        if revents == 0
            continue
        end

        # Remove from queue.
        lock(queue_lock)
        i = findfirst(x->x.fd == fd #=&& x.events == events=#, queue)
        ready = queue[i].ready      # ^^ FIXME reconsider when poll is used
        deleteat!(queue, i)         #          for reads.
        unlock(queue_lock)

        # Notify waiting task.
        lock(ready)
        notify(ready)
        unlock(ready)
    end

    nothing
end



# End of file: poll.h
