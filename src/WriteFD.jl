"""
Write-only Unix File Descriptor.
"""
mutable struct WriteFD{EventSource} <: UnixFD{EventSource}
    fd::Cint 
    isclosed::Bool
    isdead::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    timeout::Float64
    function WriteFD{T}(fd, timeout=Inf) where T
        fcntl_setfl(fd, C.O_NONBLOCK)
        fd = new{T}(fd, false, false, 0, Base.ThreadSynchronizer(), timeout)
        register_unix_fd(fd)
        fd
    end
    WriteFD(a...) = WriteFD{DefaultEvents}(a...)
end


transfer(fd::WriteFD, buf, count) = C.write(fd, buf, count)


@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::WriteFD) = UnixIO.shutdown(fd, C.SHUT_WR)
end


Base.iswritable(fd::WriteFD) = Base.isopen(fd)


Base.isreadable(::WriteFD) = false


function Base.unsafe_write(fd::WriteFD, buf::Ptr{UInt8}, nbytes::UInt)
                                         @dbf 4 :unsafe_write (fd, buf, nbytes)
    @require !fd.isclosed
    nwritten = 0
    while nwritten < nbytes
        n = UnixIO.write(fd, buf + nwritten, nbytes - nwritten)
        nwritten += n
    end
    @ensure nwritten == nbytes                                 ;@dbr 4 nwritten
    return Int(nwritten)
end



# End of file: WriteFD.jl
