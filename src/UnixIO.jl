"""
# UnixIO.jl

Unix IO Interface.

For Julia programs that need to interact with Unix-specific IO interfaces.

e.g. Character devices, Terminals, Unix domain sockets, Block devices etc.

    using UnixIO
    using UnixIO: C

    UnixIO.read(`curl https://julialang.org`, String; timeout=5)

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io) do attr
        attr.speed=9600
        attr.c_lflag |= C.ICANON
    end
    readline(io; timeout=5)

    fd = C.open("file.txt", C.O_CREAT | C.O_WRONLY, 0o644)
    C.write(fd, pointer("Hello!"), 7)
    C.close(fd)

    io = UnixIO.open("file.txt", C.O_CREAT | C.O_WRONLY)
    write(io, "Hello!")
    close(io)

Blocking IO is multiplexed by running
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html)
under a task started by `Threads.@spawn`.
See [`src/poll.jl`](src/poll.jl)

If `ENV["JULIA_IO_EVENT_SOURCE"]` is set to `epoll` the
Linux [`epoll(7)`](https://man7.org/linux/man-pages/man7/epoll.7.html)
API is used instead.

If `ENV["JULIA_IO_EVENT_SOURCE"]` is set to `sleep` IO polling
is done by a dumb loop with a 10ms delay. This may be more efficient
for small systems with simple IO requirements.
(e.g. communicating with a few serial ports and sub-processes on a
Raspberry Pi).
"""
module UnixIO

export DuplexIO,
       @sh_str



# External Dependencies.

using Base: ImmutableDict,
            assert_havelock,
            @lock,
            C_NULL

#using Preferences
using ReadmeDocs               # for README""" ... """ doc strings.
using Preconditions            # for @require and @ensure contracts
using AsyncLog                 # for @asynclog -- log errors in async tasks.
#import TypeTree                # for pretty-printed type trees in doc strings.
#const typetree = TypeTree.tt



# Local Modules.

using DuplexIOs
using IOTraits
using UnixIOHeaders
const C = UnixIOHeaders

include("macroutils.jl")
include("ccall.jl")
include("errors.jl")
include("debug.jl")
include("stat.jl")


@db function __init__()

    @ccall(jl_generating_output()::Cint) == 1 && return

    debug_init()
    @db 1 "UnixIO.DEBUG_LEVEL = $DEBUG_LEVEL. See `src/debug.jl`."
    @db 1 "                     0: All `@db` messages off (replaced by `:()`)."
    @db 1 "                     1: high level API calls."
    @db 1 "                     2: Log event registration and polling."
    @db 1 "                     3: Log extra internal functions."
    @db 1 "                     4: Log event polling detail."
    @db 1 "                     5: Log local variable state."
    @db 1 "                     6: Extra verbose."

    poll_queue_init()
    atexit(kill_all_processes)

    global stdin
    global stdout
    global stderr
    stdin = FD{In}(RawFD(Base.STDIN_NO))
    stdout = FD{Out}(RawFD(Base.STDOUT_NO))
    stderr = FD{Out}(RawFD(Base.STDERR_NO))
end



# Deadlines / Timeouts.

macro with_timeout(fd, timeout, ex)
    quote
        fd = $(esc(fd))
        timeout = $(esc(timeout))
        old_deadline = fd.deadline
        new_deadline = timeout + time()
        if new_deadline < old_deadline
            fd.deadline = new_deadline
            if fd.deadline != Inf
                @db 1 "Set fd.deadline: $(db_t(fd.deadline)) ($timeout)"
            end
        end
        try
            $(esc(ex))
        finally
            fd.deadline = old_deadline
            if fd.deadline != Inf && fd.deadline != old_deadline
                @db 1 "Reset fd.deadline: $(db_t(fd.deadline))"
            end
        end
    end
end


# Unix File Descriptor wrapper.

abstract type FDType end

abstract type IODirection end
struct In <: IODirection end
struct Out <: IODirection end

mutable struct FD{D<:IODirection,T<:FDType} <: IO
    fd::RawFD
    isclosed::Bool
    nwaiting::Int
    ready::Base.GenericCondition{Base.ReentrantLock}
    closed::Base.GenericCondition{Base.ReentrantLock}
    timeout::Float64
    deadline::Float64
    gothup::Bool
    buffer::IOBuffer
    extra::ImmutableDict{Symbol,Any}

    FD{D}(fd) where D = FD{D,Union{}}(fd)

    function FD{D,T}(fd) where {D,T}
        fcntl_setfl(fd, C.O_NONBLOCK)
        fcntl_setfd(fd, C.O_CLOEXEC)
        _T = (T != Union{}) ? T : fdtype(fd)
        new{D,_T}(RawFD(fd),
                  false,
                  0,
                  Base.GenericCondition{Base.ReentrantLock}(),
                  Base.GenericCondition{Base.ReentrantLock}(),
                  Inf,
                  Inf,
                  false,
                  PipeBuffer(),
                  ImmutableDict{Symbol,Any}())
    end
end

const AnyFD = Union{FD, RawFD, Cint}

set_extra(fd::FD, key::Symbol, value) =
    fd.extra = ImmutableDict(fd.extra, key => value)

function get_extra(fd::FD, key::Symbol, default)
    x = get(fd.extra, key, nothing)
    if x == nothing
        x = default()
        set_extra(fd, key, x)
    end
    return x
end



abstract type File     <: FDType end
abstract type Stream   <: FDType end
abstract type MetaFile <: FDType end

