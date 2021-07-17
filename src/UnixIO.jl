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

export UnixFD, DuplexIO


using Base: @lock
using ReadmeDocs
using Preconditions
using AsyncLog

using DuplexIOs
using UnixIOHeaders
const C = UnixIOHeaders

include("errors.jl")
include("debug.jl")

function __init__()
    global debug_t0
    debug_t0 = time()
    poll_queue_init()
    atexit(terminate_child_pids)

    global stdin
    global stdout
    global stderr
    stdin = ReadFD(Base.STDIN_NO)
    stdout = WriteFD(Base.STDOUT_NO)
    stderr = WriteFD(Base.STDERR_NO)
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



# Unix File Descriptor wrapper.

abstract type UnixFD{EventSource} <: IO end


function UnixFD(fd, flags = fcntl_getfl(fd); events=DefaultEvents)

    @require lookup_unix_fd(fd) == nothing ||
             lookup_unix_fd(fd).isclosed

    flags & C.O_RDWR   != 0 ?  DuplexIO(ReadFD{events}(fd),
                                        WriteFD{events}(C.dup(fd))) :
    flags & C.O_RDONLY != 0 ?  ReadFD{events}(fd) :
    flags & C.O_WRONLY != 0 ?  WriteFD{events}(C.dup(fd)) :
                               @assert false 
end

Base.wait(fd::UnixFD) = wait(fd.ready)
Base.lock(fd::UnixFD) = lock(fd.ready)
Base.unlock(fd::UnixFD) = unlock(fd.ready)
Base.notify(fd::UnixFD) = notify(fd.ready)
Base.islocked(fd::UnixFD) = islocked(fd.ready)
Base.assert_havelock(fd::UnixFD) = Base.assert_havelock(fd.ready)

Base.convert(::Type{Cint}, fd::UnixFD) = fd.fd
Base.convert(::Type{RawFD}, fd::UnixFD) = RawFD(fd.fd)

include("ReadFD.jl")
include("WriteFD.jl")


function Base.show(io::IO, fd::UnixFD)
    print(io, "$(Base.typename(typeof(fd)).name)($(fd.fd)")
    fd.isdead && print(io, "☠️")
    fd.isclosed && print(io, "🚫")
    fd.nwaiting > 0 && print(io, repeat("⏳", fd.nwaiting))
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



# Reigistry of UnixFDs indexed by FD number.


const fd_vector = fill(WeakRef(nothing), 100)
const fd_vector_lock = Threads.SpinLock()
lookup_unix_fd(fd) = @lock fd_vector_lock fd_vector[fd+1].value

function register_unix_fd(fd::UnixFD)              ;@dbf 1 :register_unix_fd fd
    i = fd.fd+1
    @lock fd_vector_lock begin
        if i > length(fd_vector)
            resize!(fd_vector, max(i, length(fd_vector) * 2))
        end
        fd_vector[i] = WeakRef(fd)
    end
    @ensure lookup_unix_fd(fd.fd) == fd;                                 @dbr 1
end



README"## Opening and Closing Unix Files."


README"""
    UnixIO.open(pathname, [flags = C.O_RDWR]; [timeout=Inf]) -> IO

Open the file specified by pathname.

Use `Base.close` to close the file.

The `IO` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
function open(pathname, flags = C.O_RDWR; timeout=Inf, events=DefaultEvents)
                                                 @dbf 2 :open (pathname, flags)
    fd = @cerr C.open(pathname, flags | C.O_NONBLOCK)
    io = UnixFD(fd, flags; events=events)
    @ensure isopen(io)                                               ;@dbr 2 io
    io
end


README"---"

README"""
    UnixIO.set_timeout(fd::UnixFD, timeout)

Configure `fd` to limit IO operations to `timeout` seconds.
"""
set_timeout(fd::UnixFD, timeout) = fd.timeout = timeout


README"---"

README"""
    UnixIO.fcntl_getfl(fd::UnixFD)

