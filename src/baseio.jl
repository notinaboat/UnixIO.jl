# Base.IO Interface


function Base.close(fd::UnixFD)
    if C.close(fd) == -1
        throw(ccall_error(:close, fd))
    end
    nothing
end

Base.isopen(fd::UnixFD) =
    bytesavailable(fd.read_buffer) > 0 ||
    C.fcntl(fd, C.F_GETFL) != -1


Base.bytesavailable(fd::UnixFD) = bytesavailable(fd.read_buffer)


function Base.eof(fd::UnixFD; kw...)
    if bytesavailable(fd.read_buffer) == 0
        Base.write(fd.read_buffer, readavailable(fd; kw...))
    end
    return bytesavailable(fd.read_buffer) == 0
end


function Base.unsafe_read(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt; kw...)
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


function Base.read(fd::UnixFD, ::Type{UInt8}; kw...)
    eof(fd; kw...) && throw(EOFError())
    @assert bytesavailable(fd.read_buffer) > 0
    Base.read(fd.read_buffer, UInt8)
end


Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)

function Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes::UInt;
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

function Base.readavailable(fd::UnixFD; kw...)
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

Base.readline(fd::UnixFD; timeout=Inf, kw...) =
    invoke_with_timeout(fd, timeout, readline, Tuple{IO}; kw...)

Base.readuntil(fd::UnixFD, d::AbstractChar; timeout=Inf, kw...) =
    invoke_with_timeout(fd, timeout, readuntil, Tuple{IO, AbstractChar}, d;
                        kw...)

Base.read(fd::UnixFD, n::Integer=typemax(Int); timeout=Inf, kw...) =
    invoke_with_timeout(fd, timeout, Base.read, Tuple{IO, Integer}, n; kw...)

Base.read(fd::UnixFD, x::Type{String}; kw...) = String(Base.read(fd; kw...))


function Base.unsafe_write(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt)
    nwritten = 0
    while nwritten < nbytes
        n = UnixIO.write(fd, buf + nwritten, nbytes - nwritten)
        if n == -1
            throw(ccall_error(:write, buf + nwritten, nbytes - nwritten))
        end
        @assert n > 0
        nwritten += n
    end
    return Int(nwritten)
end



# End of file: baseio.jl
