@doc README"""
### `UnixIO.openpt()` -- Open a pseudoterminal device.

    UnixIO.openpt([flags = C._NOCTTY | C.O_RDWR]) -> ptfd::UnixIO.FD, "/dev/pts/X"

Open an unused pseudoterminal device, returning:
a file descriptor that can be used to refer to that device,
and the path of the pseudoterminal device.

See [posix_openpt(3)](https://man7.org/linux/man-pages/man2/posix_openpt.3.html)
and [prsname(3)](https://man7.org/linux/man-pages/man2/prsname.3.html).
"""
@db function openpt(flags = C.O_NOCTTY | C.O_RDWR)

    pt = @cerr C.posix_openpt(flags)
    @assert ispt(pt)
    @cerr C.grantpt(pt)
    @cerr C.unlockpt(pt)

    path = ptsname(pt)
    clientfd = @cerr C.open(path, C.O_RDONLY | C.O_NOCTTY)
    @assert !ispt(clientfd)

    tcsetattr(pt) do attr
        setraw(attr)
        attr.c_lflag |= C.ICANON
    end

    pt_dup = C.dup(pt)
    C.shutdown(pt, C.SHUT_RD)
    C.shutdown(pt_dup, C.SHUT_WR)
    ptin = FD{In}(pt_dup)
    ptout = FD{Out}(pt)
    set_extra(ptin, :pt_clientfd, clientfd)

    @db return ptin, ptout, path
end


function ptsname(fd)
    buf = Vector{UInt8}(undef, 100)
    p = pointer(buf)
    GC.@preserve buf @cerr C.ptsname_r(fd, p, length(buf))
    unsafe_string(p)
end


ispt(fd) = C.ptsname(fd) != C_NULL


@db 1 function Base.close(fd::FD{In,Pseudoterminal})
    C.close(fd.extra[:pt_clientfd])
    @invoke Base.close(fd::FD{In})
end


@db 1 function Base.close(fd::FD{Out,Pseudoterminal})
    if isopen(fd)
        fd.isconnected = false
        # FIXME tcdrain ?
        if iscanon(fd)
            # First CEOF terminates a possible un-terminated line.
            # Second CEOF signals terminal closing.
            for _ in 1:2
                @cerr allow=C.EIO C.write(fd, Ref(UInt8(C.CEOF)), 1)
            end
        end
    end
    @invoke Base.close(fd::FD{Out})
end


"""
### Reading from a pseudoterminal device.

Reading from a pseudoterminal device is a special case.

On Linux `read(2)` returns `EIO` when called before a client has connected.
If a client connects, writes some data and then disconnects before `read(2)`
is called: `read(2)` returns the data and then returns `EIO` if called again.

On macOS `read(2)` returns `0` when called before a client has connected.
If a client connects, writes some data and then disconnects before `read(2)`
is called: `read(2)` simply returns `0` and the data is lost.

To avoid this situation a duplicate client fd is held open for the lifetime
of the pseudoterminal device (`fd.extra[:pt_clientfd]`). This has the effect that
`read(2)` will always return `EAGAIN` if there is no data available.
(The reader then waits for `poll(2)` to indicate when data is ready as usual.)

The remaining problem is that because `read(2)` will never return `0` there
is no way to detect when the client has closed the terminal.
This `raw_transfer` method handles this by checking if the client process
is still alive and returning `0` if it has terminated.
"""
@db 2 function raw_transfer(fd::FD{In,Pseudoterminal},
                            ::TransferAPI{:LibC},
                            ::IOTraits.In, buf, count,
                            deadline)
    n = C.read(fd.fd, buf, count)
    if n == -1
        err = errno()
        if err == C.EAGAIN && !isalive(fd.extra[:pt_client])
            @db 2 return 0 "Pseudoterminal client process died. -> HUP!"
        end
    end
    @db 2 return n
end


@db function IOTraits._wait(fd::FD{In,Pseudoterminal},
                            wm::T; deadline=Inf
    ) where T <: typeof(WaitAPI(FD{In,Pseudoterminal}))

    assert_havelock(fd.ready)

    process = fd.extra[:pt_client]

    while time() < deadline
        dl = min(deadline, time()+1)
        event = @invoke IOTraits._wait(fd::FD{In}, wm::T; deadline=dl)
        if  event != :timeout
            @db return event
        end
        #FIXME no need to poll for PidFD?
        if !isalive(check(process))
            fd.isconnected = false
            @db return :client_died
        end
    end
    @db return :timeout
end
