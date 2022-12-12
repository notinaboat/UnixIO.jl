"""
# UnixIO.jl

Unix IO Interface.

For Julia programs that need to interact with Unix-specific IO interfaces.

Features:

 - Serial port / terminal configuration.
 - Serial port flush/drain.
 - Use canonical (line-by-line) mode for terminal devices
   and serial ports.
 - Use poxsix_spawn (not fork/exec) to start sub-processes.
 - Run a sub-process in a pseudo terminal.
 - Communicate with a subprocess via stdin/stdout sockets with option to merge stderr.
 - Timeout option for all operations.
 - Use `epoll` and `poll` for asynchronous IO.
 - Optional fine grained debug tracing.
 - Read and write unix device files.
 - Wait for sub-process termination without signals `pid_fd`, `epoll`.
 - raw println
 - Unix Domain Sockets for IPC
 - Run shell commands through `system`
 - Better eof(), bytesavailable() etc for unix files
 - Access to raw syscalls, fcntls, ioctls etc for special needs.

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

using ReadmeDocs               # for README""" ... """ doc strings.
using MarkdownTableMaps        # for md_table_map
using Preconditions            # for @require and @ensure contracts
using AsyncLog                 # for @asynclog -- log errors in async tasks.
#import TypeTree                # for pretty-printed type trees in doc strings.
#const typetree = TypeTree.tt



# Local Modules.

using DuplexIOs
using IOTraits
using IOTraits: In, Out
using UnixIOHeaders
const C = UnixIOHeaders.C

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
    if Sys.islinux()
        epoll_queue_init()
        io_uring_queue_init()
    end

    atexit(kill_all_processes)

    global stdin
    global stdout
    global stderr
    stdin = FD{In}(RawFD(Base.STDIN_NO))
    stdout = FD{Out}(RawFD(Base.STDOUT_NO))
    stderr = FD{Out}(RawFD(Base.STDERR_NO))
end



# Unix File Descriptor wrapper.

abstract type FDType end

mutable struct FD{D<:TransferDirection,T<:FDType} <: IOTraits.Stream
    fd::RawFD
    isclosed::Bool
    nwaiting::Int
    #ready::Base.ThreadSynchronizer  FIXME seperate lock for io interleaving vs poll/wait ???
    #closed::Base.ThreadSynchronizer
    ready::Base.GenericCondition{Base.ReentrantLock}
    closed::Base.GenericCondition{Base.ReentrantLock}
    gothup::Bool
    extra::ImmutableDict{Symbol,Any}

    FD{D}(fd) where D = FD{D,Union{}}(fd)

    function FD{D,T}(fd) where {D,T}
        fcntl_setfl(fd, C.O_NONBLOCK)
        fcntl_setfd(fd, C.O_CLOEXEC)
        _T = (T != Union{}) ? T : fdtype(fd)
        new{D,_T}(RawFD(fd),
                  false,
                  0,
                  #Base.ThreadSynchronizer(),
                  #Base.ThreadSynchronizer(),
                  Base.GenericCondition{Base.ReentrantLock}(),
                  Base.GenericCondition{Base.ReentrantLock}(),
                  false,
                  ImmutableDict{Symbol,Any}())
    end
end

IOTraits.TransferDirection(::Type{<:FD{<:T}}) where T = T()

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

IOTraits._wait(fd::FD, ::WaitUsingEPoll; deadline=Inf) = wait_for_event(epoll_queue, fd; deadline)
IOTraits._wait(fd::FD, ::WaitUsingPosixPoll; deadline=Inf) = wait_for_event(poll_queue, fd; deadline)
IOTraits._wait(fd::FD, ::WaitUsingIOURing; deadline=Inf) = wait_for_event(io_uring_queue, fd; deadline)

@db function  IOTraits.isconnected(fd::FD)
    !fd.gothup
end

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

#IOTraits.WaitingMechanism(::Type{<:FD{<:Any,<:File}}) =
#    IOTraits.firstvalid(WaitUsingIOURing(),
#                        WaitBySleeping())


IOTraits.TransferMechanism(::Type{<:FD{<:Any,<:File}}) = 
    IOTraits.firstvalid(IOURingTransfer(),
                        AIOTransfer(),
                        LibCTransfer())


# FIXME unify with open() ?
@db 3 function FD(fd, flags = fcntl_getfl(fd); events=nothing)
    @nospecialize

    r = flags & C.O_RDWR   != 0 ?  (FD{In}(fd), FD{Out}(C.dup(fd))) :
        flags & C.O_WRONLY != 0 ?  FD{Out}(fd) :
                                   FD{In}(fd)
    @db 3 return r
end


include("process.jl")
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
#Mmap.gethandle(fd::FD) = RawFD(fd.fd)

include("ReadFD.jl")
include("WriteFD.jl")

IOTraits.ReadFragmentation(::Type{FD{In,CanonicalMode}}) = ReadsLines()


trait_doc = """

# IO Traits

