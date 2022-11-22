"""
Write-only Unix File Descriptor.
"""



shutdown(fd::FD{Out}) = shutdown(fd, C.SHUT_WR)

@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::FD{Out}) = UnixIO.shutdown(fd, C.SHUT_WR)
end


#=
Base.iswritable(fd::FD{Out}) = Base.isopen(fd)


Base.isreadable(::FD{Out}) = false
=#


@db 1 function Base.unsafe_write(fd::FD{Out}, buf::Ptr{UInt8}, nbytes::UInt)
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


Base.write(fd::FD{Out}, x::UInt8) = transfer(fd, [x], 1, 1)



# End of file: WriteFD.jl
