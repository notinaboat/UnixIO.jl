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
import TypeTree                # for pretty-printed type trees in doc strings.
const typetree = TypeTree.tt



# Local Modules.

using DuplexIOs
using IOTraits
using IOTraits: In, Out, AnyDirection
using UnixIOHeaders
const C = UnixIOHeaders.C

include("macroutils.jl")
include("ccall.jl")
include("errors.jl")
include("debug.jl")
include("stat.jl")
include("warnings.jl")


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

    warning_queue_init()

    poll_queue_init()
    if Sys.islinux()
        epoll_queue_init()
        io_uring_queue_init()
    end
    if Sys.isapple()
        gsd_queue_init()
        #aio_queue_init()
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

mutable struct FD{D<:TransferDirection,T<:FDType,M<:TransferMode} <: IOTraits.Stream
    fd::RawFD
    isclosed::Bool
    nwaiting::Int
    const ready::Threads.Condition
    const closed::Threads.Condition
    gothup::Bool
    extra::ImmutableDict{Symbol,Any}

    FD{D}(fd) where D = FD{D,Union{}}(fd)

    FD{D,T}(fd) where {D,T} = FD{D,T,TransferMode{:Immediate}}(fd)

    function FD{D,T,M}(fd) where {D,T,M}
        if M != TransferMode{:Blocking}
            fcntl_setfl(fd, C.O_NONBLOCK)
        end
        fcntl_setfd(fd, C.O_CLOEXEC)
        _T = (T != Union{}) ? T : fdtype(fd)
        if _T == nothing
            error("Unable to determine type of file descriptor: $fd")
        end
        _M = (M != Union{}) ? M : typeof(TransferMode(_T))
        if TransferAPI(FD{D,_T,_M}) == nothing
            error("No $_M API found for $_T file descriptor.")
        end
        fd = new{D,_T,_M}(RawFD(fd),
                          false,
                          0,
                          Threads.Condition(),
                          Threads.Condition(),
                          false,
                          ImmutableDict{Symbol,Any}())
        warning_queue_push(fd)
        fd
    end
end

IOTraits.TransferDirection(::Type{<:FD{<:D}}) where D = D()
IOTraits.TransferMode(::Type{<:FD{D,T,M}}) where {D,T,M} = M()

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

@db function  IOTraits.isconnected(fd::FD)
    !fd.gothup
end

function fdtype(fd)

    t = stattype(fd)

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

IOTraits.TransferMode(T::Type{S_IFREG}) = TransferMode{:Async}()
#IOTraits.TransferMode(T::Type{S_IFBLK}) = TransferMode{:Async}()

IOTraits.TransferAPI(T::Type{<:FD{<:Any,<:Any,TransferMode{:Async}}}) =
    IOTraits.firstvalid(TransferAPI{:IOURing}(),
                        TransferAPI{:GSD}(),
                        TransferAPI{:AIO}())


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
Base.islocked(fd::FD) = islocked(fd.ready)
Base.assert_havelock(fd::FD) = Base.assert_havelock(fd.ready)

Base.convert(::Type{Cint}, fd::FD) = Base.cconvert(Cint, fd.fd)
Base.convert(::Type{Cuint}, fd::FD) = Cuint(convert(Cint, fd))
Base.convert(::Type{RawFD}, fd::FD) = RawFD(fd.fd)
#Mmap.gethandle(fd::FD) = RawFD(fd.fd)

include("ReadFD.jl")
include("WriteFD.jl")

io_trait_doc = """

# IO Traits

| FD Type         | Cursors  | Wait API |
| --------------- | -------- | -------- |
| S_IFDIR         |          |          |
| S_IFLNK         |          |          |
| S_IFREG         | Seekable |          |
| S_IFBLK         | Seekable | Poll     |
| S_IFIFO         |          | Poll     |
| S_IFSOCK        |          | Poll     |
| S_IFCHR         |          | Poll     |
| Pseudoterminal  |          | Poll     |
| CanonicalMode   |          | Poll     |
| PidFD           |          | Poll     |
"""
md_table_foreach_cell(io_trait_doc) do trait, fdtype, x
    trait = replace(trait, " " => "")
    ex = "IOTraits.$trait(::Type{<:FD{<:Any,<:$fdtype}}) = $trait{:$x}()"
    include_string(@__MODULE__, ex)
end


