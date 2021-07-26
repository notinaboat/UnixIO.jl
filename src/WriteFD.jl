"""
Write-only Unix File Descriptor.
"""
mutable struct WriteFD{T, EventSource} <: UnixFD{T, EventSource}
    fd::RawFD 
    isclosed::Bool
    nwaiting::Int
    ready::Base.ThreadSynchronizer
    closed::Base.ThreadSynchronizer
    timeout::Float64
    deadline::Float64
    gothup::Bool
    extra::ImmutableDict{Symbol,Any}
    function WriteFD{T, E}(fd) where {T, E}
        fcntl_setfl(fd, C.O_NONBLOCK)
        fcntl_setfd(fd, C.O_CLOEXEC)
        fd = new{T, E}(RawFD(fd),
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
    WriteFD(fd; events = default_event_source(fd)) =
        WriteFD{fdtype(fd)}{events}(fd)
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
    nwritten = 0
    while nwritten < nbytes
        n = UnixIO.write(fd, buf + nwritten, nbytes - nwritten)
        nwritten += n
    end
    @ensure nwritten == nbytes
    @db 1 return Int(nwritten)
end


Base.write(fd::WriteFD, x::UInt8) = UnixIO.write(fd, Ref(x), 1)



# End of file: WriteFD.jl
