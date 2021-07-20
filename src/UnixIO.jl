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

export UnixFD, DuplexIO, @sh_str


"""
FIXME
  - Channel API?
      - all options configured on channel, not passed to take!
 - consider @noinline and @nospecialize, @noinline
 - specify types on kw args? check compiler log of methods generated
"""

using Base: @lock
using ReadmeDocs
using Preconditions
using AsyncLog

using DuplexIOs
using UnixIOHeaders
const C = UnixIOHeaders

include("errors.jl")
include("debug.jl")
include("stat.jl")


@db function __init__()
    debug_init()
    @db 1 "UnixIO.DEBUG_LEVEL = $DEBUG_LEVEL. See `src/debug.jl`."
    poll_queue_init()
    atexit(terminate_child_pids)

    global stdin
    global stdout
    global stderr
    stdin = ReadFD(RawFD(Base.STDIN_NO))
    stdout = WriteFD(RawFD(Base.STDOUT_NO))
    stderr = WriteFD(RawFD(Base.STDERR_NO))
end


# Event sources.

abstract type EPollEvents end
abstract type PollEvents end
abstract type SleepEvents end

DefaultEvents = begin
    x = get(ENV, "JULIA_IO_EVENT_SOURCE", nothing)
    x == "epoll"  ? EPollEvents :
    x == "poll"   ? PollEvents :
    x == "sleep"  ? SleepEvents :
    Sys.islinux() ? EPollEvents :
                    PollEvents
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

abstract type UnixFD{T,EventSource} <: IO end


@db 3 function UnixFD(fd, flags = fcntl_getfl(fd); events=DefaultEvents)
    @nospecialize

    @require lookup_unix_fd(fd) == nothing ||
             lookup_unix_fd(fd).isclosed

    r =
    flags & C.O_RDWR   != 0 ?  DuplexIO(ReadFD{events}(fd),
                                        WriteFD{events}(C.dup(fd))) :
    flags & C.O_RDONLY != 0 ?  ReadFD{events}(fd) :
    flags & C.O_WRONLY != 0 ?  WriteFD{events}(C.dup(fd)) :
                               @assert false
    @db 3 return r
end

debug_tiny(x::UnixFD) = string(x)

Base.stat(fd::UnixFD) = stat(fd.fd)
Base.wait(fd::UnixFD) = wait(fd.ready)
Base.lock(fd::UnixFD) = lock(fd.ready)
Base.unlock(fd::UnixFD) = unlock(fd.ready)
Base.notify(fd::UnixFD) = notify(fd.ready)
Base.islocked(fd::UnixFD) = islocked(fd.ready)
Base.assert_havelock(fd::UnixFD) = Base.assert_havelock(fd.ready)

Base.convert(::Type{Cint}, fd::UnixFD) = Base.cconvert(Cint, fd.fd)
Base.convert(::Type{RawFD}, fd::UnixFD) = RawFD(fd.fd)

include("ReadFD.jl")
include("WriteFD.jl")

DuplexIOs.DuplexIO(in::ReadFD, out::WriteFD) =
    invoke(DuplexIO, Tuple{IO,IO}, in, out)
DuplexIOs.DuplexIO(out::WriteFD, in::ReadFD) =
    invoke(DuplexIO, Tuple{IO,IO}, in, out)


# Reigistry of UnixFDs indexed by FD number.

const fd_vector = fill(WeakRef(nothing), 100)
const fd_vector_lock = Threads.SpinLock()

lookup_unix_fd(fd::Cint) = @lock fd_vector_lock fd_vector[fd+1].value

@db function register_unix_fd(fd::UnixFD)
    @nospecialize
    i = 1 + convert(Cint, fd)
    @lock fd_vector_lock begin
        if i > length(fd_vector)
            resize!(fd_vector, max(i, length(fd_vector) * 2))
        end
        fd_vector[i] = WeakRef(fd)
    end
    @ensure lookup_unix_fd(convert(Cint,fd)) == fd
end



README"## Opening and Closing Unix Files."


@doc README"""
### `UnixIO.open` -- Open Files.

    UnixIO.open(pathname, [flags = C.O_RDWR, [mode = 0o644]];
                          [timeout=Inf]) -> IO

Open the file specified by pathname.

Use `Base.close` to close the file.

The `IO` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
@db 1 function open(pathname, flags = C.O_RDWR, mode=0o644;
                    timeout=Inf, events=DefaultEvents)
    @nospecialize

    fd = @cerr C.open(pathname, flags | C.O_NONBLOCK, mode)
    io = UnixFD(fd, flags; events=events)
    @ensure isopen(io)
    @db 1 return io
end


@doc README"""
### `UnixIO.set_timeout` -- Configure Timeouts.

    UnixIO.set_timeout(fd::UnixFD, timeout)

