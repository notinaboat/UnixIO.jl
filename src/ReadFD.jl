"""
Read-only Unix File Descriptor.
"""
mutable struct ReadFD{T, EventSource} <: UnixFD{T, EventSource}
    fd::RawFD
    isclosed::Bool
    #isdead::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    closed::Base.ThreadSynchronizer
    timeout::Float64
    deadline::Float64
    buffer::IOBuffer
    function ReadFD{T, E}(fd) where {T, E}
        fcntl_setfl(fd, C.O_NONBLOCK)
        fd = new{T, E}(
               RawFD(fd),
               false,
               #false,
               0,
               Base.ThreadSynchronizer(),
               Base.ThreadSynchronizer(),
               Inf,
               Inf,
               PipeBuffer())
        register_unix_fd(fd)
        return fd
    end
    ReadFD(fd; events = default_event_source(fd)) =
        ReadFD{fdtype(fd)}{events}(fd)
end


@db 2 function raw_transfer(fd::ReadFD, buf, count)
    n = C.read(fd.fd, buf, count)
    @db 2 return n
end


"""
PTS master returns EIO when slave has disconnected.
Returning 0 here emulates normal end of stream behaviour.
"""
@db 2 function raw_transfer(fd::ReadFD{PtsMaster}, buf, count)
    n = C.read(fd.fd, buf, count)
    if n == -1 && errno() == C.EIO;                         @db 2 "$fd -> EIO!"
        n = 0
    end
    @db 2 return n
end


@db function Base.close(fd::ReadFD)
    take!(fd.buffer)
    invoke(Base.close, Tuple{UnixFD}, fd)
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
                resize!(buf, lb)                             ;@db 1 "resize -> $lb"
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
    @with_timeout(fd, timeout,
                  invoke(Base.readline, Tuple{IO}, fd; kw...))
end


"""
### `readline(::UnixIO.ReadFD{S_IFCHR})`

Character or Terminal devices (`S_IFCHR`) are usually used in
"canonical mode" (`ICANON`).

> In canonical mode: Input is made available line by line.
(termios(3))[https://man7.org/linux/man-pages/man3/termios.3.html].

For these devices calling `read(2)` will usually return exactly one line.
It will only ever return an incomplete line if length exceeded `MAX_CANON`.

This `readline` implementation is optimised for the case where `read(2)`
returns exactly one line. However it does not assume that behaviour and
will still work for devices not in canonical mode.
"""
@db 2 function Base.readline(fd::ReadFD{S_IFCHR};
                             timeout=fd.timeout, keep=false)
    @require !fd.isclosed

    @with_timeout fd timeout while true

        # If the fd buffer contains a complete line, return that.
        buf = fd.buffer
        if bytesavailable(buf) > 0
            i = find_newline(buf.data, buf.ptr, buf.size)
            if i != 0
                line = readline(buf)
                @db 2 return line
            end
        end

        # Read from fd into line buffer.
        linebuf = Vector{UInt8}(undef, C.MAX_CANON)
        n = UnixIO.transfer(fd, linebuf, length(linebuf))

        # At eof (or timeout) return empty line.
        if n == 0
            @db 2 return ""
        end

        # Search for end of line...
        i = find_newline(linebuf, 1, n)
        if i != n
            # Copy everything after the newline (or after 0) into fd buffer.
            Base.write(fd.buffer, view(linebuf, i+1:n))
        end
        if i != 0
            # Found end of line.
            if !keep
                i -= (i > 1 && linebuf[i-1] == UInt8('\r') ? 2 : 1)
            end
            resize!(linebuf, i)
            line = String(linebuf)
            @db 2 return line
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
                  invoke(Base.readuntil, Tuple{IO, AbstractChar},
                                               fd, d; kw...))
end

@db 2 function Base.read(fd::ReadFD, n::Integer=typemax(Int);
                         timeout=fd.timeout)
    @with_timeout(fd, timeout,
                  invoke(Base.read, Tuple{IO, Integer}, fd, n))
end

@db 2 function Base.read(fd::ReadFD, x::Type{String}; kw...)
    String(Base.read(fd; kw...))
end


# End of file: ReadFD.jl
