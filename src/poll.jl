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

function __init__()

    # Global Task to run `poll(2)`.
    poll_queue.task = Threads.@spawn poll_task(poll_queue)

    # Pipe for asking `poll(2)` to return before timeout.
    poll_queue.wakeup_pipe = fill(Cint(-1), 2)
    r = C.pipe(poll_queue.wakeup_pipe)
    r != -1 || throw(ccall_error(:pipe))
end


"""
Write a byte to the pipe to wake up `poll(2)` before its timeout.
"""
wakeup(q::PollQueue) = C.write(q.wakeup_pipe[2], Ref(0), 1)


"""
    poll_wait(fd, events)

Wait for `events` to occur on `fd`.
See [poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)
for event types.
"""
function poll_wait(fd::UnixFD, events)
    lock(fd.ready)
    try
        push!(poll_queue.channel, PollFD(fd.fd, events, fd.ready))
        wakeup(poll_queue)
        wait(fd.ready)
    finally
        unlock(fd.ready)
    end
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
        timeout_ms = 1000
    end
    while true
        try
            while isready(q.channel) || isempty(q.queue)
                fd = take!(q.channel)
                @assert findfirst(x->x.fd == fd.fd, q.queue) == nothing
                                        # FIXME reconsider if/when poll is used
                                        #       for writes as well as reads.
                push!(q.queue, fd)
            end
            @assert !isempty(q.queue)
            poll(q, timeout_ms)
            yield()

        catch err
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
            for fd in q.queue
                Base.notify_error(fd.ready, err)
            end
        end
    end
end


"""
Wait for events.
When events occur, notify waiters and remove entries from queue.
Return false if the queue is empty.
"""
function poll(q::PollQueue, timeout_ms)

    # Build vector of `struct pollfd`.
    vector_length = length(q.queue) + 1
    resize!(q.cvector, vector_length)
    for (i, fd) in enumerate(q.queue)
        q.cvector[i] = (fd.fd, fd.events, 0)
    end
    q.cvector[end] = (q.wakeup_pipe[1], C.POLLIN, 0)

    # Wait for events
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
            i = findfirst(x->x.fd == fd #=&& x.events == events=#, q.queue)
            ready = q.queue[i].ready    # ^^ FIXME reconsider if poll is used
            lock(ready)                 #          for writes as well as reads.
            deleteat!(q.queue, i)
            notify(ready)
            unlock(ready)
        end
    end

    nothing
end



# End of file: poll.h
