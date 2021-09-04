"""
Read-only Unix File Descriptor.
"""


@db 2 function raw_transfer(fd::FD{In}, buf, count)
    n = C.read(fd.fd, buf, count)
    @db 2 return n
end


"""
### Reading from a pseudoterminal device.

Reading from a pseudoterminal device is a special case.

On Linux `read(2)` return `EIO` when called before a client has connected.
If a client connects, writes some data and then disconnects before `read(2)`
is called: `read(2)` returns the data and then returns `EIO` if called again.

On macOS `read(2)` returns `0` when called before a client has connected.
If a client connects, writes some data and then disconnects before `read(2)`
is called: `read(2)` simply returns `0` and the data is lost.

To avoid this situation a a duplicate client fd is held open for the lifetime
of the pseudoterminal device (`fd.extra[:pt_clientfd]`). This has the effect that
`read(2)` will always return `EAGAIN` if there is no data available.
(The reader then waits for `poll(2)` to indicate when data is ready as usual.)

The remaining problem is that because `read(2)` will never return `0` there
is no way to detect when the client has closed the terminal.
This `raw_transfer` method handles this by checking if the client process
is still alive and returning `0` if it has terminated.
"""
@db 2 function raw_transfer(fd::FD{In,Pseudoterminal}, buf, count)
    n = C.read(fd.fd, buf, count)
    if n == -1
        err = errno()
        if err == C.EAGAIN && !isalive(fd.extra[:pt_client])
            @db 2 return 0 "Pseudoterminal client process died. -> HUP!"
        end
    end
    @db 2 return n
end


@db function Base.close(fd::FD{In})
    take!(fd.buffer)
    @invoke Base.close(fd::FD)
end


shutdown(fd::FD{In}) = shutdown(fd, C.SHUT_RD)

@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::FD{In}) = UnixIO.shutdown(fd, C.SHUT_RD)
end


Base.isreadable(fd::FD{In}) = Base.isopen(fd)

Base.iswritable(::FD{In}) = false


Base.bytesavailable(fd::FD{In}) = bytesavailable(fd, TransferSizeMechanism(fd))

Base.bytesavailable(fd::FD, ::NoSizeMechanism) = bytesavailable(fd.buffer)

@db 1 function Base.bytesavailable(fd::FD, ::SuppoutsStatSize)
    n = bytesavailable(fd.buffer)
    pos = @cerr allow=C.EBADF C.lseek(fd, 0, C.SEEK_CUR)
    if pos != -1
        n += stat(fd).size - pos
    end
    @db 1 return n
end

@db 1 function Base.bytesavailable(fd::FD, ::SupportsFIONREAD)
    @assert bytesavailable(fd.buffer) == 0
    x = Ref(Cint(0))
    @cerr C.ioctl(fd, C.FIONREAD, x)
    @db 1 return x[]
end


Base.eof(fd::FD{In}; kw...) = eof(fd, TotalSize(fd); kw...)

Base.eof(fd::FD, ::InfiniteTotalSize; kw...) = @assert false  
    # FIXME should block

Base.eof(fd::FD, ::KnownTotalSize; kw...) = bytesavailable(fd) == 0

@db 1 function Base.eof(fd::FD, ::UnknownTotalSize; kw...)
    if bytesavailable(fd.buffer) > 0
        @db 1 return false
    end
    event = @dblock fd wait(fd)                                    ;@db 1 event
    if event == C.POLLIN
        @db 1 return false
    end
    if !fd.isclosed
        Base.write(fd.buffer, readavailable(fd; kw...))
    end
    @db 1 return bytesavailable(fd.buffer) == 0
end


@db 1 function Base.unsafe_read(fd::FD{In}, buf::Ptr{UInt8}, nbytes::UInt;
                                timeout=fd.timeout)
    @require !fd.isclosed

    @with_timeout fd timeout begin
        nread = 0
        while nread < nbytes
            n = UnixIO.read(fd, buf + nread, nbytes - nread)
            if n == 0
                throw(EOFError())
            end
            nread += n
        end
        @ensure nread == nbytes
        nothing
    end
end