abstract type S_IFBLK  <: File end
abstract type S_IFREG  <: File end
abstract type S_IFIFO  <: Stream end
abstract type S_IFCHR  <: Stream end
abstract type S_IFSOCK <: Stream end
abstract type S_IFLNK  <: MetaFile end
abstract type S_IFDIR  <: MetaFile end

struct PidFD           <: FDType end
struct Pseudoterminal  <: S_IFCHR end
struct CanonicalMode   <: S_IFCHR end

Base.wait(fd::FD) = wait(fd, WaitingMechanism(fd))
Base.wait(fd::FD, ::WaitUsingEPoll) = wait_for_event(epoll_queue, fd)
Base.wait(fd::FD, ::WaitUsingPosixPoll) = wait_for_event(poll_queue, fd)


mutable struct Process
    pid::C.pid_t
    in::FD
    out::FD
    stopped::Bool
    code::Union{Nothing, Cint}
    exit_status::Union{Nothing, Cint}
    signal::Union{Nothing, Cint}
end

isstopped(p::Process) = p.stopped
isrunning(p::Process) = isalive(p) && !isstopped(p)
isalive(p::Process) = p.exit_status == nothing &&
                      (p.signal == nothing || p.stopped)
didexit(p::Process) = p.exit_status != nothing
waskilled(p::Process) = !isstopped(p) && p.signal != nothing

IOTraits.WaitingMechanism(::Type{Process}) = firstvalid(WaitUsingPidFD(),
                                                        WaitBySleeping())

@db function Base.wait(p::Process; timeout=Inf,
                                   deadline=timeout+time())
    if !isrunning(p)
        @db return p "Already stopped or terminated"
    end
    wait(p, WaitingMechanism(p); deadline)
    @ensure time() >= deadline || !isrunning(p)
    return p
end

check(p::Process) = wait(p; deadline=0.0)

Base.wait(p::Process, ::WaitBySleeping; kw...) = waitpid(p; kw...)
Base.wait(p::Process, ::WaitUsingPidFD; kw...)= waitpidfd(p; kw...)




function fdtype(fd)

    s = stat(fd)
    t = isfile(s)     ? S_IFREG  :
        isblockdev(s) ? S_IFBLK  :
        ischardev(s)  ? S_IFCHR  :
        isdir(s)      ? S_IFDIR  :
        isfifo(s)     ? S_IFIFO  :
        islink(s)     ? S_IFLNK  :
        issocket(s)   ? S_IFSOCK :
                        Nothing

    if t == S_IFCHR && ispt(fd)
        t = Pseudoterminal
    elseif t == S_IFCHR
        attr=Ref(C.termios_m())
        if @cerr(allow=(C.EINVAL, C.ENOTTY, C.ENODEV),
                 C.tcgetattr_m(fd, attr)) != -1 &&
            (attr[].c_lflag & C.ICANON) != 0
            t = CanonicalMode
        end
    end
    return t
end

stattype(fd) = (s = stat(fd); isfile(s)     ? S_IFREG  :
                              isblockdev(s) ? S_IFBLK  :
                              ischardev(s)  ? S_IFCHR  :
                              isdir(s)      ? S_IFDIR  :
                              isfifo(s)     ? S_IFIFO  :
                              islink(s)     ? S_IFLNK  :
                              issocket(s)   ? S_IFSOCK :
                                              Nothing)

IOTraits.WaitingMechanism(::Type{<:FD{<:Any,<:Union{Stream, PidFD}}}) =
    IOTraits.preferred_poll_mechanism


    # FIXME unify with open() ?
@db 3 function FD(fd, flags = fcntl_getfl(fd); events=nothing)
    @nospecialize

    r = flags & C.O_RDWR   != 0 ?  DuplexIO(FD{In}(fd), FD{Out}(C.dup(fd))) :
        flags & C.O_WRONLY != 0 ?  FD{Out}(fd) :
                                   FD{In}(fd)
    @db 3 return r
end

debug_tiny(x::FD) = string(x)

Base.stat(fd::FD) = stat(fd.fd)
Base.lock(fd::FD) = lock(fd.ready)
Base.unlock(fd::FD) = unlock(fd.ready)
Base.notify(fd::FD, a...) = notify(fd.ready, a...)
Base.islocked(fd::FD) = islocked(fd.ready)
Base.assert_havelock(fd::FD) = Base.assert_havelock(fd.ready)

Base.convert(::Type{Cint}, fd::FD) = Base.cconvert(Cint, fd.fd)
Base.convert(::Type{Cuint}, fd::FD) = Cuint(convert(Cint, fd))
Base.convert(::Type{RawFD}, fd::FD) = RawFD(fd.fd)

include("ReadFD.jl")
include("WriteFD.jl")

IOTraits.ReadFragmentation(::Type{FD{In,CanonicalMode}}) = ReadsLines()

IOTraits.TransferSizeMechanism(::Type{<:FD{In,<:Stream}}) = SupportsFIONREAD()
IOTraits.TotalSize(::Type{<:FD{In,<:File}}) = VariableTotalSize()
IOTraits.TransferSizeMechanism(::Type{<:FD{In,<:File}}) = SuppoutsStatSize()

DuplexIOs.DuplexIO(i::FD{In}, o::FD{Out}) = @invoke DuplexIO(i::IO, o::IO)
DuplexIOs.DuplexIO(o::FD{Out}, i::FD{In}) = @invoke DuplexIO(i::IO, o::IO)