input_trait_doc = """

# Input Traits

| FD Type         | Read Unit | Availability  | Transfer Size | Total Size | Read Size API | Max Read API |
| --------------- | --------- | ------------- | ------------- | ---------- | ------------- | ------------ |
| S_IFDIR         |           |               |               | Variable   |               |              |
| S_IFLNK         |           |               |               | Zero       |               |              |
| S_IFREG         | Byte      | Always        | Unlimited     | Variable   | FStat         |              |
| S_IFBLK         | Byte      | Always        | Unlimited     | Fixed      | BLKGETSIZE    |              |
| S_IFIFO         | Byte      | Partial       | Limited       |            | FIONREAD      | GETPIPE_SZ   |
| S_IFSOCK        | Byte      | Partial       | Limited       |            | FIONREAD      | SO_RCVBUF    |
| S_IFCHR         | Byte      | Partial       | Unlimited     |            | FIONREAD      |              |
| Pseudoterminal  | Line      | Unknown       | Unlimited     |            |               |              |
| CanonicalMode   | Line      | Partial       | Unlimited     |            | FIONREAD      |              |
| PidFD           |           |               |               | Zero       |               |              |
"""
md_table_foreach_cell(input_trait_doc) do trait, fdtype, x
    trait = replace(trait, " " => "")
    ex = "IOTraits.$trait(::Type{<:FD{In,<:$fdtype}}) = $trait{:$x}()"
    include_string(@__MODULE__, ex)
end


IOTraits.LengthAPI(::Type{<:FD{<:AnyDirection,S_IFREG}}) = LengthAPI{:FStat}()
IOTraits.LengthAPI(::Type{<:FD{<:AnyDirection,S_IFBLK}}) =
    Sys.isapple() ? LengthAPI{:DKIOCGETBLOCKCOUNT}() :
                    LengthAPI{:BLKGETSIZE64}()

IOTraits.BlockSizeAPI(::Type{<:FD{<:AnyDirection,S_IFBLK}}) =
    Sys.isapple() ? BlockSizeAPI{:DKIOCGETBLOCKSIZE}() :
                    BlockSizeAPI{:BLKSSZGET}()