Configure `fd` to limit IO operations to `timeout` seconds.
"""
set_timeout(fd::UnixFD, timeout) = fd.timeout = timeout


"""
Set the file status flags.
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
### `UnixIO.tcsetattr` -- Configure Terminals and Serial Ports.

    UnixIO.tcsetattr(tty::UnixFD;
                     [iflag=0], [oflag=0], [cflag=C.CS8], [lflag=0], [speed=0])

Set terminal device options.

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)
"""
@db 2 function tcsetattr(tty::UnixFD; iflag = 0,
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


@db 1 function Base.close(fd::UnixFD)
    @dblock fd begin
        fd.isclosed = true
        shutdown(fd)
        @cerr allow=C.EBADF C.close(fd)
        # FIXME Should we call wakeup_poll(poll_queue) here
        #       to prevent sprurious wakeups for this fd after it is closed?
        #       See note after `lookup_unix_fd` in poll.jl
        notify(fd)
    end
    @ensure !isopen(fd)
    nothing
end


Base.isopen(fd::UnixFD) = !fd.isclosed


@db 1 function Base.wait_close(fd::UnixFD; timeout=fd.timeout,
                                           deadline=timeout+time())
    @dblock fd begin
        timer = register_timer(deadline, fd.ready)
        try
            while isopen(fd) && time() < deadline           ;@db 3 "waiting..."
                if fd isa ReadFD
                    wait_for_event(fd)
                else
                    wait(fd) # FIXME reconsider
                end
            end
        finally
            close(timer)
        end
    end
    nothing
end


@doc README"""
### `UnixIO.shutdown` -- Signal end of transmission or reception.

    UnixIO.shutdown(sockfd, how)

