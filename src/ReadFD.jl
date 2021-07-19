"""
Read-only Unix File Descriptor.
"""
mutable struct ReadFD{T, EventSource} <: UnixFD{T, EventSource}
    fd::RawFD
    isclosed::Bool
    #isdead::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    timeout::Float64
    deadline::Float64
    buffer::IOBuffer
    function ReadFD{T, E}(fd, timeout=Inf) where {T, E}
        fcntl_setfl(fd, C.O_NONBLOCK)
        fd = new{T, E}(
               RawFD(fd),
               false,
               #false,
               0,
               Base.ThreadSynchronizer(),
               timeout,
               Inf,
               PipeBuffer())
        register_unix_fd(fd)
        fd
    end
    function ReadFD{EventSource}(fd, a...) where EventSource
        T = fdtype(fd)
        ReadFD{T, EventSource}(fd, a...)
    end
    ReadFD(a...) = ReadFD{DefaultEvents}(a...)
end


@db 2 function raw_transfer(fd::ReadFD, buf, count)
    n = C.read(fd.fd, buf, count)
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


@db 4 function Base.eof(fd::ReadFD; timeout=Inf, kw...)
    if bytesavailable(fd.buffer) == 0 && isopen(fd)
        Base.write(fd.buffer, readavailable(fd; timeout=timeout, kw...))
    end
    r = bytesavailable(fd.buffer) == 0
    @db 4 return r
end


@db 1 function Base.unsafe_read(fd::ReadFD, buf::Ptr{UInt8}, nbytes::UInt;
                                timeout=fd.timeout, kw...)
    @require !fd.isclosed

    @with_timeout fd timeout begin
        nread = 0
        while nread < nbytes
            n = UnixIO.read(fd, buf + nread, nbytes - nread; kw...)
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
                               all::Bool=true, timeout=fd.timeout, kw...)
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
            n = UnixIO.read(fd, view(buf, nread+1:lb); kw...)
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

@db 2 function Base.readuntil(fd::ReadFD, d::AbstractChar;
                              timeout=fd.timeout, kw...)
    @with_timeout(fd, timeout,
                  invoke(Base.readuntil, Tuple{IO, AbstractChar},
                                               fd, d; kw...))
end

@db 2 function Base.read(fd::ReadFD, n::Integer=typemax(Int);
                         timeout=fd.timeout, kw...)
    @with_timeout(fd, timeout,
                  invoke(Base.read, Tuple{IO, Integer}, fd, n; kw...))
end

@db 2 function Base.read(fd::ReadFD, x::Type{String}; kw...)
    String(Base.read(fd; kw...))
end


# End of file: ReadFD.jl