README"## Opening and Closing Unix Files."


@doc README"""
### `UnixIO.open` -- Open Files.

    UnixIO.open([FDType], pathname, [flags = C.O_RDWR],
                                    [mode = 0o644]];
                                    [timeout=Inf],
                                    [tcattr=nothing]) -> UnixIO.FD{FDType}

Open the file specified by pathname.

Use `Base.close` to close the file.

The `IO` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)

`open` returns `Unix.FD{FDType}`, where `FDType` is one of:

```
(join(typetree(FDType; mod=UnixIO)))
```

If the `FDType` argument is provided then `open` guarantees to return
`UnixIO{FDType}` (or throw an `ArgumentError` if `FDType` is not applicable
to `pathname`.

_Note: `C.O_NONBLOCK` is always added to `flags` to ensure compatibility with
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html).
A `RawFD` can be opened in blocking mode by calling `C.open` directly._
"""
@db 1 function open(type::Type{T},
                    pathname, flags=nothing, mode=0o644;
                    timeout=Inf, tcattr=nothing) where T

    if flags == nothing # See Open Type test set.
        flags = C.O_RDWR
    end

    flags |= C.O_NONBLOCK

    if flags & C.O_RDWR == C.O_RDWR
        flags &= ~C.O_RDWR
        fout = FD{Out,T}(open_raw(pathname, flags | C.O_WRONLY, mode; tcattr))
        fin = FD{In,T}(open_raw(pathname, flags; tcattr))
        io = DuplexIO(fin, fout)
    else
        D = (flags & C.O_WRONLY) != 0 ? Out : In
        io = FD{D,T}(open_raw(pathname, flags, mode; tcattr))
    end

    if timeout != nothing
        set_timeout(io, timeout)
    end

    @ensure isopen(io)
    @db 1 return io
end

open(args...; kw...) = open(Union{}, args...; kw...)


function open_raw(a...; tcattr=nothing)
    fd = @cerr gc_safe_open(a...)
    if tcattr != nothing
        tcsetattr(tcattr, fd)
    end
    return fd
end

gc_safe_open(a...) = @gc_safe C.open(a...)


@doc README"""
### `UnixIO.set_timeout` -- Configure Timeouts.

    UnixIO.set_timeout(fd::UnixIO.FD, timeout)

Configure `fd` to limit IO operations to `timeout` seconds.
"""
set_timeout(fd::FD, t) = fd.timeout = t
DuplexIOs.@wrap set_timeout


"""
Get the file status flags.
Uses `F_GETFL` to read the current flags.
See [fcntl(2)](https://man7.org/linux/man-pages/man2/fcntl.2.html).
"""
fcntl_getfl(fd; get=C.F_GETFL) = @cerr C.fcntl(fd, get)


"""
Set `flag` in the file status flags.
Uses `F_GETFL` to read the current flags and `F_SETFL` to store the new flag.
See [fcntl(2)](https://man7.org/linux/man-pages/man2/fcntl.2.html).
"""
@db 3 function fcntl_setfl(fd, flag; get=C.F_GETFL, set=C.F_SETFL)
    flags = fcntl_getfl(fd; get=get)               ;@db 3 "$(db_c(flag, "O_"))"
    if flags & flag == flag
        return nothing
    end
    flags |= flag
    @cerr C.fcntl(fd, set, flags)
end

fcntl_setfd(fd, flag) = fcntl_setfl(fd, flag; get=C.F_GETFD, set=C.F_SETFD)


@doc README"""
    UnixIO.tcgetattr(tty) -> C.termios_m

Get terminal device options.
See [tcgetattr(3)](https://man7.org/linux/man-pages/man3/tcgetattr.3.html).
"""
@db 2 function tcgetattr(tty, attr=termios(tty))
    aref = Ref(attr)
    @cerr C.tcgetattr_m(tty, aref)
    @db 2 return aref[]
end
tcgetattr(tty::FD{<:Any,<:S_IFCHR}) = tcgetattr(tty, termios(tty))


function termios(tty::FD{<:Any,<:S_IFCHR})
    get_extra(tty, :termios, ()->tcgetattr(tty, C.termios_m()))
end
termios(tty::Union{Cint,RawFD}) = tcgetattr(tty, C.termios_m())


@doc README"""
### `UnixIO.tcsetattr` -- Configure Terminals and Serial Ports.

    UnixIO.tcsetattr(tty, attr::C.termios_m)
    UnixIO.tcsetattr(tty) do attr
         [attr.c_iflag = ...]
         [attr.c_oflag = ...]
         [attr.c_cflag = ...]
         [attr.c_lflag = ...]
         [attr.speed = ...]
    end

Set terminal device options.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io) do attr
        setraw(attr)
        attr.speed=9600
        attr.c_lflag |= C.ICANON
    end

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

"""
function tcsetattr(f, tty::AnyFD)
    c = tcgetattr(tty)
    f(c)
    tcsetattr(tty, c)
end
tcsetattr(tty, attr::C.termios_m) =
    @cerr C.tcsetattr_m(tty, C.TCSANOW, Ref(attr))

DuplexIOs.@wrap tcsetattr
tcsetattr(f, tty::DuplexIO) = (tcsetattr(f, tty.in); tcsetattr(f, tty.out))

"""
Disabling all terminal input and output processing.
"""
@selfdoc function setraw(x::C.termios_m)
    x.c_iflag = 0
    x.c_oflag = 0
    x.c_cflag = C.CS8
    x.c_lflag = 0
