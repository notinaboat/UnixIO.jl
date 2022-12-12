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
    
        while true
            n = C.aio_error(cbp)
            if n == C.EINPROGRESS
                sleep(0.1) # FIXME
            elseif n == C.ECANCELED
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
end
