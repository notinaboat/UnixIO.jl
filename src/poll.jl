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


waiting_fds(q::PollQueue) = q.fd_vector


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
            for fd in waiting_fds(q)
                @lock fd.ready Base.notify_error(fd.ready, err)
            end
            exception=(err, catch_backtrace())
            @error "Error in poll_task()" exception
        end
        yield()
    end
    @assert false
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

include("iouring.jl")
include("epoll.jl")



# Pretty Printing.


Base.show(io::IO, fd::C.pollfd) =
    print(io, "(", fd.fd, ", ", fd.events, ", ", fd.revents, ")")


Base.show(io::IO, q::PollQueue) =
    dbprint(io, "(", q.fd_vector, ", ", q.poll_vector, ")")



# End of file: poll.h