IOTraits.StreamIndexing(::Type{<:FD{<:AnyDirection,S_IFBLK}}) = IndexableIO()
IOTraits.StreamIndexing(::Type{<:FD{<:AnyDirection,S_IFREG}}) = IndexableIO()


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
$(join(typetree(FDType; mod=UnixIO)))
```

If the `FDType` argument is provided then `open` guarantees to return
`UnixIO{FDType}` (or throw an `ArgumentError` if `FDType` is not applicable
to `pathname`.

Note: `C.O_NONBLOCK` is always added to `flags` to ensure compatibility with
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html).
A `RawFD` can be opened in blocking mode by calling `C.open` directly.
"""
@db 1 function open(type::Type{T},
                    pathname, flags=nothing, mode=0o644;
                    transfer_mode::Type{M}=Union{},
                    timeout=Inf, tcattr=nothing) where {T,M}

    if flags == nothing # See Open Type test set.
        flags = C.O_RDWR
    end

    if M != TransferMode{:Blocking}
        flags |= C.O_NONBLOCK
    end

    if flags & C.O_RDWR == C.O_RDWR
        flags &= ~C.O_RDWR
        fout = FD{Out,T,M}(open_raw(pathname, flags | C.O_WRONLY, mode;
                                    tcattr))
        fin = FD{In,T,M}(open_raw(pathname, flags; tcattr))
        io = DuplexIO(IOTraits.BaseIO(IOTraits.LazyBufferedInput(fin)),
                      IOTraits.BaseIO(fout))
    else
        D = (flags & C.O_WRONLY) != 0 ? Out : In
        io = FD{D,T,M}(open_raw(pathname, flags, mode; tcattr))
        if D == In
            io = IOTraits.LazyBufferedInput(io)
        end
        io = IOTraits.BaseIO(io)
    end

    @ensure isopen(io)
    @db 1 return io
end

open(args...; kw...) = open(Union{}, args...; kw...)


@inline @db 1 function _open(type::Type{T},
                             path,
                             flags;
                             mode=0o644,
                             transfer_mode::Type{M}=Union{},
                             timeout=Inf,
                             tcattr=nothing) where {T<:FDType,M}

    flags |= C.O_NONBLOCK
    rawfd = open_raw(path, flags, mode; tcattr)
    D = (flags & C.O_WRONLY) == 0 ? In : Out
    fd = FD{D,T,M}(rawfd)
    @ensure isopen(fd)
    finalizer(fd) do fd
        if !fd.isclosed
            C.close(fd)
        end
    end
    @db 1 return fd
end

@inline function IOTraits.openread(type::Type, path, flags=Cint(0); kw...)
    @require flags & (C.O_RDWR | C.O_WRONLY) == 0
    flags = C.O_RDONLY
    _open(type, path, flags; kw...)
end

@inline function IOTraits.openwrite(type::Type, path, flags=Cint(0); kw...)
    @require flags & (C.O_RDWR) == 0
    flags = (C.O_WRONLY | C.O_CREAT #=| C.O_APPEND=#)
    _open(type, path, flags; kw...)
end

IOTraits.openread(args...; kw...) = IOTraits.openread(Union{}, args...; kw...)
IOTraits.openwrite(args...; kw...) = IOTraits.openwrite(Union{}, args...; kw...)

function openreadwrite(args...; kw...)
    out = IOTraits.openwrite(args...; kw...)
    in = IOTraits.openread(args...; kw...)
    in, out
end


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
    if fd.isclosed
        return
    end
    fd.isclosed = true
    @dblock fd.ready notify(fd.ready)
    yield()
    shutdown(fd)
    @cerr #=allow=C.EBADF=# C.close(fd)
    fd.fd = RawFD(-1)
    @dblock fd.closed notify(fd.closed)
    @ensure !isopen(fd)
    nothing
end

Base.close(io::Tuple{FD{In},FD{Out}}) = close.(io)


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
                                                 fd_offset::Union{Missing,UInt},
                                                 count::UInt)
    @require !fd.isclosed
    @require count > 0
    @require TransferMode(fd) == TransferMode{:Blocking}() ||
             (fcntl_getfl(fd) & C.O_NONBLOCK) != 0

    # Linux pwrite not POSIX compliant with O_APPEND
    # https://bugzilla.kernel.org/show_bug.cgi?id=43178
    @require !Sys.islinux() ||
             ismissing(fd_offset) ||
             (fcntl_getfl(fd) & C.O_APPEND) == 0

    while true
        n = @cerr(allow=(C.EAGAIN, C.EINTR),
                  raw_transfer(fd,
                               TransferAPI(fd),
                               TransferDirection(fd),
                               buf,
                               fd_offset,
                               Csize_t(count)))
        if n == -1
            @db 2 n err=errno() errname(err)
            n = 0
        end
        @ensure n >= 0
        @ensure n <= count
        @db 2 return UInt(unsigned(n))
    end
end

@inline @db 2 function raw_transfer(fd, ::TransferAPI{:LibC}, ::Out,
                                    buf, fd_offset, count)
    ismissing(fd_offset) ? C.write(fd, buf, count) :
                          C.pwrite(fd, buf, count, fd_offset)
end

@inline @db 2 function raw_transfer(fd, ::TransferAPI{:LibC}, ::In,
                                    buf, fd_offset, count)
    ismissing(fd_offset) ? C.read(fd, buf, count) :
                          C.pread(fd, buf, count, fd_offset)
end

raw_transfer(fd::FD{In,S_IFDIR}, ::TransferAPI{:LibC}, ::In,  args...) =
    error("Directory read not supported yet!")

include("timer.jl")
include("poll.jl")
if Sys.islinux()
    include("iouring.jl")
    include("epoll.jl")
end
if Sys.isapple()
    include("gsd.jl")
    #include("aio.jl")
end



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
@db 3 function socketpair()
    v = fill(RawFD(-1), 2)
    @cerr C.socketpair(C.AF_UNIX, C.SOCK_STREAM, 0, v)
    @ensure -1 ∉ v
    @db 3 return (v[1], v[2])
end


@doc README"""
### `UnixIO.pipe()` -- Unix FIFO Pipe for IPC.

    UnixIO.pipe() -> ::FD{In}, ::FD{Out}

Create a unidirectional FIFO pipe.
See [pipe(2)](https://man7.org/linux/man-pages/man2/pipe.2.html)
"""
@db 3 function pipe()
    v = fill(RawFD(-1), 2)
    @cerr C.pipe(v)
    @ensure -1 ∉ v
    @db 3 return (FD{In}(v[1]), FD{Out}(v[2]))
end



include("pseudoterminal.jl") 
include("command.jl")
include("posix_spawn.jl")
include("fork.jl")



# Pretty Printing.


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
    if D == In
        print(io, "FD{$t→}($fdint")
    else
        print(io, "FD{→$t}($fdint")
    end
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
