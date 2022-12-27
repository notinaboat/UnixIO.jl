"""
Read-only Unix File Descriptor.
"""


@db 1 function IOTraits._bytesavailable(fd::FD, ::ReadSizeAPI{:FIONREAD})
    x = Ref(Cint(0))
    @cerr allow=C.EIO C.ioctl(fd, C.FIONREAD, x)
    @db 1 return x[]
end

@db function IOTraits._blocksize(fd::FD, ::BlockSizeAPI{:DKIOCGETBLOCKSIZE})
    x = Ref{UInt32}()
    @cerr C.ioctl(fd, C.DKIOCGETBLOCKSIZE, x)
    @db 1 return x[]
end


@db function IOTraits._blocksize(fd::FD, ::BlockSizeAPI{:BLKSSZGET})
    x = Ref{UInt32}()
    @cerr C.ioctl(fd, C.BLKSSZGET, x)
    @db 1 return x[]
end


@db function IOTraits._length(fd::FD, ::LengthAPI{:DKIOCGETBLOCKCOUNT})
    x = Ref{UInt64}()
    @cerr C.ioctl(fd, C.DKIOCGETBLOCKCOUNT, x)
    x[] *= IOTraits.blocksize(fd)
    @db 1 return x[]
end


@db function IOTraits._length(fd::FD, ::LengthAPI{:BLKGETSIZE64})
    x = Ref{UInt64}()
    @cerr C.ioctl(fd, C.BLKGETSIZE64, x)
    @db 1 return x[]
end


@db function IOTraits._position(fd::FD, ::Cursors{:Seekable})
    @cerr allow=C.EBADF C.lseek(fd, 0, C.SEEK_CUR)
end


#=
@db 1 function Base.readline(fd::ReadFD{<:S_IFCHR};
                             timeout=fd.timeout,
                             wait=true,
                             keep::Bool=false)
    @require !fd.isclosed

    linebuf = Vector{UInt8}(undef, C.MAX_CANON)
    fdbuf = fd.buffer

    canonical_mode = iscanon(fd) && !(fd isa ReadFD{Pseudoterminal})

    @with_timeout fd timeout while true

        # If the fd buffer already contains a complete line, return it.
        fdbuf_n = bytesavailable(fdbuf)
        if fdbuf_n > 0
            if canonical_mode || !wait ||
               find_newline(fdbuf.data, fdbuf.ptr, fdbuf.size) != 0
                @db 1 return readline(fdbuf; keep=keep)
            end
        end

        # Read new data from fd into line buffer.
        n = UnixIO.transfer(fd, linebuf, 1, length(linebuf))
        if n == 0
            line = take!(fdbuf)
            @db 1 return String(line) "EOF or timeout!"
        end

        # Prepend old data from the fd buffer.
        if fdbuf_n > 0
            prepend!(linebuf, take!(fdbuf))
            n += fdbuf_n
        end

        # Search for end of line...
        i = find_newline(linebuf, 1, n)

        # In canonical mode, `read(2)` never returns partial lines and
        # may return lines without a newline character (if C.CEOF was sent).
        if i == 0 && (canonical_mode || !wait)
            i = n
        end

        if i != n
            # Copy everything after the newline (or after 0) into fd buffer.
            Base.write(fd.buffer, view(linebuf, i+1:n))
            @db 1 "$(repr(String(take!(copy(fd.buffer))))) -> buffer"
        end

        if i != 0
            # Found end of line.
            while !keep && i > 0 && (linebuf[i] == UInt8('\r') ||
                                     linebuf[i] == UInt8('\n'))
                i -= 1
            end
            resize!(linebuf, i)

            line = String(linebuf)
            @db 1 return line
        end
    end
end


@db 2 function find_newline(buf, i, j)
    checkbounds(buf, i:j)
    while i <= j
        if @inbounds buf[i] == UInt8('\n')
            @db 2 return i
        end
        i += 1
    end
    @db 2 return 0
end
=#




# End of file: ReadFD.jl
