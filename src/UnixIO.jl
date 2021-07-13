"""
# UnixIO.jl

Unix IO Interface.

For Julia programs that need to interact with Unix-specific IO interfaces.

e.g. Character devices, Terminals, Unix domain sockets, Block devices etc.

    using UnixIO
    const C = UnixIO.C

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)

    fd = C.open("file.txt", C.O_CREAT | C.O_WRONLY)
    C.write(fd, "Hello!", 7)
    C.close(fd)

    io = UnixIO.open("file.txt", C.O_CREAT | C.O_WRONLY)
    write(io, "Hello!")
    close(io)

Blocking IO is multiplexed by running 
[`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html)
under a task started by `Threads.@spawn`.
See [`src/poll.jl`](src/poll.jl)
"""
module UnixIO

export UnixFD


using ReadmeDocs

using UnixIOHeaders
const C = UnixIOHeaders


# Unix File Descriptor wrapper.

struct UnixFD <: IO
    fd::Cint
    read_buffer::IOBuffer
    ready::Threads.Condition
    function UnixFD(fd)
        fcntl_setfl(fd, C.O_NONBLOCK)
        new(fd, PipeBuffer(), Threads.Condition())
    end
end


Base.convert(::Type{Cint}, fd::UnixFD) = fd.fd
Base.convert(::Type{RawFD}, fd::UnixFD) = RawFD(fd.fd)

Base.show(io::IO, fd::UnixFD) = print(io, "$(typeof(fd))($(fd.fd))")

include("baseio.jl")



# Errors.

ccall_error(call, args...) =
            Base.SystemError("UnixIO.$call$args failed", Base.Libc.errno())



README"## Opening and Closing Unix Files."


README"""
    UnixIO.open(pathname, [flags = C.O_RDWR]) -> UnixFD <: IO

Open the file specified by pathname.

The `UnixFD` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
function open(pathname, flags = C.O_RDWR)
    fd = C.open(pathname, flags)
    fd != -1 || throw(ccall_error(:open, pathname))
    UnixFD(fd)
end



README"---"

README"""
    UnixIO.fcntl_setfl(fd::UnixFD, flag)

Set `flag` in the file status flags. 
Uses `F_GETFL` to read the current flags and `F_SETFL` to store the new flag.
See [fcntl(2)](https://man7.org/linux/man-pages/man2/fcntl.2.html).
"""
function fcntl_setfl(fd, flag; getset=(C.F_GETFL, C.F_SETFL))
    get, set = getset
    flags = C.fcntl(fd, get)
    flags != -1 || throw(ccall_error(:fcntl_setfl, flag))
    if flags & flag == flag
        return nothing
    end
    flags |= flag
    r = C.fcntl(fd, set, flags)::Cint
    r != -1 || throw(ccall_error(:fcntl_setfl, flag))
    nothing
end

fcntl_setfd(fd, flag) = fcntl_setfl(fd, flag; getset=(C.F_GETFD, C.F_SETFD))


README"---"

README"""
    UnixIO.tcsetattr(tty::UnixFD;
                     [iflag=0], [oflag=0], [cflag=C.CS8], [lflag=0], [speed=0])

Set terminal device options.

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)
"""
function tcsetattr(tty::UnixFD; iflag = 0,
                                oflag = 0,
                                cflag = C.CS8,
                                lflag = 0,
                                speed = 0)

    conf = termios()
    conf.c_iflag = iflag
    conf.c_oflag = oflag
    conf.c_cflag = cflag
    conf.c_lflag = lflag
    @GC.preserve conf begin
        cfsetspeed(Ref(conf), eval(Symbol("B$speed")))
        tcsetattr(tty, TCSANOW, Ref(conf))
    end
end


README"---"

README"""
    UnixIO.close(fd::UnixFD)

Close a file descriptor, so that it no longer refers to
any file and may be reused.
See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)
"""
close(fd) = C.close(fd)


README"""
    UnixIO.shutdown(sockfd, [how = C.SHUT_WR])