Set the file status flags.
Uses `F_GETFL` to read the current flags.
See [fcntl(2)](https://man7.org/linux/man-pages/man2/fcntl.2.html).
"""
fcntl_getfl(fd; get=C.F_GETFL) = @cerr C.fcntl(fd, get)


README"""
    UnixIO.fcntl_setfl(fd::UnixFD, flag)

Set `flag` in the file status flags.
Uses `F_GETFL` to read the current flags and `F_SETFL` to store the new flag.
See [fcntl(2)](https://man7.org/linux/man-pages/man2/fcntl.2.html).
"""
function fcntl_setfl(fd, flag; get=C.F_GETFL, set=C.F_SETFL)
    @db 3 "fcntl_setfl($fd, $flag)"
    flags = fcntl_getfl(fd; get=get)
    if flags & flag == flag
        return nothing
    end
    flags |= flag
    @cerr C.fcntl(fd, set, flags)
end

fcntl_setfd(fd, flag) = fcntl_setfl(fd, flag; get=C.F_GETFD, set=C.F_SETFD)


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
                                                         @db 2 "tcsetattr($fd)"
    conf = termios()
    conf.c_iflag = iflag
    conf.c_oflag = oflag
    conf.c_cflag = cflag
    conf.c_lflag = lflag
    cfsetspeed(Ref(conf), eval(Symbol("B$speed")))
    tcsetattr(tty, TCSANOW, Ref(conf))
end


function Base.close(fd::UnixFD)                                @dbf 3 :close fd
                                                                   @dblock 1 fd
    @lock fd begin
        fd.isclosed = true
        @cerr allow=C.EBADF C.close(fd)
        notify(fd)
    end
    @ensure !isopen(fd)                                                 ;@dbr 3
    nothing
end


Base.isopen(fd::UnixFD) = !fd.isclosed


#=
function isclosed(fd::UnixFD)                           ;@dbf 6 "isclosed($fd)"
    if fd.isclosed || fd.isdead                                   ;@db 6 "true"
        return true 
    end
    fd.isdead = C.fcntl(fd, C.F_GETFL) == -1
    fd.isdead && @db 2 "☠️:: isclosed($fd)"
    return fd.isdead
end
=#




function Base.wait_close(fd::UnixFD; timeout=fd.timeout,
                                     deadline=time()+timeout)

                                        @dbf 2 :wait_close (fd, db_t(deadline))
                                                                   @dblock 1 fd
    @lock fd begin
        t = register_timer(deadline, fd.ready)
        try
            while isopen(fd) && time() < deadline        ;@db 3 "waiting..."
                wait_for_event(fd)
            end
        finally
            cancel_timer(t)
        end
    end                                                                 ;@dbr 2
    nothing
end


README"""
    UnixIO.shutdown(sockfd, [how = C.SHUT_WR])

Shut down part of a full-duplex connection.
`how` is one of `C.SHUT_RD`, `C.SHUT_WR` or `C.SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
function shutdown(fd, how=C.SHUT_WR)
    @db 3 "shutdown($fd, $how)"
    @cerr allow=C.ENOTCONN C.shutdown(fd, how)
end



README"## Reading from Unix Files."


README"""
    UnixIO.read(fd, buf, [count=length(buf)];
                [timeout=Inf] ) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
"""
function read(fd::ReadFD, buf, count=length(buf); timeout=fd.timeout,
                                                  deadline=time()+timeout)
    # First read from buffer.
    n = bytesavailable(fd.buffer)                     ;@dbf 3 :read (fd, count)
    if n > 0
        n = min(n, count)
        read_from_buffer(fd, buf, n);                  ;@dbr 3 "$n from buffer"
        @ensure n >= 1
        @ensure n <= count
        return n
    end

    # Then read from file.
    n = transfer(fd, buf, count, deadline)               ;@dbr 3 "$n from file"
    return n
end

"""
Read or write (ReadFD or WriteFD) up to `count` bytes to or from `buf`
until `deadline`.
Return number of bytes transferred.
"""
function transfer(fd::UnixFD, buf, count, deadline)
    @require !fd.isclosed                  
    @require fd.nwaiting >= 0
    @require count > 0
                                   @dbf 3 :transfer (fd, count, db_t(deadline))
                                                                   @dblock 1 fd
    @lock fd begin
        n = -1
        t = time() < deadline ? register_timer(deadline, fd.ready) : nothing
        try
            while n == -1 && !fd.isclosed
                n = @cerr allow=(C.EAGAIN, C.EINTR) transfer(fd, buf, count)
                                                                @db 6 "C -> $n"
                if n == -1
                    if Base.Libc.errno() == C.EINTR
                                                                ;@db 3 "EINTR!"
                    else
                        if time() < deadline;                ;@db 3 "waiting.."
                            wait_for_event(fd)
                        else                                  ;@db 3 "timeout!"
                            n = 0
                        end
                    end
                elseif n == 0                                   ;@db 3 "💥HUP!"
                    @assert fd isa ReadFD """
                                          C.write returned 0!
                                          https://stackoverflow.com/q/41904221/
                                          """
                    fd.isdead = true
                end
            end
        finally 
            t == nothing || cancel_timer(t)
        end 
                                                                       @dbr 3 n
        @ensure fd.nwaiting >= 0
        @ensure n >= 0
        @ensure n <= count
        return n
    end
end

read_from_buffer(fd::ReadFD, buf, n) = readbytes!(fd.buffer, buf, n)
read_from_buffer(fd::ReadFD, buf::Ptr, n) = unsafe_read(fd.buffer, buf, n)


include("timer.jl")
include("poll.jl")



README"## Writing to Unix Files."


README"""
    UnixIO.write(fd, buf, [count=length(buf)];
                 [timeout=Inf] ) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)
"""
function write(fd::WriteFD, buf, count=length(buf); timeout=Inf,
                                                    deadline=time()+timeout)
    @db 3 "UnixIO.write($fd, $count)"
    return transfer(fd, buf, count, deadline)
end


README"""
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


README"""
    socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)
"""
function socketpair()
    v = fill(Cint(-1), 2)
    @cerr C.socketpair(C.AF_UNIX, C.SOCK_STREAM, 0, v)
    @ensure !(-1 in v)
    @db 3 "socketpair() -> $((v...,))"
    return (v[1], v[2])
end



README"## Executing Unix Commands."

README"""
    sh"shell command"

String containing result of shell command. e.g.

    julia> println("Machine is ", sh"uname -m")
    Machine is x86_64
"""
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
function system(command)                                ;@dbf 2 :system command
    r = @cerr C.system(command)
    if r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end                                                               ;@dbr 2 r
    return r
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
    @nospecialize f;                                  @dbf 2 :open "$cmd do..."

    # Create Unix Domain Socket to communicate with Child Process.
    parent_io, child_io = socketpair()

    fcntl_setfd(parent_io, C.O_CLOEXEC)
    cmdin = WriteFD(parent_io)                           ;@db 2 "cmdin: $cmdin"
    cmdout = ReadFD(C.dup(parent_io))                  ;@db 2 "cmdout: $cmdout"

    child_in = child_io
    child_out = child_io
    child_err = capture_stderr ? child_out : Base.STDERR_NO

    GC.enable(false)
    Base.sigatomic_begin();

    # Prepare arguments for `C.execv`.
    cmd_bin = find_cmd_bin(cmd)
    args = pointer.(cmd.exec)
    push!(args, Ptr{UInt8}(0))

    pid = C.fork()                      # Child process:
                                        if pid == 0
                                            # Connect STDIN/OUT to socket.
                                            C.dup2(child_in, Base.STDIN_NO)
                                            C.dup2(child_out, Base.STDOUT_NO)
                                            C.dup2(child_err, Base.STDERR_NO)

                                            # Execute command.
                                            C.execv(cmd_bin, args)
                                            C._exit(-1)
                                        end
                                                    ;@db 4 "forked -> pid $pid"
    # Main process:
    Base.sigatomic_end()
    GC.enable(true)

    @assert pid > 0
    register_child(pid)
    C.close(child_io)

    try                                              ;@db 3 "f($cmdin,$cmdout)"
        # Run the IO handling function `f`.  
        result = f(cmdin, cmdout)                            ;@db 3 "f() done!"

        # Close IO and send TERM signal.
        close(cmdin)
        close(cmdout)
        C.kill(pid, C.SIGHUP)                           ;@db 3 "SIGHUP -> $pid"

        # Get child process exit status.
        status = waitpid(pid; timeout=1)
        if WIFSIGNALED(status) && WTERMSIG(status) == C.SIGHUP
            status = 0
        end
        if status == nothing
            C.kill(pid, C.SIGKILL)                     ;@db 3 "SIGKILL -> $pid"
            status = waitpid(pid)
        end                                           ;@dbr 2 "$pid -> $status"
        if check_status
            if !WIFEXITED(status) || WEXITSTATUS(status) != 0
                throw(waitpid_error(cmd, status))
            end
            return result
        else
            return status, result
        end
    finally
        C.close(cmdin.fd)
        C.close(cmdout.fd)
        terminate_child(pid)
    end
end


const child_pids_lock = Threads.SpinLock()
const child_pids = Set{Cint}()

function register_child(pid)                      ;@db 3 "register_child($pid)"
    @lock child_pids_lock push!(child_pids, pid)
end

function terminate_child(pid)         ;@db 3 "terminate_child($pid) -> SIGKILL"
    @lock child_pids_lock delete!(child_pids, pid)
    C.kill(pid, C.SIGKILL)
    @asynclog "UnixIO.terminate_child(::Cmd)" waitpid(pid)
end

function terminate_child_pids()                   ;@dbf 3 :terminate_child_pids
    @sync for pid in child_pids                        ;@db 3 "SIGKILL -> $pid"
        C.kill(pid, C.SIGKILL)               
        @async waitpid(pid)
    end                                                                 ;@dbr 3
end


function open(cmd::Cmd; kw...);                                @dbf 3 :open cmd
    c = Channel{Tuple{WriteFD,ReadFD}}(0)
    @asynclog "UnixIO.open(::Cmd)" open(cmd; kw...) do cmdin, cmdout
        put!(c, (cmdin, cmdout))
        @sync begin
            @async Base.wait_close(cmdin)
            @async Base.wait_close(cmdout)
        end
    end                                                               ;@dbr 3 c
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

function read(cmd::Cmd; timeout=Inf, kw...)                   ;@dbf 3 :read cmd
    r = open(cmd; kw...) do cmdin, cmdout
        shutdown(cmdin)
        Base.read(cmdout; timeout=timeout)
    end                                                       ;@dbr 3 typeof(r)
    return r
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
function waitpid(pid; timeout=Inf)                         ;@dbf 3 :waitpid pid
    status = Ref{Cint}(0)
    deadline = time() + timeout           ;@db 3 "deadline = $(db_t(deadline))"
    delay = nothing
    while true
        r = C.waitpid(pid, status, C.WNOHANG | C.WUNTRACED)     ;@db 3 "r = $r"
        if r == -1
            errno = Base.Libc.errno()
            if errno in (C.EINTR, C.EAGAIN)             ;@db 3 "EINTR / EAGAIN"
                continue
            elseif errno == C.ECHILD        ;@dbr 3 "ECHILD (No child process)"
                return nothing
            end
            throw(ccall_error(C.waitpid, (pid,)))
        end
        if r == pid                                ;@dbr 3 "status=$(status[])"
            return status[]
        end
        if time() >= deadline                                ;@dbr 3 "timeout!"
            return nothing
        end                                                   ;@db 3 "sleep(1)"

        delay = something(delay, exponential_delay())
        sleep(popfirst!(delay))
    end
end

exponential_delay() =
    Iterators.Stateful(ExponentialBackOff(n=typemax(Int); factor=2))



end # module UnixIO