| Type            | Read Fragmentation | Transfer Size         | Transfer Size Mechanism | Total Size          | Total Size Mechanism  | Cursor Support |
| --------------- | ------------------ | --------------------- | ----------------------- | ------------------- | --------------------- | -------------- |
| S_IFBLK         |                    |                       | Supports Stat Size      | Fixed Total Size    | Supports Stat Size    | Seekable       |
| S_IFREG         |                    |                       | Supports Stat Size      | Variable Total Size | Supports Stat Size    | Seekable       |
| S_IFIFO         |                    | Limited Transfer Size | Supports FIONREAD       |                     |                       |                | 
| S_IFCHR         |                    |                       | Supports FIONREAD       |                     |                       |                |
| S_IFSOCK        |                    | Limited Transfer Size | Supports FIONREAD       |                     |                       |                |
| S_IFLNK         |                    |                       |                         |                     |                       |                | 
| S_IFDIR         |                    |                       |                         |                     |                       |                | 
| PidFD           |                    |                       |                         |                     |                       |                | 
| Pseudoterminal  |                    |                       |                         |                     |                       |                | 
| CanonicalMode   | Reads Lines        |                       |                         |                     |                       |                | 
"""

#=
for (i, n) in enumerate(md_table_columns(trait_doc))
    i > 1 || continue
    f = Symbol(replace(n, " " => ""))
    for (k, v) in md_table_map(trait_doc, 1 => i)
        if v != ""
            v = Symbol(replace(v, " " => ""))
            ex = :(IOTraits.$f(::Type{<:FD{In,<:$(Symbol(k))}}) = $v())
            eval(ex)
        end
    end
end
=#



IOTraits.TransferSizeMechanism(::Type{<:FD{In,<:Stream}}) = SupportsFIONREAD()
IOTraits.TotalSize(::Type{<:FD{In,<:File}}) = VariableTotalSize()
IOTraits.TransferSizeMechanism(::Type{<:FD{In,<:File}}) = SupportsStatSize()
IOTraits.TotalSizeMechanism(::Type{<:FD{In,<:File}}) = SupportsStatSize()

IOTraits.CursorSupport(::Type{<:FD{In,<:File}}) = Seekable()

IOTraits.Availability(::Type{<:FD{In,<:File}}) = AlwaysAvailable()
IOTraits.Availability(::Type{<:FD{In,<:Stream}}) = PartiallyAvailable()
IOTraits.Availability(::Type{<:FD{In,Pseudoterminal}}) = UnknownAvailability()


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
        io = DuplexIO(IOTraits.BaseIO(IOTraits.LazyBufferedInput(fin)),
                      IOTraits.BaseIO(fout))
    else
        D = (flags & C.O_WRONLY) != 0 ? Out : In
        io = FD{D,T}(open_raw(pathname, flags, mode; tcattr))
        if D == In
            io = IOTraits.LazyBufferedInput(io)
        end
        io = IOTraits.BaseIO(io)
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


include("termio.jl")


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


Base.isopen(fd::FD) = !fd.isclosed


@db 1 function Base.wait_close(fd::FD; timeout=Inf,
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

shutdown(fd::FD{Out}) = shutdown(fd, C.SHUT_WR)
shutdown(fd::FD{In}) = shutdown(fd, C.SHUT_RD)


README"## Reading from Unix Files."




"""
Read or write (FD{In} or FD{Out}) up to `count` bytes to or from `buf`.
Retry on `C.EINTR`.
Return number of bytes transferred or `0` on timeout or `C.EAGAIN`.
"""
@inline @db 2 function IOTraits.unsafe_transfer!(fd::FD,
                                                 buf::Ptr{UInt8},
                                                 count::UInt)
    @require !fd.isclosed
    @require count > 0
    while true
        n = @cerr(allow=(C.EAGAIN, C.EINTR),
                  raw_transfer(fd,
                               TransferMechanism(fd),
                               TransferDirection(fd),
                               buf, Csize_t(count)))
        if n == -1
            err = errno()
            @db 2 n err errname(err)
            @assert err == C.EAGAIN ||
                    err == C.EPIPE
            n = 0
        end
        @ensure n <= count
        @db 2 return UInt(n)
    end
end

raw_transfer(fd, ::LibCTransfer, ::Out, buf, count) = C.write(fd, buf, count)
raw_transfer(fd, ::LibCTransfer, ::In,  buf, count) = C.read(fd, buf, count)

include("timer.jl")
include("poll.jl")
include("iouring.jl")
include("epoll.jl")
include("aio.jl")



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


include("pseudoterminal.jl") 
include("command.jl")
include("posix_spawn.jl")
include("fork.jl")



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
    if D == In
        fd.gothup && print(io, "☠️ ")
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
          "ProcessFailedException: ", e.cmd, ", ", "pid ", p.pid,
          (waskilled(p) ? (" killed by ", signame[p.signal]) :
                          (" exit status ", p.exit_code))...)
end


dbtiny(fd::FD) = string(fd)


# Compiler hints.

include("precompile.jl")
_precompile_()



end # module UnixIO