Shut down part of a full-duplex connection.
`how` is one of `C.SHUT_RD`, `C.SHUT_WR` or `C.SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
shutdown(fd, how=C.SHUT_WR) = C.shutdown(fd, how)

@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::UnixFD) = shutdown(fd)
end



README"## Reading from Unix Files."


README"""
    UnixIO.read(fd, buf, count) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
"""
function read(fd::UnixFD, buf, count)
    n = bytesavailable(fd.read_buffer)
    if n > 0
        n = min(n, count)
        unsafe_read(fd.read_buffer, buf, n)
        return n
    end
    while true
        n = C.read(fd.fd, buf, count)
        if n != -1
            return n
        end
        if !(Base.Libc.errno() in (C.EAGAIN, C.EINTR))
            throw(ccall_error(:read, fd, buf, count))
        end
        poll_wait(fd, C.POLLIN)
    end
end

function C.read(fd::UnixFD, buf, count)
end

include("poll.jl")



README"## Writing to Unix Files."


README"""
    UnixIO.write(fd, buf, count) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)
"""
write(fd, buf, count) = C.write(fd, buf, count)



README"""
    UnixIO.println(x...)
    UnixIO.printerr(x...)

Write directly to `STDOUT` or `STDERR`.
Does not yield control from the current task.
"""
println(x...) = raw_println(STDERR, x...)
printerr(x...) = raw_println(STDERR, x...)
function raw_println(fd, x...)
    io = IOBuffer()
    Base.println(io, x...) 
    buf = take!(io)
    C.write(fd, buf, length(buf))
    nothing
end



README"## Unix Domain Sockets."


README"""
    socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)
"""
function socketpair()
    v = fill(Cint(-1), 2)
    r = C.socketpair(C.AF_UNIX, C.SOCK_STREAM, 0, v)
    r != -1 || throw(ccall_error(socketpair))
    (v[1], v[2])
end



README"## Executing Unix Commands."

macro sh_str(s)
    s = Meta.parse("\"$s\"")
    esc(:($s |> split |> Vector{String} |> Cmd |> read |> String |> chomp))
end

README"""
    UnixIO.system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)

e.g.
```
julia> UnixIO.system("uname -srm")
Darwin 20.3.0 x86_64
```
"""
function system(command)
    r = C.system(command)
    if r == -1
        throw(ccall_error(:system, command))
    elseif r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end
    r
end

system(cmd::Cmd) = system(join(cmd.exec, " "))


function waitpid_error(cmd, status)
    @assert !WIFEXITED(status) || WEXITSTATUS(status) != 0
    if WIFSTOPPED(status)
        msg = "stopped by signal $(WSTOPSIG(status))"
    elseif WIFSIGNALED(status)
        msg = "killed by signal $(WTERMSIG(status))"
    elseif WIFEXITED(status)
        msg = "exited with status $(WEXITSTATUS(status))"
    end
    ErrorException("UnixIO.open($cmd) $msg")
end


function cmd_bin(cmd::Cmd)
    bin = Base.Sys.which(cmd.exec[1])
    bin != nothing || throw(ArgumentError("Command not found: $(cmd.exec[1])"))
    bin
end


README"---"

README"""
    open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `fork` and `execv`.
Call `f(fd)` where `fd` is a socket connected to stdin/stdout of `cmd`.

e.g.
```
julia> UnixIO.open(`hexdump -C`) do io
           write(io, "Hello World!")
           shutdown(io)
           read(io, String)
       end |> println
00000000  48 65 6c 6c 6f 20 57 6f  72 6c 64 21              |Hello World!|
0000000c
```
"""
function open(f::Function, cmd::Cmd; check_status=true,
                                     capture_stderr=false)

    parent_io, child_io = socketpair()
    fcntl_setfd(parent_io, C.O_CLOEXEC)
    child_in = child_io
    child_out = child_io
    child_err = capture_stderr ? child_out : Base.STDERR_NO

    GC.enable(false)
    Base.sigatomic_begin()

    bin = cmd_bin(cmd)
    args = pointer.(cmd.exec)
    push!(args, Ptr{UInt8}(0))

#    GC.@preserve cmd begin
    pid = C.fork()
        if pid == 0
            C.dup2(child_in, Base.STDIN_NO)
            C.dup2(child_out, Base.STDOUT_NO)
            C.dup2(child_err, Base.STDERR_NO)
            C.execv(bin, args)
            C._exit(-1) # Only reached if execv() fails.
        end
#    end
    close(child_io)

    Base.sigatomic_end()
    GC.enable(true)

    status = 0
    result = try
        f(UnixFD(parent_io))
    catch
        C.kill(pid, C.SIGTERM)
        rethrow()
    finally
        C.close(parent_io)
        status = waitpid(pid)
    end
    if check_status
        if !WIFEXITED(status) || WEXITSTATUS(status) != 0
            throw(waitpid_error(cmd, status))
        end
        return result
    end
    return status, result
end

README"---"
README"""
    read(cmd::Cmd, String; [check_status=true, capture_stderr=false]) -> String
    read(cmd::Cmd; [check_status=true, capture_stderr=false]) -> Vector{UInt8}

Run `cmd` using `fork` and `execv`.
Return byes written to stdout by `cmd`.

e.g.
```
julia> UnixIO.read(`uname -srm`, String)
"Darwin 20.3.0 x86_64\n"
```
"""
read(cmd::Cmd, ::Type{String}; kw...) = String(read(cmd; kw...))

function read(cmd::Cmd; kw...)
    open(cmd; kw...) do io
        shutdown(io)
        Base.read(io)
    end
end


WIFSIGNALED(x) = (((x & 0x7f) + 1) >> 1) > 0
WTERMSIG(x) = (x & 0x7f)
WIFEXITED(x) = WTERMSIG(x) == 0
WEXITSTATUS(x) = signed(UInt8((x >> 8) & 0xff))
WIFSTOPPED(x) = (x & 0xff) == 0x7f
WSTOPSIG(x) = WEXITSTATUS(x)

README"---"

README"""
    UnixIO.waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)
"""
function waitpid(pid)
    status = Ref{Cint}(0)
    while true
        r = C.waitpid(pid, status, 0)
        if r == -1
            if Base.Libc.errno() == C.EINTR
                continue
            end
            throw(ccall_error(:waitpid, pid))
        end
        @assert r == pid
        return status[]
    end
end



end # module UnixIO
