"""
Write-only Unix File Descriptor.
"""
mutable struct WriteFD{T} <: UnixFD{T}
    fd::RawFD 
    isclosed::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    closed::Base.ThreadSynchronizer
    timeout::Float64
    deadline::Float64
    gothup::Bool
    extra::ImmutableDict{Symbol,Any}
    function WriteFD{T}(fd) where T
        fcntl_setfl(fd, C.O_NONBLOCK)
        fcntl_setfd(fd, C.O_CLOEXEC)
        fd = new{T}(RawFD(fd),
                    false,
                    0,
                    Base.ThreadSynchronizer(),
                    Base.ThreadSynchronizer(),
                    Inf,
                    Inf,
                    false,
                    ImmutableDict{Symbol,Any}())
        return fd
    end
    function WriteFD(T::Type, fd)
        T = (T == Union{}) ? fdtype(fd) : T
        WriteFD{T}(fd)
    end
    WriteFD(fd) = WriteFD(Union{}, fd)
end


raw_transfer(fd::WriteFD, buf, count) = C.write(fd, buf, count)


shutdown(fd::WriteFD) = shutdown(fd, C.SHUT_WR)

@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::WriteFD) = UnixIO.shutdown(fd, C.SHUT_WR)
end


Base.iswritable(fd::WriteFD) = Base.isopen(fd)


Base.isreadable(::WriteFD) = false


@db 1 function Base.unsafe_write(fd::WriteFD, buf::Ptr{UInt8}, nbytes::UInt)
    @require !fd.isclosed 
    nwritten = 0                   ;if nbytes < 100
                                        @db 1 repr(unsafe_string(buf, nbytes))
                                    end
    while nwritten < nbytes
        n = transfer(fd, buf + nwritten, nbytes - nwritten)
        nwritten += n
    end
    @ensure nwritten == nbytes
    @db 1 return Int(nwritten)
end


Base.write(fd::WriteFD, x::UInt8) = transfer(fd, [x], 1, 1)



# End of file: WriteFD.jl
