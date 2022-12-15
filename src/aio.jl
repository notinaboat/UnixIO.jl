struct AIOQueue
    fd_list::Vector{FD}
    aiocb_list::Vector{Ptr{C.aiocb}}
    wakeup_pipe::Vector{Cint}
    lock::Threads.SpinLock
end

waiting_fds(q::AIOQueue) = q.fd_list

const aio_queue = AIOQueue([], [], [], Threads.SpinLock())

@db function aio_queue_init()
    # Pipe for asking `aio_suspend(3)` to return before timeout.
    copy!(aio_queue.wakeup_pipe, wakeup_pipe())
    fd = aio_queue.wakeup_pipe[1]
    push!(aio_queue.poll_vector, C.pollfd(fd, C.POLLIN, 0))
    push!(aio_queue.fd_vector, FD{In}(fd))

    # Global Task to run `aio_suspend(3)`.
    Threads.@spawn aio_task(aio_queue)
end

gc_safe_aio_suspend(aiocb_list, n, timeout) =
    @gc_safe C.aio_suspend(aiocb_list, n, timeout)


function aio_task(q)

    # See `@warn` in `poll_task(q)`.
    timeout = Threads.threadid() == 1 ?
        Ref(C.timespec(0,        10^9÷10 #=ns=#)) :
        Ref(C.timespec(60 #=s=#, 0))

    while true
        try
            @cerr0 gc_safe_aio_suspend(q.aiocb_list,
                                       length(q.aiocb_list),
                                       timeout)

            @dblock q.lock begin
                indexes_to_delete = Int[]

                for (i, cb) in enumerate(q.aiocb_list)
                    n = C.aio_error(cb)
                    if n != C.EINPROGRESS
                        fd = q.fd_list[i]
                        @assert RawFD(q.aiocb_list[i].aio_filedes) == fd.fd
                        @dblock fd.ready notify(fd.ready, n)
                        push!(indexes_to_delete, i)
                    end
                end

                deleteat!(q.aiocb_list, indexes_to_delete)
                deleteat!(q.fd_list, indexes_to_delete)
            end

        catch err
            for fd in waiting_fds(q)
                @lock fd.ready Base.notify_error(fd.ready, err)
            end
            exception=(err, catch_backtrace())
            @error "Error in aio_task()" exception
        end
        yield()
    end
end


function raw_transfer(fd, ::AIOTransfer, ::Out, buf, count)
    # FIXME
    C.write(fd, buf, count)
end


@db 1 function raw_transfer(fd, ::AIOTransfer, ::In,  buf, count)

    cb = Ref{C.aiocb}()
    cbp = Base.unsafe_convert(Ptr{C.aiocb}, cb)

    offset = @cerr C.lseek(fd, 0, C.SEEK_CUR)

    GC.@preserve cb begin
        cbp.aio_fildes = fd
        cbp.aio_offset = offset
        cbp.aio_buf = buf
        cbp.aio_nbytes = count
        cbp.aio_reqprio = 0
        cbp.aio_sigevent.sigev_notify = C.SIGEV_NONE
        cbp.aio_lio_opcode = 0

        @cerr0 C.aio_read(cbp)

        @dblock q.lock begin
            push!(q.aiocb_list, cbp)
            push!(q.fd_list, fd)

            FIXME - no way to wake up existing call to `aio_suspend` !

        end
    
        n = wait(fd)
        @assert n != C.EINPROGRESS

        if n == C.ECANCELED
            return 0
        elseif n == 0
            n = @cerr C.aio_return(cbp)
            @cerr C.lseek(fd, offset + n, C.SEEK_SET)
            return n
        else
            err = n
            systemerror("C.aio_read()", err)
        end
    end
end
