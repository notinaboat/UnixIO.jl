"""
Read-only Unix File Descriptor.
"""
mutable struct ReadFD{T, EventSource} <: UnixFD{T, EventSource}
    fd::RawFD
    isclosed::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    closed::Base.ThreadSynchronizer
    timeout::Float64
    deadline::Float64
    gothup::Bool
    buffer::IOBuffer
    extra::ImmutableDict{Symbol,Any}
    function ReadFD{T, E}(fd) where {T, E}
        fcntl_setfl(fd, C.O_NONBLOCK)
        fd = new{T, E}(
               RawFD(fd),
               false,
               0,
               Base.ThreadSynchronizer(),
               Base.ThreadSynchronizer(),
               Inf,
               Inf,
               false,
               PipeBuffer(),
               ImmutableDict{Symbol,Any}())
        register_unix_fd(fd)
        return fd
    end
    ReadFD(fd; events = default_event_source(fd)) =
        ReadFD{fdtype(fd)}{events}(fd)
end


set_extra(fd::UnixFD, key::Symbol, value) =
    fd.extra = ImmutableDict(fd.extra, key => value)

function get_extra(fd::UnixFD, key::Symbol, default)
    x = get(fd.extra, key, nothing)
    if x == nothing
        x = default()
        set_extra(fd, key, x)
    end
    return x
end


@db 2 function raw_transfer(fd::ReadFD, buf, count)
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

The remaining problem is that because `read(2)` will never returns `0` there
is no way to detect when the client has closed the terminal.
This `raw_transfer` method handles this by checking if the client process
is still alive and returning `0` if it has terminated.
"""
@db 2 function raw_transfer(fd::ReadFD{<:Pseudoterminal}, buf, count)
    n = C.read(fd.fd, buf, count)
    if n == -1
        err = errno()
        if err == C.EAGAIN && !isalive(fd.extra[:pt_client])
            @db 2 return 0 "Pseudoterminal client process died. -> HUP!"
        end
    end
    @db 2 return n
end


@db function Base.close(fd::ReadFD)
    take!(fd.buffer)
    @invoke Base.close(fd::UnixFD)
end


# FIXME can be !isopen() but not yet eof().
#Base.isopen(fd::ReadFD) = !eof(fd) || !isclosed(fd)

shutdown(fd::ReadFD) = shutdown(fd, C.SHUT_RD)

@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::ReadFD) = UnixIO.shutdown(fd, C.SHUT_RD)
end


Base.isreadable(fd::ReadFD) = Base.isopen(fd)


Base.iswritable(::ReadFD) = false


Base.bytesavailable(fd::ReadFD) = bytesavailable(fd.buffer)
#FIXME getsockopt - SO_NREAD ?
#FIXME ioctl FIONREAD ?


@db 4 function Base.eof(fd::ReadFD; timeout=Inf)
    if bytesavailable(fd.buffer) == 0 && isopen(fd)
        Base.write(fd.buffer, readavailable(fd; timeout=timeout))
    end
    r = bytesavailable(fd.buffer) == 0
    @db 4 return r
end


@db 1 function Base.unsafe_read(fd::ReadFD, buf::Ptr{UInt8}, nbytes::UInt;
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


@db 3 function Base.read(fd::ReadFD, ::Type{UInt8}; kw...)
    @require !fd.isclosed
    eof(fd; kw...) && throw(EOFError())
    @assert bytesavailable(fd.buffer) > 0
    r = Base.read(fd.buffer, UInt8)          ;@db 2 "from buffer: '$(Char(r))'"
    @db 3 return r
end


Base.readbytes!(fd::ReadFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)


@db 1 function Base.readbytes!(fd::ReadFD, buf::Vector{UInt8}, nbytes::UInt;
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
            n = UnixIO.read(fd, view(buf, nread+1:lb))
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

@db 5 function Base.readavailable(fd::ReadFD; timeout=0)
    @require !fd.isclosed
    buf = Vector{UInt8}(undef, BUFFER_SIZE)
    n = UnixIO.read(fd, buf; timeout=timeout)                          ;@db 5 n
    resize!(buf, n)
end


@db 2 function Base.readline(fd::ReadFD;
                             timeout=fd.timeout, kw...)
    @with_timeout(fd, timeout, @invoke Base.readline(fd::IO; kw...))
end


"""
### `readline(::UnixIO.ReadFD{S_IFCHR})`

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
"""
@db 1 function Base.readline(fd::ReadFD{<:S_IFCHR};
                             timeout=fd.timeout, keep=false)
    @require !fd.isclosed

    linebuf = Vector{UInt8}(undef, C.MAX_CANON)
    fdbuf = fd.buffer

    @with_timeout fd timeout while true

        # If the fd buffer already contains a complete line, return it.
        fdbuf_n = bytesavailable(fdbuf)
        if fdbuf_n > 0
            if iscanon(fd) ||
               find_newline(fdbuf.data, fdbuf.ptr, fdbuf.size) != 0
                @db 1 return readline(fdbuf; keep=keep)
            end
        end

        # Read new data from fd into line buffer.
        n = UnixIO.transfer(fd, linebuf, length(linebuf))
        if n == 0
            @db 1 return String(take!(fdbuf)) "EOF or timeout!"
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
        if i == 0 && iscanon(fd)
            i = n
        end

        if i != n
            # Copy everything after the newline (or after 0) into fd buffer.
            Base.write(fd.buffer, view(linebuf, i+1:n))
            @db 1 "\"$(String(take!(copy(fd.buffer))))\" -> buffer"
        end

        if i != 0
            # Found end of line.
            while !keep && (linebuf[i] == UInt8('\r') ||
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


@db 2 function Base.readuntil(fd::ReadFD, d::AbstractChar;
                              timeout=fd.timeout, kw...)
    @with_timeout(fd, timeout,
                  @invoke Base.readuntil(fd::IO, d::AbstractChar; kw...))
end

@db 2 function Base.read(fd::ReadFD, n::Integer=typemax(Int);
                         timeout=fd.timeout)
    @with_timeout(fd, timeout, @invoke Base.read(fd::IO, n::Integer))
end

@db 2 function Base.read(fd::ReadFD, x::Type{String}; kw...)
    String(Base.read(fd; kw...))
end


# End of file: ReadFD.jl
