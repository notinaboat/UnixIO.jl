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


function Base.read(fd::UnixFD, nbytes::Integer = typemax(Int); kw...)
    buf = Vector{UInt8}(undef, nbytes == typemax(Int) ? BUFFER_SIZE : nbytes)
    nread = readbytes!(fd, buf, nbytes; kw...)
    return resize!(buf, nread)
end


Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)

function Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, kw...)
    lb = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
            resize!(buf, lb)
        end
        @assert lb > nread
        n = GC.@preserve buf UnixIO.read(fd, pointer(buf) + nread, lb - nread;
                                         kw...)
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
    n = UnixIO.read(fd, buf, length(buf); kw...)
    resize!(buf, n)
end


function Base.readline(fd::UnixFD; keep::Bool=false, timeout=Inf)
    old_timeout = fd.timeout
    fd.timeout = timeout
    try
        invoke(readline, Tuple{IO}, fd; keep=keep)
    finally
        fd.timeout = old_timeout
    end
end


function Base.unsafe_write(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt)
    nwritten = 0
    while nwritten < nbytes
        n = UnixIO.write(fd, buf + nwritten, nbytes - nwritten)
        if n == -1
            throw(ccall_error(:write, buf + nwritten, nbytes - nwritten))
        end
        nwritten += n
    end
    return Int(nwritten)
end



# End of file: baseio.jl