end


function setspeed!(attr::C.termios_m, speed)
    flag = eval(:(C.$(Symbol("B$speed"))))
    @cerr C.cfsetspeed_m(Ref(attr), flag)
    nothing
end

Base.setproperty!(c::C.termios_m, f::Symbol, x) =
    f === :speed ? (setspeed!(c, x); x) :
                    @invoke setproperty!(c::Any, f::Symbol, x)


iscanon(tty) = (termios(tty).c_lflag & C.ICANON) != 0
setcanon(tty) = tcsetattr(c -> c.c_lflag &= C.ICANON, tty)


@doc README"""
### `UnixIO.flush` -- Discard untransmitted data.

    tcflush(tty, flags)

See [tcflush(3p)](https://man7.org/linux/man-pages/man3/tcflush.3p.html)
"""
tcflush(tty, flags) = @cerr C.tcflush(tty, flags)

DuplexIOs.@wrap tcflush

tcdrain(tty) = @cerr C.tcdrain(tty)

DuplexIOs.@wrap tcdrain


@doc README"""
### `UnixIO.tiocgwinsz` -- Get Terminal size.

    tiocgwinsz(tty) -> C.winsize

See [tty_ioctl(4)](https://man7.org/linux/man-pages/man4/tty_ioctl.4.html)
"""
tiocgwinsz(tty) = (x=[C.winsize()]; @cerr C.ioctl(tty, C.TIOCGWINSZ, x); x[1])

tiocgwinsz(tty::DuplexIO) = tiocgwinsz(tty.out)


@db 1 function Base.close(fd::FD)
    fd.isclosed = true
    @dblock fd notify(fd)
    yield()
    shutdown(fd)
    @cerr allow=C.EBADF C.close(fd)
    @dblock fd.closed notify(fd.closed)
    @ensure !isopen(fd)
    nothing
end

@db function Base.wait(fd::FD{In,Pseudoterminal})
    assert_havelock(fd)

    process = fd.extra[:pt_client]

    while true
        timer = register_timer(time() + 1) do
            @dblock fd notify(fd, :poll_isalive) # FIXME SIGCHILD?
        end
        try
            event = @invoke wait(fd::FD{In})
            if event != :poll_isalive
                return event
            end
            #FIXME no need to poll for PidFD?
            if !isalive(check(process))
                return nothing
            end                                              ;@db event process
        finally
            close(timer)
        end
    end
end


@db 1 function Base.close(fd::FD{In,Pseudoterminal})
    C.close(fd.extra[:pt_clientfd])
    @invoke Base.close(fd::FD{In})
end

@db 1 function Base.close(fd::FD{Out,Pseudoterminal})
    if !fd.isclosed                                           ;@db 1 "-> ^D 🛑"
        fd.gothup = true
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


Base.isopen(fd::FD) = !fd.isclosed


@db 1 function Base.wait_close(fd::FD; timeout=fd.timeout,
                                       deadline=timeout+time())
    wait_until(fd.closed, ()->!isopen(fd), deadline)
end


@doc README"""
### `UnixIO.shutdown` -- Signal end of transmission or reception.

    UnixIO.shutdown(sockfd, how)

Shut down part of a full-duplex connection.
`how` is one of `C.SHUT_RD`, `C.SHUT_WR` or `C.SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
@db 1 function shutdown(fd, how);                  @db 1 "$(db_c(how, "SHUT"))"
    @cerr(allow=(C.ENOTCONN, C.EBADF, C.ENOTSOCK),
          C.shutdown(fd, how))
end



README"## Reading from Unix Files."


@doc README"""
### `UnixIO.read` -- Read bytes into a buffer.

    UnixIO.read(fd, buf, [count=length(buf)];
                [timeout=Inf] ) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
"""
@db 2 function read(fd::FD{In}, buf::Ptr{UInt8}, count::Csize_t;
                    timeout=fd.timeout)

    # First read from buffer.
    n = bytesavailable(fd.buffer)
    if n > 0                                          ;@db 2 "read from buffer"
        n = min(n, count)
        unsafe_read(fd.buffer, buf, n)
    end

    # Then read from file.
    if count > n
        n += @with_timeout(fd, timeout, transfer(fd, buf+n, count-n))
    end
    @ensure n <= count
    @db 2 return n
end

@db 2 function read(fd::FD, v::AbstractVector{UInt8},
                    index=1, count=length(v)-(index-1); kw...)
    checkbounds(v, index + count - 1)
    buf = pointer(v, index)
    @db 2 return GC.@preserve v read(fd, buf, Csize_t(count); kw...)
end


"""
Read or write (FD{In} or FD{Out}) up to `count` bytes to or from `buf`
until `fd.deadline`.
Always attempt at least one call to `read(2)/write(2)`
even if `fd.deadline` has passed.
Return number of bytes transferred or `0` on timeout.
"""
@db 2 function transfer(fd::FD, buf::Ptr{UInt8}, count::Csize_t)
    @require !fd.isclosed
    @require count > 0

    n = nointr_transfer(fd, buf, count)
    if n >= 0
        @db 2 return n
    end

    @dblock fd while time() < fd.deadline
        wait(fd)
        n = nointr_transfer(fd, buf, count);                           ;@db 2 n
        if n >= 0
            @ensure n <= count
            @db 2 return n
        end                                                    ;@db 2 "wait..."
    end

    @db 2 return 0 "timeout!"
end

@db 2 function transfer(fd::FD, v::AbstractVector{UInt8},
                        index=1, count=length(v)-(index-1))
    checkbounds(v, index + count - 1)
    buf = pointer(v, index)
    @db 2 return GC.@preserve v transfer(fd, buf, Csize_t(count))
end


"""
Read or write (FD{In} or FD{Out}) up to `count` bytes to or from `buf`.
Retry on `C.EINTR`.
Return number of bytes transferred or `-1` on `C.EAGAIN`.
"""
@db 2 function nointr_transfer(fd::FD, buf::Ptr{UInt8}, count::Csize_t)
    @require count > 0
    while true
        n = @cerr(allow=(C.EAGAIN, C.EINTR), raw_transfer(fd, buf, count))
        n != -1 || @db 2 n errno() errname(errno())
        if n != -1 || errno() == C.EAGAIN
            @ensure n <= count
            @db 2 return n
        end
    end
end


include("timer.jl")
include("poll.jl")



README"## Writing to Unix Files."


@doc README"""
### `UnixIO.write` -- Write bytes from a buffer.

    UnixIO.write(fd, buf, [count=length(buf)];
                 [timeout=Inf] ) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)
