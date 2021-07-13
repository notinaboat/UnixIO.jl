# Polling


"""
Tuple that matches the memory layout of C `struct pollfd`."
"""
const PollFDTuple = Tuple{fieldtypes(C.pollfd)...}


"""
PollFD: an `fd` to poll, `events` to wait for and a `Condition` to notify.
"""
struct PollFD
    fd::Cint
    events::Cshort
    ready::Threads.Condition
end

Base.show(io::IO, fd::PollFD) = print(io, "PollFD($(fd.fd), $(fd.events))")

"""
Global queue of file descriptors to poll.
"""
mutable struct PollQueue
    queue::Vector{PollFD}
    vector::Vector{PollFDTuple}
    lock::Threads.SpinLock
end

const poll_queue = PollQueue([], [], Threads.SpinLock())


"""
    poll_wait(fd, events)

Wait for `events` to occur on `fd`.
See [poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)
for event types.
"""
function poll_wait(fd::PolledUnixFD, events)
    global poll_queue
    q = poll_queue

    lock(fd.ready)
    try
        # Insert a new `PollFD` in the global `poll_queue`.
        lock(q.lock)
        isfirst = isempty(q.queue)
        isdupe = findfirst(x->x.fd == fd.fd, q.queue) != nothing
        push!(q.queue, PollFD(fd.fd, events, fd.ready))
        unlock(q.lock)

        @assert !isdupe # FIXME reconsider if/when poll is used
                        #       for writes as well as reads.

        # Start the polling task if needed.
        if isfirst == 1
            @async poll_task(q)
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
function poll_task(q)
    while true
        try
            poll(q) || return
        catch err
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        sleep(0.01)
    end
end


"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
Return false if the queue is empty.
"""
function poll(q::PollQueue)

    # Build vector of `struct pollfd`.
    lock(q.lock)
    queue_length = length(q.queue)
    if queue_length == 0
        unlock(q.lock)
        return false
    end
    resize!(q.vector, queue_length)
    for (i, fd) in enumerate(q.queue)
        q.vector[i] = (fd.fd, fd.events, 0)
    end
    unlock(q.lock)

    # Wait for events
    timeout_ms = 10
    n = C.poll(q.vector, queue_length, timeout_ms)
    if n == -1 && Base.Libc.errno() != C.EINTR
        throw(ccall_error(:poll, q.vector, queue_length, timeout_ms))
    end

    # Check poll vector for events.
    for (fd, events, revents) in q.vector
        if revents == 0
            continue
        end

        # Remove from queue.
        lock(q.lock)
        i = findfirst(x->x.fd == fd #=&& x.events == events=#, q.queue)
        ready = q.queue[i].ready     # ^^ FIXME reconsider if/when poll is used
        deleteat!(q.queue, i)        #          for writes as well as reads.
        queue_length = length(q.queue)
        unlock(q.lock)

        # Notify waiting task.
        lock(ready)
        notify(ready)
        unlock(ready)
    end

    return queue_length > 0
end



# End of file: poll.h