Shut down part of a full-duplex connection.
`how` is one of `C.SHUT_RD`, `C.SHUT_WR` or `C.SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
@db 1 function shutdown(fd, how)
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
@db 2 function read(fd::ReadFD, buf, count=length(buf); timeout=fd.timeout)

    # First read from buffer.
    n = bytesavailable(fd.buffer)
    if n > 0                                          ;@db 2 "read from buffer"
        n = min(n, count)
        read_from_buffer(fd, buf, n);
        @ensure n >= 1
        @ensure n <= count
        @db 2 return n
    end

    # Then read from file.
    n = @with_timeout(fd, timeout, transfer(fd, buf, count))
    @db 2 return n
end

read_from_buffer(fd::ReadFD, buf, n) = readbytes!(fd.buffer, buf, n)
read_from_buffer(fd::ReadFD, buf::Ptr, n) = unsafe_read(fd.buffer, buf, n)


"""
Read or write (ReadFD or WriteFD) up to `count` bytes to or from `buf`
until `fd.deadline`.
Always attempt at least one call to `read(2)/write(2)`
even if `fd.deadline` has passed.
Return number of bytes transferred or `0` on timeout.
"""
@db 2 function transfer(fd::UnixFD, buf, count)
    @require !fd.isclosed
    @require count > 0

    n = raw_transfer(fd, buf, count)
    if n >= 0
        @db 2 return n
    end

    if time() < fd.deadline
        @dblock fd begin
            timer = register_timer(fd.deadline, fd.ready)
            try
                while time() < fd.deadline
                    n = raw_transfer(fd, buf, count);               ;@db 2 n
                    if n >= 0
                        @db 2 return n
                    end                                        ;@db 2 "wait..."
                    wait_for_event(fd)
                end
            finally
                close(timer)
            end
        end
    end

    @db 2 return 0 "timeout!"
end


"""
Read or write (ReadFD or WriteFD) up to `count` bytes to or from `buf`.
Return number of bytes transferred or `-1` on `C.EAGAIN`.
"""
@db 2 function raw_transfer(fd::UnixFD, buf, count)
    @require count > 0
    while true
        n = @cerr(allow=(C.EAGAIN, C.EINTR), raw_transfer(fd, buf, count))
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
@db 1 function write(fd::WriteFD, buf, count=length(buf); timeout=fd.timeout)
    n = @with_timeout(fd, timeout, transfer(fd, buf, count))
    @db 1 return n
end


@doc README"""
### `UnixIO.println` -- Write messages to the terminal.

    UnixIO.println(x...)
    UnixIO.printerr(x...)

Write directly to `STDOUT` or `STDERR`.
Does not yield control from the current task.
"""
println(x...) = raw_println(Base.STDERR_NO, x...)
printerr(x...) = raw_println(Base.STDERR_NO, x...)
function raw_println(fd, x...)
    io = IOBuffer()
    Base.println(io, x...)
    buf = take!(io)
    C.write(fd, buf, length(buf))
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
    r = @cerr C.system(command)
    if r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end
    @db return r
end

system(cmd::Cmd) = system(join(cmd.exec, " "))


function waitpid_error(cmd, status)
    @require !WIFEXITED(status) ||
              WEXITSTATUS(status) != 0
    if WIFSTOPPED(status)
        msg = "stopped by signal $(WSTOPSIG(status))"
    elseif WIFSIGNALED(status)
        msg = "killed by signal $(WTERMSIG(status))"
    elseif WIFEXITED(status)
        msg = "exited with status $(WEXITSTATUS(status))"
    end
    ErrorException("UnixIO.open($cmd) $msg")
end


@doc README"""
### `UnixIO.open(::Cmd) do...` -- Communicate with a sub-process.

    UnixIO.open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `posix_spawn`.

Connect (STDIN, STDOUT) to (`cmdin`, `cmdout`).

Call `f(cmdin, cmdout)`.

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
@db function open(f::Any, cmd::Cmd; check_status=true,
                                    capture_stderr=false)
    @nospecialize

    # Create Unix Domain Socket to communicate with Child Process STDIN/STDOUT.
    parent_io, child_io = socketpair()
    fcntl_setfd(parent_io, C.O_CLOEXEC)

    # Merge STDERR into STDOUT?
    # or leave connected to Parent Process STDERR?
    child_err = capture_stderr ? child_io : RawFD(Base.STDERR_NO)

    if true #Sys.isapple()
        pid = posix_spawn(cmd, child_io, child_io, child_err)
    else
        pid = fork_and_exec(cmd, child_io, child_io, child_err)
    end
    @assert pid > 0

    C.close(child_io)

    cmdin = WriteFD(parent_io)
    cmdout = ReadFD(C.dup(parent_io))

    # Run the IO handling function `f`.
    try                                           ;@db 1 "f ┬─($cmdin,$cmdout)"
                                                  ;@db_indent 1 "f"
        result = f(cmdin, cmdout)                 ;@db_unindent 1
                                                  ;@db 1 "  └─▶ 👍"
        # Close IO and send TERM signal.
        close(cmdin)
        close(cmdout)
        C.kill(pid, C.SIGHUP)                     ;@db 3 "SIGHUP -> $pid"

        # Get child process exit status.
        status = waitpid(pid; timeout=5.0)
        if WIFSIGNALED(status) && WTERMSIG(status) == C.SIGHUP
            status = 0
        end
        if status == nothing
            C.kill(pid, C.SIGKILL)                ;@db 3 "SIGKILL -> $pid"
            status = waitpid(pid)
        end
        if check_status
            if !WIFEXITED(status) || WEXITSTATUS(status) != 0
                throw(waitpid_error(cmd, status))
            end
            @db return result
        else
            @db return status, result
        end
    finally
        C.close(cmdin.fd)
        C.close(cmdout.fd)
        terminate_child(pid)
    end
end


function open(cmd::Cmd; kw...)
    c = Channel{Tuple{WriteFD,ReadFD}}(0)
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
        close(cmdin)
        Base.read(cmdout; timeout=timeout)
    end
    @db return r
end


WIFSIGNALED(x) = (((x & 0x7f) + 1) >> 1) > 0
WTERMSIG(x) = (x & 0x7f)
WIFEXITED(x) = WTERMSIG(x) == 0
WEXITSTATUS(x) = signed(UInt8((x >> 8) & 0xff))
WIFSTOPPED(x) = (x & 0xff) == 0x7f
WSTOPSIG(x) = WEXITSTATUS(x)

@doc README"""
### `UnixIO.waitpid` -- Wait for a sub-process to terminate.

    UnixIO.waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)
"""
@db function waitpid(pid::C.pid_t; timeout::Float64=Inf)
    status = Ref{Cint}(0)
    deadline = timeout + time()           ;@db 3 "deadline = $(db_t(deadline))"
    delay = nothing
    while true
        r = C.waitpid(pid, status, C.WNOHANG | C.WUNTRACED)            ;@db 3 r
        if r == -1
            err = errno()
            if err in (C.EINTR, C.EAGAIN)               ;@db 3 "EINTR / EAGAIN"
                continue
            elseif err == C.ECHILD
                @db return nothing "ECHILD (No child process)"
            end
            systemerror(string("C.waitpid($pid)"), err)
        end
        if r == pid
            @db return status[]
        end
        if time() >= deadline
            @db return nothing "timeout!"
        end

        delay = something(delay, exponential_delay())
        t = popfirst!(delay)                                 ;@db 3 "sleep($t)"
        sleep(t)
    end
end

exponential_delay() =
    Iterators.Stateful(ExponentialBackOff(n=typemax(Int); factor=2))



# Sub Processes.


function find_cmd_bin(cmd::Cmd)
    bin = Base.Sys.which(cmd.exec[1])
    bin != nothing || throw(ArgumentError("Command not found: $(cmd.exec[1])"))
    bin
end


"""
    posix_spawn(cmd, in, out, err; [env=ENV]) -> pid

Run `cmd` using `posix_spawn`.
Connect child process (STDIN, STDOUT, STDERR) to (`in`, `out`, `err`).
See (posix_spawn(3))[https://man7.org/linux/man-pages/man3/posix_spawn.3.html].
"""
@db function posix_spawn(cmd::Cmd, infd::RawFD, outfd::RawFD, errfd::RawFD;
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
                                                C.POSIX_SPAWN_SETPGROUP)

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

        # Create a new process group.
        @cerr0 C.posix_spawnattr_setpgroup(attr, 0)

        # Connect Child Process STDIN/OUT to socket.
        dup2(a, b) = @cerr0 C.posix_spawn_file_actions_adddup2(actions, a, b)
        dup2(infd,  Base.STDIN_NO)
        dup2(outfd, Base.STDOUT_NO)
        dup2(errfd, Base.STDERR_NO)

        # Start the Child Process
        GC.@preserve cmd env_vector begin
            @cerr0 C.posix_spawn(pid, cmd_bin, actions, attr, argv, envp)
        end
        @assert pid[] > 0
        register_child(pid[])

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
                                                               Base.C_NULL);

                                             # Connect STDIN/OUT to socket.
                                             C.dup2(infd,  Base.STDIN_NO)
                                             C.dup2(outfd, Base.STDOUT_NO)
                                             C.dup2(errfd, Base.STDERR_NO)

                                             # Execute command.
                                             C.execv(cmd_bin, args)
                                             C._exit(-1)
                                         end

        # Restore old signal mask.
        C.pthread_sigmask(C.SIG_SETMASK, oldmask, Base.C_NULL);

        @assert pid > 0
        register_child(pid)

        @db return pid
    end
end


const child_pids_lock = Threads.SpinLock()
const child_pids = Set{Cint}()

@db 1 function register_child(pid)
    @lock child_pids_lock push!(child_pids, pid)
end

@db 1 function terminate_child(pid)
    @lock child_pids_lock delete!(child_pids, pid)
    C.kill(pid, C.SIGKILL)
    @asynclog "UnixIO.terminate_child(::Cmd)" waitpid(pid)
end

@db 1 function terminate_child_pids()
    @sync for pid in child_pids                        ;@db 1 "SIGKILL -> $pid"
        C.kill(pid, C.SIGKILL)
        @async waitpid(pid)
    end
end



# Pretty Printing.


type_icon(::Type{S_IFIFO})  = "📥"
type_icon(::Type{S_IFCHR})  = "📞"
type_icon(::Type{S_IFDIR})  = "📂"
type_icon(::Type{S_IFBLK})  = "🧊"
type_icon(::Type{S_IFREG})  = "📄"
type_icon(::Type{S_IFLNK})  = "🔗"
type_icon(::Type{S_IFSOCK}) = "🧦"


function Base.show(io::IO, fd::UnixFD{T}) where T
    fdint = convert(Cint, fd)
    t = type_icon(T)

    print(io, "$(Base.typename(typeof(fd)).name){$t}($fdint")
    #fd.isdead && print(io, "☠️ ")
    fd.isclosed && print(io, "🚫")
    fd.nwaiting > 0 && print(io, repeat("👀", fd.nwaiting))
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



# Compiler hints.

include("precompile.jl")
_precompile_()



end # module UnixIO