"""
#=
@db 1 function write(fd::WriteFD, buf, count=length(buf); timeout=fd.timeout)
    n = @with_timeout(fd, timeout, transfer(fd, buf, 1, count))
    @db 1 return n
end
=#


@doc README"""
### `UnixIO.println` -- Write messages to the terminal.

    UnixIO.println(x...)
    UnixIO.printerr(x...)

Write directly to `STDOUT` or `STDERR`.
Does not yield control from the current task.
"""
println(x...) = raw_println(Base.STDOUT_NO, x...)
printerr(x...) = raw_println(Base.STDERR_NO, x...)
function raw_println(fd, x...)
    io = IOBuffer()
    Base.println(io, x...)
    buf = take!(io)
    GC.@preserve buf debug_write(fd, pointer(buf), length(buf))
    nothing
end



README"## Unix Domain Sockets."


@doc README"""
### `UnixIO.socketpair()` -- Unix Domain Sockets for IPC.

    UnixIO.socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)
"""
@db function socketpair()
    v = fill(RawFD(-1), 2)
    @cerr C.socketpair(C.AF_UNIX, C.SOCK_STREAM, 0, v)
    @ensure -1 ∉ v
    @db return (v[1], v[2])
end



@doc README"""
### `UnixI in debug.openpt()` -- Open a pseudoterminal device.

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

    fd = FD(pt)
    tcsetattr(fd.in) do attr
        setraw(attr)
        attr.c_lflag |= C.ICANON
    end
    set_extra(fd.in, :pt_clientfd, clientfd)

    @db return fd, path
end


function ptsname(fd)
    buf = Vector{UInt8}(undef, 100)
    p = pointer(buf)
    GC.@preserve @cerr C.ptsname_r(fd, p, length(buf))
    unsafe_string(p)
end


ispt(fd) = C.ptsname(fd) != C_NULL



README"## Executing Unix Commands."

@doc README"""
### `sh"cmd"` -- Shell command string.

    sh"shell command"

String containing result of shell command. e.g.

    julia> println("Machine is ", sh"uname -m")
    Machine is x86_64

    julia> println("V: ", sh"grep version Project.toml | awk '{print\$3}'")
    V: "0.1.0"
"""
macro sh_str(s)
    s = Meta.parse("\"$s\"")
    cmd = `bash -c "$s"`
    esc(:($cmd |> read |> String |> chomp))
end

@doc README"""
### `UnixIO.system` -- Run a shell command.

    UnixIO.system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)

e.g.
```
julia> UnixIO.system("uname -srm")
Darwin 20.3.0 x86_64
```
"""
@db function system(command)
    r = @cerr gc_safe_system(command)
    if r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end
    @db return r
end

system(cmd::Cmd) = system(join(cmd.exec, " "))

gc_safe_system(c) = @gc_safe C.system(c)



@doc README"""
### `UnixIO.open(::Cmd) do...` -- Communicate with a sub-process.

    UnixIO.open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `posix_spawn`.

Call `f(cmdin, cmdout)`
with (STDIN, STDOUT) of `cmd` connected to (`cmdin`, `cmdout`).

If `capture_stderr` is `true` STDERR of `cmd` is merged into `cmdout`.

If `check_status` is `true` an exception is thrown on non-zero exit status.

e.g.
```
julia> UnixIO.open(`hexdump -C`) do cmdin, cmdout
           write(cmdin, "Hello World!")
           close(cmdin)
           read(cmdout, String)
       end |> println
00000000  48 65 6c 6c 6f 20 57 6f  72 6c 64 21              |Hello World!|
0000000c
```
"""
@db function open(f, cmd::Cmd; capture_stderr=false, env=nothing, kw...)
    process = socketpair_spawn(cmd; env, capture_stderr)
    run_cmd_function(f, cmd, process; kw...)
end


@doc README"""
### `UnixIO.ptopen(::Cmd) do...` -- Run a sub-process in a pseudoterminal.

    UnixIO.ptopen(f, cmd::Cmd; [env=ENV, check_status=true])

Run `cmd` using `posix_spawn`.

Call `f(cmdin, cmdout)` with (STDIN, STDOUT and STDERR) of `cmd`
connected to (`cmdin`, `cmdout`) via a pseudoterminal.

If `check_status` is `true` an exception is thrown on non-zero exit status.

Run `cmd` using `posix_spawn`.
"""
@db function ptopen(f, cmd::Cmd; env=nothing, kw...)
    process = pseudoterminal_spawn(cmd; env)
    run_cmd_function(f, cmd, process; kw...)
