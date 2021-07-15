"""
Write-only Unix File Descriptor.
"""
mutable struct WriteFD <: UnixFD
    fd::Cint 
    iswaiting::Bool
    ready::Threads.Condition
    timeout::Float64
    deadline::Float64 # FIXME
    events::Cint # FIXME
    function WriteFD(fd, timeout=Inf)
        fcntl_setfl(fd, C.O_NONBLOCK)
        new(fd, false, Threads.Condition(), timeout, 0)
    end
end


function Base.close(fd::WriteFD)
    if C.close(fd) == -1
        throw(ccall_error(:close, fd))
    end
    nothing
end


Base.isopen(fd::WriteFD) = C.fcntl(fd, C.F_GETFL) != -1


@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::WriteFD) = UnixIO.shutdown(fd, C.SHUT_WR)
end


Base.iswritable(fd::WriteFD) = Base.isopen(fd)


Base.isreadable(::WriteFD) = false


function Base.unsafe_write(fd::WriteFD, buf::Ptr{UInt8}, nbytes::UInt)
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



# End of file: WriteFD.jl
