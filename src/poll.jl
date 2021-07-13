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
    channel::Channel{PollFD}
    queue::Vector{PollFD}
    vector::Vector{PollFDTuple}
    task::Union{Nothing,Task}
end


const poll_queue = PollQueue(Channel{PollFD}(0),[], [], nothing)

function __init__()
    poll_queue.task = @async poll_task(q)
end


"""
    poll_wait(fd, events)

Wait for `events` to occur on `fd`.
See [poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)
for event types.
"""
function poll_wait(fd::PolledUnixFD, events)
    lock(fd.ready)
    try
        push!(poll_queue.channel, PollFD(fd.fd, events, fd.ready))
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
            printerr("poll_task")
            while isready(q.channel) || isempty(q.queue)
                fd = take!(q.channel)
                @assert findfirst(x->x.fd == fd.fd, q.queue) == nothing
                                        # FIXME reconsider if/when poll is used
                                        #       for writes as well as reads.
                push!(q.queue, fd)
            end

            printerr("poll_task poll")
            poll(q)

        catch err
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
    end
end


"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
Return false if the queue is empty.
"""
function poll(q::PollQueue)

    queue_length = length(q.queue)
    if queue_length == 0
        return
    end

    # Build vector of `struct pollfd`.
    resize!(q.vector, queue_length)
    for (i, fd) in enumerate(q.queue)
        q.vector[i] = (fd.fd, fd.events, 0)
    end

    # Wait for events
    timeout_ms = 10
    n = C.poll(q.vector, queue_length, timeout_ms)
    if n == -1 && Base.Libc.errno() != C.EINTR
        throw(ccall_error(:poll, q.vector, queue_length, timeout_ms))
    end

    # Check poll vector for events.
    for (fd, events, revents) in q.vector
        if revents != 0

            # Remove from queue.
            i = findfirst(x->x.fd == fd #=&& x.events == events=#, q.queue)
            ready = q.queue[i].ready    # ^^ FIXME reconsider if poll is used
            deleteat!(q.queue, i)       #          for writes as well as reads.

            # Notify waiting task.
            lock(ready)
            notify(ready)
            unlock(ready)
        end
    end

    nothing
end



# End of file: poll.h
