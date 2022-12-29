# Linux epoll(7)             https://man7.org/linux/man-pages/man7/epoll.7.html

"""
See PollQueue above.
"""
mutable struct EPollQueue
    fd::RawFD
    cvector::Vector{C.epoll_event}
end

const epoll_queue = EPollQueue(RawFD(-1),
                               Vector{C.epoll_event}(undef, 10))

@db function epoll_queue_init()

    @assert C.EPOLLIN == C.POLLIN
    @assert C.EPOLLOUT == C.POLLOUT
    @assert C.EPOLLHUP == C.POLLHUP

    # Global FD interface to Linux epoll(7).
    epoll_queue.fd = RawFD(@cerr C.epoll_create1(C.EPOLL_CLOEXEC))

    # Global Task to run `epoll_wait(7)`.
    Threads.@spawn poll_task(epoll_queue)
end


IOTraits._wait(fd::FD, ::WaitAPI{:EPoll}; deadline=Inf) =
    wait_for_event(epoll_queue, fd; deadline)


"""
Add, modify or delete epoll target FDs.
See [epoll_ctl(7)(https://man7.org/linux/man-pages/man7/epoll_ctl.7.html)
"""
@db 4 function epoll_ctl(fd, op, events=0, data=fd; allow=())
                                                  @db 4 fd db_c(op,"EPOLL_CTL")
    e = Ref{C.epoll_event}()
    p = Base.unsafe_convert(Ptr{C.epoll_event}, e)
    GC.@preserve e begin
        p.events = events
        p.data.fd = fd
        @cerr(allow=allow, C.epoll_ctl(epoll_queue.fd, op, fd, p))
    end
end

epoll_ctl(fd::FD, op, events=0; kw...) =
    epoll_ctl(convert(Cint, fd), op, events; kw...)


"""
Register `fd` to wake up `epoll_wait(7)` on `event`:
"""
@db 4 function register_for_events(q::EPollQueue, fd)
    epoll_ctl(fd, C.EPOLL_CTL_ADD, poll_event_type(fd) | C.EPOLLONESHOT;
              allow=C.EEXIST)
    epoll_ctl(fd, C.EPOLL_CTL_MOD, poll_event_type(fd) | C.EPOLLONESHOT;
              allow=C.EEXIST)
    #FIXME 
    nothing
end

@db 4 function unregister_for_events(q::EPollQueue, fd)
    if !fd.isclosed
        epoll_ctl(fd, C.EPOLL_CTL_DEL; allow=C.ENOENT)
    end
    nothing
end


"""
Call `epoll_wait(7)` to wait for events.
Call `f(events, fd)` for each event.
"""
@db 4 function poll_wait(f::Function, q::EPollQueue, timeout_ms::Int)
    v = q.cvector
    n = @cerr(allow=C.EINTR,
              gc_safe_epoll_wait(q.fd, v, length(v), timeout_ms))    ;@db 6 n v
    if n >= 0
        for i in 1:n
            p = pointer(v, i)
            fd = get_weak_fd(unsafe_load(p.data.fd))
            if fd == nothing
                @error "Ignoring epoll_wait() notification v[$i] = $(v[i]) " *
                       "for unknown FD (already deleted?)." v[i]
            else
                f(unsafe_load(p.events), fd)
            end
        end
    end
    nothing
end


gc_safe_epoll_wait(epfd, events, maxevents, timeout_ms) = 
    @gc_safe C.epoll_wait(epfd, events, maxevents, timeout_ms)