@db 2 function Base.read(fd::FD{In}, ::Type{UInt8}; kw...)
    @require !fd.isclosed
    eof(fd; kw...) && throw(EOFError())
    if bytesavailable(fd.buffer) == 0
        Base.write(fd.buffer, readavailable(fd; kw...))
    end
    r = Base.read(fd.buffer, UInt8)
    @db 2 return r                                "$(repr(Char(r))) $(repr(r))"
end


Base.readbytes!(fd::FD{In}, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)


@db 1 function Base.readbytes!(fd::FD{In}, buf::Vector{UInt8}, nbytes::UInt;
                               all::Bool=true, timeout=fd.timeout)
    @require !fd.isclosed

    @with_timeout fd timeout begin
        lb::Int = length(buf)
        nread = 0
        while nread < nbytes
            @assert nread <= lb
            if (lb - nread) == 0
                lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
                resize!(buf, lb)                         ;@db 1 "resize -> $lb"
            end
            @assert lb > nread
            n = UnixIO.read(fd, buf, nread + 1, lb - nread)
            if n == 0 || !all
                break
            end
            nread += n
        end
        @ensure nread <= nbytes
        @db 1 return nread
    end
end


const BUFFER_SIZE = 65536

@db 5 function Base.readavailable(fd::FD{In}; timeout=0)
    @require !fd.isclosed
    n = bytesavailable(fd)
    if n == 0
        n = BUFFER_SIZE
    end
    buf = Vector{UInt8}(undef, n)
    n = UnixIO.read(fd, buf; timeout)                          ;@db 5 n
    resize!(buf, n)
end


@db 2 function Base.readline(fd::FD{In}; timeout=fd.timeout, kw...)
    @with_timeout fd timeout begin
        @db 2 return readline(fd, ReadFragmentation(fd); kw...)
    end
end

Base.readline(fd::FD, ::ReadsBytes; kw...) = @invoke readline(fd::IO; kw...)


"""
### `readline(::UnixIO.FD{In,S_IFCHR})`

Character or Terminal devices (`S_IFCHR`) are usually used in
"canonical mode" (`ICANON`).

> In canonical mode: Input is made available line by line.
(termios(3))[https://man7.org/linux/man-pages/man3/termios.3.html].

For these devices calling `read(2)` will usually return exactly one line.
It will only ever return an incomplete line if length exceeded `MAX_CANON`.
Note that in canonical mode a line can be terminated by `CEOF` rather than
"\n", but `read(2)` does not return the `CEOF` character (e.g. when the
shell sends a "bash\$ " prompt without a newline).

This `readline` implementation is optimised for the case where `read(2)`
returns exactly one line. However it does not assume that behaviour and
will still work for devices not in canonical mode.

Notes:
 - TIOCSTI could be used to Insert a byte into the input queue
"""
@db 1 function Base.readline(fd::FD, ::ReadsLines; keep::Bool=false)
    @require !fd.isclosed
    @assert bytesavailable(fd.buffer) == 0

    linebuf = Vector{UInt8}(undef, C.MAX_CANON)
    n = UnixIO.transfer(fd, linebuf)
    if n == 0
        @db 1 return "" "EOF or timeout!"
    end

    # Check for '\n'.
    i = find_newline(linebuf, 1, n)
    @assert i == 0 || i == n

    # Trim end of line characters.
    while !keep && n > 0 && (linebuf[n] == UInt8('\r') ||
                             linebuf[n] == UInt8('\n'))
        n -= 1
    end
    resize!(linebuf, n)
    @db 1 return String(linebuf)
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
=#


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


@db 2 function Base.readuntil(fd::FD{In}, d::AbstractChar;
                              timeout=fd.timeout, kw...)
    @with_timeout(fd, timeout,
                  @invoke Base.readuntil(fd::IO, d::AbstractChar; kw...))
end

@db 2 function Base.read(fd::FD{In}, n::Integer=typemax(Int);
                         timeout=fd.timeout)
    @with_timeout(fd, timeout, @invoke Base.read(fd::IO, n::Integer))
end

@db 2 function Base.read(fd::FD{In}, x::Type{String}; kw...)
    String(Base.read(fd; kw...))
end


# End of file: ReadFD.jl