end


@db function run_cmd_function(f, cmd, p; check_status=true)
    @nospecialize

    # Run the IO handling function `f`.
    try                                         ;@db 1 "f ┬─($(p.in),$(p.out))"
                                                ;@db_indent 1 "f"
        result = f(p.in, p.out)                 ;@db_unindent 1
        close(p.in)                             ;@db 1 "  └─▶ 👍"
        close(p.out)

        # If cmd is still running try to kill it softly.
        if isalive(check(p))
            C.kill(p, C.SIGHUP)                           ;@db 3 "SIGHUP -> $p"
            wait(p; timeout=5.0)
            sent_sighup = true
        else
            sent_sighup = false
        end

        if !check_status
            @db return p, result
        elseif (didexit(check(p)) && p.exit_status == 0) || sent_sighup
            @db return result
        else
            throw(ProcessFailedException(p, cmd))
        end
    finally
        kill(p)
    end
end


function open(cmd::Cmd; kw...)
    c = Channel{Tuple{FD{Out},FD{In}}}(0)
    @asynclog "UnixIO.open(::Cmd)" open(cmd; kw...) do cmdin, cmdout
        put!(c, (cmdin, cmdout))
        @sync begin
            @async Base.wait_close(cmdin)
            @async Base.wait_close(cmdout)
        end
    end
    take!(c)
end


@doc README"""
### `UnixIO.read(::Cmd)` -- Read sub-process output.

    read(cmd::Cmd; [timeout=Inf,
                    check_status=true,
                    capture_stderr=false]) -> Vector{UInt8}
    read(cmd::Cmd, String; kw...) -> String

Run `cmd` using `fork` and `execv`.

Return byes written to stdout by `cmd`.

e.g.
```
julia> UnixIO.read(`uname -srm`, String)
"Darwin 20.3.0 x86_64\n"
```
"""
@db function read(cmd::Cmd, ::Type{String}; kw...)
    r = String(read(cmd; kw...))
    @db return r
end

@db function read(cmd::Cmd; timeout=Inf, kw...)
    r = open(cmd; kw...) do cmdin, cmdout
        shutdown(cmdin)
        Base.read(cmdout; timeout)
    end
    @db return r
end



# Sub Processes.

function Process(pid, infd, outfd)
    p = Process(pid, infd, outfd, false, nothing, nothing, nothing)
    @dblock processes_lock push!(processes, p)
    return p
end

Base.convert(::Type{C.pid_t}, p::Process) = p.pid


const processes_lock = Threads.SpinLock()
const processes = Set{Process}()


@doc README"""
### `UnixIO.waitpid` -- Wait for a sub-process to terminate.

    UnixIO.waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)
"""
@db function waitpid(p::Process; deadline::Float64=Inf)

    status = Ref{Cint}(0)
    delay = nothing

    while true
        r = C.waitpid(p.pid, status, C.WNOHANG | C.WUNTRACED)          ;@db 3 r
        if r == -1
            err = errno()
            if err == C.EINTR                                    ;@db 3 "EINTR"
                continue
            elseif err == C.ECHILD
                @db return nothing "ECHILD (No child process)"
            end
            systemerror(string("C.waitpid($(p.pid))"), err)
        end
        if r == p.pid
            s = status[]
            if C.WIFEXITED(s)
                p.exit_status = C.WEXITSTATUS(s)
            elseif C.WIFSTOPPED(s)
                p.stopped = true
                p.signal = WSTOPSIG(s)
            elseif C.WIFCONTINUED(s)
                p.stopped = false
                p.signal = nothing
                @assert p.exit_status == nothing
            elseif C.WIFSIGNALED(s)
                p.signal = C.WTERMSIG(s)
            else
                @error "Unhandedl termination status: $s" p
            end
            if !p.stopped
                @dblock processes_lock delete!(processes, p)
            end
            @db return nothing "terminated"
        end
        if time() >= deadline
            @db return nothing "timeout!"
        end

        if delay == nothing
            delay = exponential_delay()
        end
        t = popfirst!(delay)                                 ;@db 3 "sleep($t)"
        sleep(t)
    end
end

exponential_delay() =
    Iterators.Stateful(ExponentialBackOff(n=typemax(Int); factor=2))


code(i::C.siginfo_t) = i.si_code
pid(i::C.siginfo_t) = i._sifields._pad[1]
status(i::C.siginfo_t) = i._sifields._pad[3]


#=
`waitid(pidfd, ...)` only works if the `pidfd` is opened before the
process terminates.
The `waitpidfd` method below calls the normal `waitpid` function
after polling the `pidfd`.

"""
    waitid(::ReadFD{PidFD}) -> C.siginfo_t

See [waitid(2)](https://man7.org/linux/man-pages/man2/waitid.2.html)
"""
@db function waitid(fd::ReadFD{<:PidFD})
    si = Ref(C.siginfo_t())
    @assert pid(si[]) == 0
    @cerr0 C.waitid(C.P_PIDFD, fd, si, C.WEXITED | C.WNOHANG | C.WUNTRACED)
    @db return pid(si[]) == 0 ? nothing : si[]
end


