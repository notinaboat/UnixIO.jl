"""
# UnixIO.jl

Unix IO Interface.

For Julia programs that need to interact with Unix-specific IO interfaces.

e.g. Character devices, Terminals, Unix domain sockets, Block devices etc.

    using UnixIO
    const C = UnixIO.C

    UnixIO.read(`curl https://julialang.org`, String; timeout=5)

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)
    readline(io; timeout=5)

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

If `UnixIO.enable_dumb_polling[]` is set to `true` IO polling is done by
a dumb loop with a 10ms delay. This may be more efficient for small
systems with simple IO requirements (e.g. communicating with a few
serial ports and sub-processes on a Raspberry Pi).
"""
module UnixIO

export UnixFD


using ReadmeDocs
using Preconditions
using AsyncLog

using DuplexIOs
using UnixIOHeaders
const C = UnixIOHeaders

function __init__()
    poll_queue_init()
    atexit(terminate_child_pids)
end



# Unix File Descriptor wrapper.

abstract type UnixFD <: IO end

include("ReadFD.jl")
include("WriteFD.jl")


Base.lock(fd::UnixFD) = lock(fd.ready)
Base.unlock(fd::UnixFD) = lock(fd.ready)
Base.notify(fd::UnixFD) = notify(fd.ready)
Base.islocked(fd::UnixFD) = islocked(fd.ready)

Base.convert(::Type{Cint}, fd::UnixFD) = fd.fd
Base.convert(::Type{RawFD}, fd::UnixFD) = RawFD(fd.fd)


function Base.show(io::IO, fd::UnixFD)
    print(io, "$(typeof(fd))($(fd.fd)")
    isopen(fd) || print(io, "☠️")
    fd.iswaiting && print(io, "⏳")
    islocked(fd) && print(io, "🔒")
    fd.timeout == Inf || print(io, ", ⏱", fd.timeout)
    if fd isa ReadFD
        n = bytesavailable(fd.buffer)
        if n > 0
            print(io, ", $n-byte buf")
        end
    end
    print(io, ")")
end



# Errors.


"""
Look up name for a C-constant `n`.
"""
function constant_name(n; prefix="")
    filter(names(C; all=true)) do name
        try 
            startswith(String(name), prefix) &&
            eval(:(C.$name)) == n
        catch
            false
        end
    end
end


function ccall_error(call, args...)
    errno = Base.Libc.errno()
    name = join(constant_name(errno; prefix="E"), "?")
    Base.SystemError("UnixIO.$call$args failed ($name)", errno)
end

struct ReadTimeoutError <: Exception
    fd::ReadFD
end

struct WriteTimeoutError <: Exception
    fd::WriteFD
end



README"## Opening and Closing Unix Files."


README"""
    UnixIO.open(pathname, [flags = C.O_RDWR]; [timeout=Inf]) -> IO

Open the file specified by pathname.

The `IO` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
function open(pathname, flags = C.O_RDWR; timeout=Inf)

    fd = C.open(pathname, flags | C.O_NONBLOCK)
    fd != -1 || throw(ccall_error(:open, pathname))

    if flags & C.O_RDWR != 0
        DuplexIO(ReadFD(fd, timeout), WriteFD(C.dup(fd), timeout))
    elseif flags & C.O_RDONLY != 0
        ReadFD(fd, timeout)
    elseif flags & C.O_WRONLY != 0
        WriteFD(C.dup(fd), timeout)
    end
end


README"---"

README"""
    UnixIO.set_timeout(fd::UnixFD, timeout)

Configure `fd` to throw `UnixIO.ReadTimeoutError` when read operations take
longer than `timeout` seconds.
"""
set_timeout(fd::UnixFD, timeout) = fd.timeout = timeout


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
    cfsetspeed(Ref(conf), eval(Symbol("B$speed")))
    tcsetattr(tty, TCSANOW, Ref(conf))
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
function shutdown(fd, how=C.SHUT_WR)
    if C.shutdown(fd, how) == -1 && Base.Libc.errno() != C.ENOTCONN
        throw(ccall_error(:shutdown, fd, how))
    end
    nothing
end



README"## Reading from Unix Files."


README"""
    UnixIO.read(fd, buf, [count=length(buf)];
                [timeout=Inf] ) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)

Throw `UnixIO.ReadTimeoutError` if read takes longer than `timeout` seconds.
"""
function read(fd::ReadFD, buf, count=length(buf); timeout=fd.timeout)

    # First read from buffer.
    n = bytesavailable(fd.buffer)
    if n > 0
        n = min(n, count)
        read_from_buffer(fd, buf, n)
        return n
    end

    # Then read from file.
    fd.deadline = time() + timeout
    while true
        n = C.read(fd.fd, buf, count)
        if n != -1
            return n
        end
        if !(Base.Libc.errno() in (C.EAGAIN, C.EINTR))
            throw(ccall_error(:read, fd, typeof(buf), count))
        end
        if time() > fd.deadline
            throw(ReadTimeoutError(fd))
        end
        wait_for_read_event(fd)
    end
end

read_from_buffer(fd::ReadFD, buf, n) = readbytes!(fd.buffer, buf, n)
read_from_buffer(fd::ReadFD, buf::Ptr, n) = unsafe_read(fd.buffer, buf, n)


include("poll.jl")



README"## Writing to Unix Files."


README"""
    UnixIO.write(fd, buf, [count=length(buf)];
                 [timeout=Inf] ) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)

