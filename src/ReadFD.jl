"""
Read-only Unix File Descriptor.
"""
mutable struct ReadFD <: UnixFD
    fd::Cint 
    iswaiting::Bool
    ready::Threads.Condition
    timeout::Float64
    deadline::Float64 # FIXME
    events::Cint # FIXME
    buffer::IOBuffer
    function ReadFD(fd, timeout=Inf)
        fcntl_setfl(fd, C.O_NONBLOCK)
        new(fd, false, Threads.Condition(), timeout, 0, 0, PipeBuffer())
    end
end


function Base.close(fd::ReadFD)
    take!(fd.buffer)
    if C.close(fd) == -1
        throw(ccall_error(:close, fd))
    end
    nothing
end


Base.isopen(fd::ReadFD) =
    bytesavailable(fd.buffer) > 0 ||
    C.fcntl(fd, C.F_GETFL) != -1


@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::ReadFD) = UnixIO.shutdown(fd, C.SHUT_RD)
end


Base.isreadable(fd::ReadFD) = Base.isopen(fd)


Base.iswritable(::ReadFD) = false


Base.bytesavailable(fd::ReadFD) = bytesavailable(fd.buffer)


function Base.eof(fd::ReadFD; kw...)
    if bytesavailable(fd.buffer) == 0
        Base.write(fd.buffer, readavailable(fd; kw...))
    end
    return bytesavailable(fd.buffer) == 0
end


function Base.unsafe_read(fd::ReadFD, buf::Ptr{UInt8}, nbytes::UInt; kw...)
    nread = 0
    while nread < nbytes
        n = UnixIO.read(fd, buf + nread, nbytes - nread; kw...)
        if n == 0
            throw(EOFError())
        end
        nread += n
    end
    nothing
end


function Base.read(fd::ReadFD, ::Type{UInt8}; kw...)
    eof(fd; kw...) && throw(EOFError())
    @assert bytesavailable(fd.buffer) > 0
    Base.read(fd.buffer, UInt8)
end


Base.readbytes!(fd::ReadFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)


function Base.readbytes!(fd::ReadFD, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, kw...)
    lb::Int = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
            resize!(buf, lb)
        end
        @assert lb > nread
        n = UnixIO.read(fd, view(buf, nread+1:lb); kw...)
        if n == 0 || !all
            break
        end
        nread += n
    end
    return nread
end


const BUFFER_SIZE = 65536

function Base.readavailable(fd::ReadFD; kw...)
    buf = Vector{UInt8}(undef, BUFFER_SIZE)
    n = UnixIO.read(fd, buf; kw...)
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
