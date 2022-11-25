"""
Read-only Unix File Descriptor.
"""


"""
### Reading from a pseudoterminal device.

Reading from a pseudoterminal device is a special case.

On Linux `read(2)` returns `EIO` when called before a client has connected.
If a client connects, writes some data and then disconnects before `read(2)`
is called: `read(2)` returns the data and then returns `EIO` if called again.

On macOS `read(2)` returns `0` when called before a client has connected.
If a client connects, writes some data and then disconnects before `read(2)`
is called: `read(2)` simply returns `0` and the data is lost.

To avoid this situation a duplicate client fd is held open for the lifetime
of the pseudoterminal device (`fd.extra[:pt_clientfd]`). This has the effect that
`read(2)` will always return `EAGAIN` if there is no data available.
(The reader then waits for `poll(2)` to indicate when data is ready as usual.)

The remaining problem is that because `read(2)` will never return `0` there
is no way to detect when the client has closed the terminal.
This `raw_transfer` method handles this by checking if the client process
is still alive and returning `0` if it has terminated.
"""
@db 2 function raw_transfer(fd::FD{In,Pseudoterminal}, ::IOTraits.In, buf, count)
    n = C.read(fd.fd, buf, count)
    if n == -1
        err = errno()
        if err == C.EAGAIN && !isalive(fd.extra[:pt_client])
            @db 2 return 0 "Pseudoterminal client process died. -> HUP!"
        end
    end
    @db 2 return n
end


@db 1 function IOTraits._bytesavailable(fd::FD, ::SupportsStatSize)
    @db_not_tested
    pos = @cerr allow=C.EBADF C.lseek(fd, 0, C.SEEK_CUR)
    if pos == -1
        return 0
    end
    @db 1 return stat(fd).size - pos
end

@db 1 function IOTraits._bytesavailable(fd::FD, ::SupportsFIONREAD)
    x = Ref(Cint(0))
    @cerr C.ioctl(fd, C.FIONREAD, x)
    @db 1 return x[]
end

@db function IOTraits._position(fd::FD, ::Seekable)
    @cerr allow=C.EBADF C.lseek(fd, 0, C.SEEK_CUR)
end


#=
@db 1 function Base.readline(fd::ReadFD{<:S_IFCHR};
                             timeout=fd.timeout,
                             wait=true,
                             keep::Bool=false)
    @require !fd.isclosed

    linebuf = Vector{UInt8}(undef, C.MAX_CANON)
    fdbuf = fd.buffer

    canonical_mode = iscanon(fd) && !(fd isa ReadFD{Pseudoterminal})

    @with_timeout fd timeout while true

        # If the fd buffer already contains a complete line, return it.
        fdbuf_n = bytesavailable(fdbuf)
        if fdbuf_n > 0
            if canonical_mode || !wait ||
               find_newline(fdbuf.data, fdbuf.ptr, fdbuf.size) != 0
                @db 1 return readline(fdbuf; keep=keep)
            end
        end

        # Read new data from fd into line buffer.
        n = UnixIO.transfer(fd, linebuf, 1, length(linebuf))
        if n == 0
            line = take!(fdbuf)
            @db 1 return String(line) "EOF or timeout!"
        end

        # Prepend old data from the fd buffer.
        if fdbuf_n > 0
            prepend!(linebuf, take!(fdbuf))
            n += fdbuf_n
        end

        # Search for end of line...
        i = find_newline(linebuf, 1, n)

        # In canonical mode, `read(2)` never returns partial lines and
        # may return lines without a newline character (if C.CEOF was sent).
        if i == 0 && (canonical_mode || !wait)
            i = n
        end

        if i != n
            # Copy everything after the newline (or after 0) into fd buffer.
            Base.write(fd.buffer, view(linebuf, i+1:n))
            @db 1 "$(repr(String(take!(copy(fd.buffer))))) -> buffer"
        end

        if i != 0
            # Found end of line.
            while !keep && i > 0 && (linebuf[i] == UInt8('\r') ||
                                     linebuf[i] == UInt8('\n'))
                i -= 1
            end
            resize!(linebuf, i)

            line = String(linebuf)
            @db 1 return line
        end
    end
end


@db 2 function find_newline(buf, i, j)
    checkbounds(buf, i:j)
    while i <= j
        if @inbounds buf[i] == UInt8('\n')
            @db 2 return i
        end
        i += 1
    end
    @db 2 return 0
end
=#




# End of file: ReadFD.jl