@db function waitid(fd::ReadFD{<:PidFD}, p::Process)
    si = waitid(fd)
    if si == nothing
        return
    end
    @assert pid(si) == p.pid
    if code(si) == C.CLD_CONTINUED
        p.signal = nothing
        @assert p.exit_status == nothing
    else
        if code(si) == C.CLD_STOPPED
            p.stopped = true
            p.signal = status(si)
        elseif code(si) == C.CLD_CONTINUED
            p.stopped = false
            p.signal = nothing
        elseif code(si) == C.CLD_EXITED
            p.exit_status = status(si)
        else
            p.signal = status(si)
        end
    end
    if !p.stopped
        @dblock processes_lock delete!(processes, p)
    end
    nothing
end
=#


@db function waitpidfd(p::Process; deadline::Float64=Inf)

    waitpid(p; deadline=0.0)

    while deadline >= time() && isrunning(p)
        r = @cerr allow=C.ESRCH C.pifd_open(p.pid, 0)
        if r != -1
            fd = FD{In,PidFD}(r)
            fd.deadline = deadline
            try
                @dblock fd wait(fd)
            finally
                close(fd)
            end
        end
        waitpid(p; deadline=0.0)
    end

    nothing
end


@db function kill(p::Process)
    if isalive(check(p))
        C.close(p.in)
        C.close(p.out)
        C.kill(p, C.SIGKILL)                             ;@db 3 "SIGKILL -> $p"
        @asynclog "UnixIO.kill(::Process) -> waitpid()" wait(p)
    else
        @db "Already terminated!"
    end
end


@db 1 function kill_all_processes()
    @sync for p in processes                             ;@db 1 "SIGKILL -> $p"
        C.kill(p, C.SIGKILL)
        @async wait(p)
    end
end

struct ProcessFailedException <: Exception
    p::Process
    cmd::Cmd
end


function find_cmd_bin(cmd::Cmd)
    bin = Base.Sys.which(cmd.exec[1])
    bin != nothing || throw(ArgumentError("Command not found: $(cmd.exec[1])"))
    bin
end


@db 3 function pseudoterminal_spawn(cmd; kw...)

    # Create a Pseudoterminal to communicate with Child Process STDIN/OUT.
    parent_io, devpath = openpt()
    cmdin = parent_io.out
    cmdout = parent_io.in

    pid = spawn_process(cmd, devpath; kw...)

    process = Process(pid, cmdin, cmdout)
    set_extra(cmdout, :pt_client, process)
    return process
end


@db 3 function socketpair_spawn(cmd; capture_stderr=false, kw...)

    # Create a Unix Domain Socket to communicate with Child Process STDIN/OUT.
    parent_io, child_io = socketpair()
    cmdin = FD{Out}(parent_io)
    cmdout = FD{In}(C.dup(parent_io))
    @db 3 "dup($parent_io) -> $(cmdout.fd)"

    # Merge STDERR into STDOUT?
    # or leave connected to Parent Process STDERR?
    child_err = capture_stderr ? child_io : RawFD(Base.STDERR_NO)

    pid = spawn_process(cmd, child_io, child_io, child_err; kw...)

    # Close the child end of the socketpair.
    C.close(child_io)

    return Process(pid, cmdin, cmdout)
end


@db 3 function spawn_process(cmd, infd, outfd=infd, errfd=outfd; kw...)
    if true #Sys.isapple
        posix_spawn(cmd, infd, outfd, errfd; kw...)
    else
        fork_and_exec(cmd, infd, outfd, errfd; kw...)
    end
end


"""
    posix_spawn(cmd, in, out, err; [env=ENV]) -> pid

Run `cmd` using `posix_spawn`.
Connect child process (STDIN, STDOUT, STDERR) to (`in`, `out`, `err`).
See [posix_spawn(3)](https://man7.org/linux/man-pages/man3/posix_spawn.3.html).
"""
@db function posix_spawn(cmd::Cmd, infd::Union{String,RawFD},
                                   outfd::Union{String,RawFD,Nothing}=nothing,
                                   errfd::Union{String,RawFD,Nothing}=nothing;
                                   env=nothing)
    @nospecialize

    # Find path to binary.
    cmd_bin = find_cmd_bin(cmd)

    # Prepare NULL-terminated vector of Argument Pointers.
    argv = [pointer.(cmd.exec); Ptr{UInt8}(0)]

    # Prepare NULL-terminated vector of Environment Variables.
    if env != nothing
        env_vector = ["$k=$v" for (k, v) in env]
    else
        env_vector = String[]
        i = 0
        while (s = @ccall jl_environ(i::Int32)::Any) != nothing
            push!(env_vector, s)
            i += 1
        end
    end
    envp = [pointer.(env_vector); Ptr{UInt8}(0)]

    # Allocate Attribute and File Action structs (destoryed in `finally`).
    pid = Ref{C.pid_t}()
    attr = Ref{C.posix_spawnattr_t}()
    actions = Ref{C.posix_spawn_file_actions_t}()
    @cerr0 C.posix_spawnattr_init(attr)
    @cerr0 C.posix_spawn_file_actions_init(actions)
    try
        # Set flags.
        @cerr0 C.posix_spawnattr_setflags(attr, C.POSIX_SPAWN_SETSIGDEF |
                                                C.POSIX_SPAWN_SETSIGMASK |
                                                C.POSIX_SPAWN_SETSID )

        # Set all signals to default behaviour.
        sigset = Ref{C.sigset_t}()
        @cerr0 C.sigfillset(sigset)
        @cerr0 C.sigdelset(sigset, C.SIGKILL)
        @cerr0 C.sigdelset(sigset, C.SIGSTOP)
        @cerr0 C.posix_spawnattr_setsigdefault(attr, sigset)

        # Un-mask all signals.
        emptyset = Ref{C.sigset_t}()
        @cerr0 C.sigemptyset(emptyset)
        @cerr0 C.posix_spawnattr_setsigmask(attr, emptyset)

        # Connect Child Process STDIN/OUT to socket.
        previous_stdno=-1
        for (fd, stdno) in ( infd => Base.STDIN_NO,
                            outfd => Base.STDOUT_NO,
                            errfd => Base.STDERR_NO)
            if fd isa String
                @db 4 "addopen($stdno, $fd)"
                @cerr C.posix_spawn_file_actions_addopen(
                    actions, stdno, fd, C.O_RDWR, 0)
            else
                @db 4 "adddup2($stdno, $fd, $stdno)"
                @cerr0 C.posix_spawn_file_actions_adddup2(
                    actions, something(fd, previous_stdno), stdno)
                previous_stdno = stdno
            end
        end

        # Start the Child Process
        GC.@preserve cmd env_vector begin
            @cerr0 C.posix_spawn(pid, cmd_bin, actions, attr, argv, envp)
        end
        @assert pid[] > 0

        @db return pid[]

    finally
        @cerr0 C.posix_spawn_file_actions_destroy(actions)
        @cerr0 C.posix_spawnattr_destroy(attr)
    end
