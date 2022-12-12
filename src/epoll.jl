# Linux epoll(7)             https://man7.org/linux/man-pages/man7/epoll.7.html

if Sys.islinux()

"""
See PollQueue above.
"""
mutable struct EPollQueue
    fd::RawFD
    dict::Dict{RawFD,FD}
    cvector::Vector{C.epoll_event}
    lock::Threads.SpinLock
end

const epoll_queue = EPollQueue(RawFD(-1),
                               Dict{RawFD,FD}(),
                               Vector{C.epoll_event}(undef, 10),
                               Threads.SpinLock())

waiting_fds(q::EPollQueue) = @dblock q.lock collect(values(q.dict))


@db function epoll_queue_init()

    @assert C.EPOLLIN == C.POLLIN
    @assert C.EPOLLOUT == C.POLLOUT
    @assert C.EPOLLHUP == C.POLLHUP

    # Global FD interface to Linux epoll(7).
    epoll_queue.fd = RawFD(@cerr C.epoll_create1(C.EPOLL_CLOEXEC))

    # Global Task to run `epoll_wait(7)`.
    Threads.@spawn poll_task(epoll_queue)
end



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
    @dblock q.lock begin
        if !haskey(q.dict, fd.fd)
            q.dict[fd.fd] = fd
            epoll_ctl(fd, C.EPOLL_CTL_ADD, poll_event_type(fd))
        else
            @db 2 "Already registered!"
        end
    end
end

@db 4 function unregister_for_events(q::EPollQueue, fd)
    @dblock q.lock begin
        if haskey(q.dict, fd.fd)
            delete!(q.dict, fd.fd)
            epoll_ctl(fd, C.EPOLL_CTL_DEL)#; allow=C.ENOENT)
        end
    end
end


"""
Call `epoll_wait(7)` to wait for events.
Call `f(events, fd)` for each event.
"""
@db 4 function poll_wait(f::Function, q::EPollQueue, timeout_ms::Int)
    v = q.cvector                                                 ;@db 6 q.dict
    n = @cerr(allow=C.EINTR,
              gc_safe_epoll_wait(q.fd, v, length(v), timeout_ms))    ;@db 6 n v
    if n >= 0
        for i in 1:n
            p = pointer(v, i)
            fd = nothing
            @dblock q.lock begin
                fd = get(q.dict, RawFD(unsafe_load(p.data.fd)), nothing) ;@db 6 i fd
            end
            if fd == nothing
                @error "Ignoring epoll_wait() notification v[$i] = $(v[i]) " *
                       "for unknown FD (already deleted?)." v[i] q.dict
            else
                unregister_for_events(q, fd)
                f(unsafe_load(p.events), fd)
            end
        end
    end
    nothing
end


gc_safe_epoll_wait(epfd, events, maxevents, timeout_ms) = 
    @gc_safe C.epoll_wait(epfd, events, maxevents, timeout_ms)

end # if Sys.islinux()