Throw `UnixIO.WriteTimeoutError` if write takes longer than `timeout` seconds.
"""
function write(fd::WriteFD, buf, count=length(buf); timeout=Inf)
    fd.deadline = time() + timeout
    while true
        n = C.write(fd, buf, count)
        if n != -1
            return n
        end
        if !(Base.Libc.errno() in (C.EAGAIN, C.EINTR))
            throw(ccall_error(:read, fd, typeof(buf), count))
        end
        if time() > fd.deadline
            throw(WriteTimeoutError(fd))
        end
        wait_for_write_event(fd)
    end
end


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


function find_cmd_bin(cmd::Cmd)
    bin = Base.Sys.which(cmd.exec[1])
    bin != nothing || throw(ArgumentError("Command not found: $(cmd.exec[1])"))
    bin
end


README"---"

README"""
    open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `fork` and `execv`.
Call `f(cmdin, cmdout)`.

e.g.
```
julia> UnixIO.open(`hexdump -C`) do cmdin, cmdout
           write(cmdin, "Hello World!")
           shutdown(cmdin)
           read(cmdout, String)
       end |> println
00000000  48 65 6c 6c 6f 20 57 6f  72 6c 64 21              |Hello World!|
0000000c
```
"""
function open(f::Function, cmd::Cmd; check_status=true,
                                     capture_stderr=false)
    @nospecialize f

    # Create Unix Domain Socket to communicate with Child Process.
    parent_io, child_io = socketpair()

    fcntl_setfd(parent_io, C.O_CLOEXEC)
    cmdin = WriteFD(parent_io)
    cmdout = ReadFD(C.dup(parent_io))

    child_in = child_io
    child_out = child_io
    child_err = capture_stderr ? child_out : Base.STDERR_NO

    GC.enable(false)
    Base.sigatomic_begin();

        # Prepare arguments for `C.execv`.
        cmd_bin = find_cmd_bin(cmd)
        args = pointer.(cmd.exec)
        push!(args, Ptr{UInt8}(0))

        pid = C.fork()                  # Child process:
                                        if pid == 0
                                            # Connect STDIN/OUT to socket.
                                            C.dup2(child_in, Base.STDIN_NO)
                                            C.dup2(child_out, Base.STDOUT_NO)
                                            C.dup2(child_err, Base.STDERR_NO)

                                            # Execute command.
                                            C.execv(cmd_bin, args)
                                            C._exit(-1)
                                        end
    Base.sigatomic_end()
    GC.enable(true)

    register_child(pid)
    C.close(child_io)


    try
        # Run the IO handling function `f`.
        result = f(cmdin, cmdout)
        C.close(cmdin.fd)

        # Get child process exit status.
        while true
            status = waitpid(pid; timeout=1) #FIXME add a close notification?
            if status != nothing
                if check_status
                    if !WIFEXITED(status) || WEXITSTATUS(status) != 0
                        throw(waitpid_error(cmd, status))
                    end
                    return result
                else
                    return status, result
                end
            end
            if !isopen(cmdout)
                return result
            end
        end
    catch
        @asynclog "UnixIO.open(::Cmd)" waitpid(pid)
        rethrow()
    finally
        C.close(cmdin.fd)
        C.close(cmdout.fd)
        terminate_child(pid)
    end
end


const child_pids_lock = Threads.SpinLock()
const child_pids = Set{Cint}()

function register_child(pid)
    lock(child_pids_lock)
    try
        push!(child_pids, pid)
    finally
        unlock(child_pids_lock)
    end
end

function terminate_child(pid)
    lock(child_pids_lock)
    try
        delete!(child_pids, pid)
    finally
        unlock(child_pids_lock)
    end
    C.kill(pid, C.SIGKILL)
    @async waitpid(pid)
end

function terminate_child_pids()
    @sync for pid in child_pids
        C.kill(pid, C.SIGKILL)
        @async waitpid(pid)
    end
end


function open(cmd::Cmd; kw...)
    c = Channel{Tuple{WriteFD,ReadFD}}(0)
    @asynclog "UnixIO.open(::Cmd)" open(cmd; kw...) do cmdin, cmdout
        put!(c, (cmdin, cmdout))
        while isopen(cmdin) || isopen(cmdout) # FIXME close notify?
            sleep(1)
        end
    end
    take!(c)
end


README"---"

README"""
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
read(cmd::Cmd, ::Type{String}; kw...) = String(read(cmd; kw...))

function read(cmd::Cmd; timeout=Inf, kw...)
    open(cmd; kw...) do cmdin, cmdout
        shutdown(cmdin)
        Base.read(cmdout; timeout=timeout)
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
function waitpid(pid; timeout=Inf)
    status = Ref{Cint}(0)
    deadline = time() + timeout
    while true
        r = C.waitpid(pid, status, C.WNOHANG | C.WUNTRACED)
        if r == -1
            if Base.Libc.errno() == C.EINTR
                continue
            end
            throw(ccall_error(:waitpid, pid))
        end
        if r == pid
            return status[]
        end
        if time() >= deadline
            return nothing
        end
        sleep(1)
    end
end



end # module UnixIO