end


"""
    fork_and_exec(cmd, in, out, err) -> pid

Run `cmd` using `fork` and `execv`.
Connect child process (STDIN, STDOUT, STDERR) to (`in`, `out`, `err`).
"""
@db function fork_and_exec(cmd::Cmd, infd::RawFD, outfd::RawFD, errfd::RawFD;
                           env=nothing)
    @nospecialize

    GC.@preserve cmd begin

        # Find path to binary.
        cmd_bin = find_cmd_bin(cmd)

        # Prepare arguments for `C.execv`.
        args = [pointer.(cmd.exec); Ptr{UInt8}(0)]

        # Mask all signals.
        oldmask = Ref{C.sigset_t}()
        newmask = Ref{C.sigset_t}()
        C.sigfillset(newmask)
        C.pthread_sigmask(C.SIG_SETMASK, newmask, oldmask);

        # Start Child Process ─────────────────────╮
        #                                          ▼
        pid = C.fork();                  if pid == 0

                                             # Set Default Signal Handlers.
                                             for n in 1:31
                                                 C.signal(n, C.SIG_DFL)
                                             end

                                             # Clear Signal Mask.
                                             emptyset = Ref{C.sigset_t}()
                                             C.sigemptyset(emptyset)
                                             C.pthread_sigmask(C.SIG_SETMASK,
                                                               emptyset,
                                                               C_NULL);

                                             # Connect STDIN/OUT to socket.
                                             C.dup2(infd,  Base.STDIN_NO)
                                             C.dup2(outfd, Base.STDOUT_NO)
                                             C.dup2(errfd, Base.STDERR_NO)

                                             # Execute command.
                                             C.execv(cmd_bin, args)
                                             C._exit(-1)
                                         end

        # Restore old signal mask.
        C.pthread_sigmask(C.SIG_SETMASK, oldmask, C_NULL);

        @assert pid > 0

        @db return pid
    end
end



# Pretty Printing.


type_icon(::Type{In})              = "→"
type_icon(::Type{Out})             = "←"
type_icon(::Type{S_IFIFO})         = "📥"
type_icon(::Type{S_IFCHR})         = "📞"
type_icon(::Type{S_IFDIR})         = "📂"
type_icon(::Type{S_IFBLK})         = "🧊"
type_icon(::Type{S_IFREG})         = "📄"
type_icon(::Type{S_IFLNK})         = "🔗"
type_icon(::Type{S_IFSOCK})        = "🧦"
type_icon(::Type{PidFD})           = "⚙️ "
type_icon(::Type{Pseudoterminal})  = "⌨️ "
type_icon(::Type{CanonicalMode})   = "📺"


function Base.show(io::IO, fd::FD{D,T}) where {D,T}
    fdint = convert(Cint, fd)
    t = type_icon(T)
    d = type_icon(D)
    print(io, "FD{$d$t}($fdint")
    fd.isclosed && print(io, "🚫")
    fd.nwaiting > 0 && print(io, repeat("👀", fd.nwaiting))
    islocked(fd) && print(io, "🔒")
    fd.timeout == Inf || print(io, ", ⏱", fd.timeout)
    if D == In
        fd.gothup && print(io, "☠️ ")
        n = bytesavailable(fd.buffer)
        if n > 0
            print(io, ", $(n)📥")
        end
    end
    print(io, ")")
end


const signame = [string(unsafe_string(C.strsignal(n)),
                        " (", constant_name(n; prefix=r"^SIG[A-Z]+$",
                                              first=true), ")")
                 for n in 1:31]


function Base.show(io::IO, e::ProcessFailedException)
    p = e.p
    print(io,
          "ProcessFailedException: ", cmd, ", ", "pid ", p.pid,
          (waskilled(p) ? (" killed by ", signame[p.signal]) :
                          (" exit status ", p.exit_code))...)
end


dbtiny(fd::FD) = string(fd)


# Compiler hints.

include("precompile.jl")
_precompile_()



end # module UnixIO
