"""
Read-only Unix File Descriptor.
"""
mutable struct ReadFD{EventSource} <: UnixFD{EventSource}
    fd::Cint
    isclosed::Bool
    isdead::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    timeout::Float64
    buffer::IOBuffer
    function ReadFD{T}(fd, timeout=Inf) where T
        fcntl_setfl(fd, C.O_NONBLOCK)
        fd = new{T}(fd,
               false,
               false,
               0,
               Base.ThreadSynchronizer(),
               timeout,
               PipeBuffer())
        register_unix_fd(fd)
        fd
    end
    ReadFD(a...) = ReadFD{DefaultEvents}(a...)
end


function transfer(fd::ReadFD, buf, count)         ;@dbf 4 :transfer (fd, count)
    n = C.read(fd.fd, buf, count)                                     ;@dbr 4 n
    return n
end


function Base.close(fd::ReadFD)                             ;@db 2 "close($fd)"
    take!(fd.buffer)
    invoke(Base.close, Tuple{UnixFD}, fd)
end


# FIXME can be !isopen() but not yet eof().
#Base.isopen(fd::ReadFD) = !eof(fd) || !isclosed(fd)


@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::ReadFD) = UnixIO.shutdown(fd, C.SHUT_RD)
end


Base.isreadable(fd::ReadFD) = Base.isopen(fd)


Base.iswritable(::ReadFD) = false


Base.bytesavailable(fd::ReadFD) = bytesavailable(fd.buffer)
#FIXME getsockopt - SO_NREAD ?
#FIXME ioctl FIONREAD ?


function Base.eof(fd::ReadFD; timeout=Inf)                      ;@dbf 4 :eof fd
    if bytesavailable(fd.buffer) == 0 && isopen(fd)
        Base.write(fd.buffer, readavailable(fd; timeout=timeout))
    end
    r = bytesavailable(fd.buffer) == 0                                ;@dbr 4 r
    return r
end

#FIXME set deadline at outer call

function Base.unsafe_read(fd::ReadFD, buf::Ptr{UInt8}, nbytes::UInt; kw...)
                                          @dbf 3 :unsafe_read (fd, buf, nbytes)
    @require !fd.isclosed
    nread = 0
    while nread < nbytes
        n = UnixIO.read(fd, buf + nread, nbytes - nread; kw...)
        if n == 0
            throw(EOFError())
        end
        nread += n
    end
    @ensure nread == nbytes                                       ;@dbr 3 nread
    nothing
end


function Base.read(fd::ReadFD, ::Type{UInt8}; kw...)  ;@db 3 "read($fd, UInt8)"
    @require !fd.isclosed
    eof(fd; kw...) && throw(EOFError())
    @assert bytesavailable(fd.buffer) > 0
    Base.read(fd.buffer, UInt8)
end


Base.readbytes!(fd::ReadFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)


function Base.readbytes!(fd::ReadFD, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, kw...)
                                                @dbf 5 :readbytes! (fd, nbytes)
    @require !fd.isclosed
    lb::Int = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
            resize!(buf, lb)                             ;@db 5 "resize -> $lb"
        end
        @assert lb > nread
        n = UnixIO.read(fd, view(buf, nread+1:lb); kw...)
        if n == 0 || !all
            break
        end
        nread += n
    end
    @ensure nread <= nbytes                                       ;@dbr 5 nread
    return nread
end


const BUFFER_SIZE = 65536

function Base.readavailable(fd::ReadFD; timeout=0)    ;@dbf 5 :readavailable fd
    @require !fd.isclosed
    buf = Vector{UInt8}(undef, BUFFER_SIZE)
    n = UnixIO.read(fd, buf; timeout=timeout)                         ;@dbr 5 n
    resize!(buf, n)
end


function invoke_with_timeout(fd, timeout, f, types, args...; kw...)
    old_timeout = fd.timeout
    fd.timeout = timeout
    try
        invoke(f, types, fd, args...; kw...)
    finally
        fd.timeout = old_timeout
    end
end

Base.readline(fd::ReadFD; timeout=Inf, kw...) =
    invoke_with_timeout(fd, timeout, readline, Tuple{IO}; kw...)

Base.readuntil(fd::ReadFD, d::AbstractChar; timeout=Inf, kw...) =
    invoke_with_timeout(fd, timeout, readuntil, Tuple{IO, AbstractChar}, d;
                        kw...)

Base.read(fd::ReadFD, n::Integer=typemax(Int); timeout=Inf, kw...) =
    invoke_with_timeout(fd, timeout, Base.read, Tuple{IO, Integer}, n; kw...)

Base.read(fd::ReadFD, x::Type{String}; kw...) = String(Base.read(fd; kw...))



# End of file: ReadFD.jl
