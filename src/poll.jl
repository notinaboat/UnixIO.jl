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
    fd_vector::Vector{FD}
    poll_vector::Vector{C.pollfd}
    wakeup_pipe::Vector{Cint}
    lock::Threads.SpinLock
end

waiting_fds(q::PollQueue) = q.fd_vector

is_registered_with_queue(q) = @lock q.lock (fd ∈ waiting_fds(q))

is_registered_with_wait_api(fd) = is_registered_with_wait_api(fd, WaitAPI(fd))

is_registered_with_wait_api(fd, ::WaitAPI{:PosixPoll}) =
    is_registered_with_queue(poll_queue)


# FIXME look at https://github.com/JuliaConcurrent/ConcurrentCollections.jl

const poll_queue = PollQueue(Channel{FD}(Inf),
                             [],
                             [],
                             [],
                             Threads.SpinLock())


@db function poll_queue_init()

    # Pipe for asking `poll(2)` to return before timeout.
    copy!(poll_queue.wakeup_pipe, wakeup_pipe())
    fd = poll_queue.wakeup_pipe[1]
    push!(poll_queue.poll_vector, C.pollfd(fd, C.POLLIN, 0))
    push!(poll_queue.fd_vector, FD{In}(fd))

    # Global Task to run `poll(2)`.
    Threads.@spawn poll_task(poll_queue)              ;@db "@spawn poll_task()"
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


IOTraits._wait(fd::FD, ::WaitAPI{:PosixPoll}; deadline=Inf) =
    wait_for_event(poll_queue, fd; deadline)


"""
Wait for an event to occur on `fd`.
"""
@db 2 function wait_for_event(queue, fd::FD; deadline=Inf)
    assert_havelock(fd.ready)

    timer = register_timer(deadline) do
        @dblock fd.ready notify(fd.ready, :timeout)
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
end

const poll_threads = Vector{Int}()

"""
Run `poll_wait()` in a loop.
"""
@db 1 function poll_task(q)

    @assert !(Threads.threadid() ∈ poll_threads)
    push!(poll_threads, Threads.threadid())

    if Threads.threadid() == 1
        @warn "UnixIO.poll_task() is running on thread No. 1!\n" *
              "Other Tasks on thread 1 may be blocked for up to 100ms while " *
              "poll_task() is waiting for IO.\n" *
              "Consider increasing JULIA_NUM_THREADS (`julia --threads N`)."

        timeout_ms = 100
    else
        @db 1 "poll_task($(typeof(q))) on thread $(Threads.threadid())"
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
                    debug_write("none waiting! $fd\n");
                    @db 1 "$(db_c(events,r"POLL[A-Z]")) -> $fd None Waiting!"
                else
                    @db 2 "$(db_c(events,r"POLL[A-Z]")) -> notify($fd)"
                    @dblock fd.ready notify(fd.ready, events); # Wake: `wait_for_event()`
                end
            end
        catch err
            @lock q.lock for fd in waiting_fds(q)
                @lock fd.ready Base.notify_error(fd.ready, err)
            end
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        # FIXME process_warning_queue()
        # GC.safepoint()
        if Threads.threadid() == 1
            yield()
        end
    end
    @assert false
end


gc_safe_poll(fds, nfds, timeout_ms) = @gc_safe C.poll(fds, nfds, timeout_ms)


"""
- Update `poll_vector` based on `fd_new`.
- Wait for events.
- Call `f(events, fd)` for each event.
"""
@db 4 function poll_wait(f::Function, q::PollQueue, timeout_ms::Int)

    fdv = q.fd_vector                                         
    pollv = q.poll_vector                                         
    timeout_ms = next_timer_deadline_ms(timeout_ms)
    @db 4 " [ poll($timeout_ms ms)..."

    # Add new entries to fd_vector and poll_vector.
    while !isempty(q.fd_new)
        fd = take!(q.fd_new)                                   ;@db 4 "add $fd"
        @lock q.lock push!(fdv, fd)
        push!(pollv, C.pollfd(fd, poll_event_type(fd), 0))
    end
    pollv_length = length(pollv)

    # Wait for events
    n = @cerr(allow=C.EINTR,
              gc_safe_poll(pollv, pollv_length, timeout_ms))           ;@db 5 n
                                                                   ;@db 4 pollv
    # Process wakeup pipe events.
    @assert pollv[1].fd == q.wakeup_pipe[1]
    if pollv[1].revents != 0
        C.read(q.wakeup_pipe[1], Ref(0), 1)                ;@db 4 "got wakeup!"
    end

    # Check poll vector for events.
    keep_i = 1
    for i in 2:pollv_length
        fd = fdv[i]
        fd.nwaiting > 0 || continue
        e = pollv[i]
        if e.revents != 0
            @assert fd.isclosed || RawFD(e.fd) == fd.fd
            f(e.revents, fd)
        else
            # Keep this item if it is still waiting for events.
            keep_i += 1
            if i != keep_i
                pollv[keep_i] = e
                fdv[keep_i] = fd
            end
        end
    end

    # Resize the vectors to inclue only the kept items.
    if keep_i < pollv_length
        pollv_length = keep_i
        resize!(pollv, pollv_length)
        @lock q.lock resize!(fdv, pollv_length)
    end

    # Check for timeouts.
    notify_timers()
    nothing
end

poll_event_type(::FD{In}) = C.POLLIN
poll_event_type(::FD{Out}) = C.POLLOUT




# Pretty Printing.


Base.show(io::IO, fd::C.pollfd) =
    print(io, "(", fd.fd, ", ", fd.events, ", ", fd.revents, ")")


Base.show(io::IO, q::PollQueue) =
    dbprint(io, "(", q.fd_vector, ", ", q.poll_vector, ")")



# End of file: poll.h
