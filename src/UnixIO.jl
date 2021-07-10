"""
# UnixIO.jl

Unix IO Interface.
"""
module UnixIO

export UnixFD


using ReadmeDocs

using CInclude
@cinclude "termios.h" quiet
@cinclude "fcntl.h" quiet
@cinclude "poll.h" quiet
@cinclude "sys/socket.h" quiet


# Unix File Descriptor wrapper.


struct UnixFD <: IO
    fd::Cint
    read_buffer::IOBuffer
    UnixFD(fd) = new(fd, PipeBuffer())
end

Base.convert(::Type{Cint}, fd::UnixFD) = fd.fd
Base.convert(::Type{RawFD}, fd::UnixFD) = RawFD(fd.fd)

Base.show(io::IO, fd::UnixFD) = print(io, "UnixFD($(fd.fd))")



# Standard Streams.


const STDIN = UnixFD(Base.STDIN_NO)
const STDOUT = UnixFD(Base.STDOUT_NO)
const STDERR = UnixFD(Base.STDERR_NO)



# Errors.


fd_error(fd::UnixFD, call) =
            Base.SystemError("UnixIO.$call($fd) failed", Base.Libc.errno())



# Threaded @ccall wrapper

TID() = Threads.threadid()
TID(t) = Threads.threadid(t)

mutable struct IOThreadState
    id::Int
    busy::Bool
    f::Symbol
    args::Tuple
    IOThreadState(id) = new(id, false, :nothing, ())
end

function thread_state(id)
    global io_thread_state
    for st in io_thread_state
        if st.id == id
            return st
        end
    end
    @assert false "Bad io_thread id: $id"
end

const io_thread_init_done = Ref(false)

function io_thread_init()

    if Threads.nthreads() < 6
        @error "UnixIO requires at least 6 threads. e.g. `julia --threads 6`"
        @async io_thread()
        return
    end

    n = Threads.nthreads()
    threads_ready = fill(false,n)

    # Only use half of the available threads.
    threads_ready[1:n÷2] .= true

    global io_thread_state
    io_thread_state = [IOThreadState(id) for id in n÷2+1:n-1]

    # Run `io_thread()` on each tread...
    Threads.@threads for i in 1:n
        id = Threads.threadid()
        if  id == n
            threads_ready[id] = true
            @async io_monitor()
        end
        if !threads_ready[id]
            threads_ready[id] = true
            @async io_thread(id, thread_state(id))
        end
    end
    yield()

    # Wait for all threads to start...
    while !all(threads_ready)
        sleep(1)
        if !all(threads_ready)
            x = length(threads_ready) - count(threads_ready)
            @info "Waiting to Initialise $x UnixIO Threads..."
        end
    end
end


"""
    UnixIO.@uassert cond [text]

Print a message directly to `STDERR` if `cond` is false,
then throw `AssertionError`.
"""
macro uassert(ex, msgs...)
    msg = isempty(msgs) ? ex : msgs[1]
    if isa(msg, AbstractString)
        msg = msg # pass-through
    elseif !isempty(msgs) && (isa(msg, Expr) || isa(msg, Symbol))
        # message is an expression needing evaluating
        msg = :(Main.Base.string($(esc(msg))))
    else
        msg = Main.Base.string(msg)
    end
    return quote
        if $(esc(ex))
            $(nothing)
        else
            printerr("UnixIO.@uassert failed ⁉️ :",
                     @__FILE__, ":", @__LINE__, ": ", $msg)
            throw(AssertionError($msg))
        end
    end
end


const io_queue = Channel{Tuple{Function, Tuple, Channel}}(0)

function io_thread(id::Int, state::IOThreadState)
    msg(x) = UnixIO.printerr("    io_thread($id): $x")
    #msg("starting...")
    try
        @uassert TID() == id
        for (f, args, result) in io_queue
            @uassert state.busy == false
            state.busy = true
            state.f = Symbol(f)
            state.args = args
            #msg("🟢 $f($args)")
            @uassert TID() == id
            put!(result, f(args...))
            @uassert TID() == id
            #msg("🔴 $f($args)")
            @uassert state.busy == true
            state.busy = false
            GC.safepoint()
        end
    catch err
        msg("error⁉️ : $err")
    end
    #msg("exiting!")
end


function io_monitor()
    msg(x) = UnixIO.printerr("io_monitor(): $x")
    while true
        try
            sleep(10)
            #msg("...")

            # Check Task Workqueues.
            for t in io_thread_state
                q = Base.Workqueues[t.id]
                l = length(q.queue)
                if l > 0
                    msg("io_thread($(t.id)): $l Tasks queued ⁉️ ")
                end
                if t.busy
                    msg("io_thread($(t.id)) busy: $(t.f)($(t.args))")
                end
            end

            # Check io_queue
            if !isempty(io_queue)
                msg("io_queue waiting ⁉️ ")
            end
        catch err
            msg("error⁉️ : $err")
        end
        GC.safepoint()
    end
end


macro yieldcall(expr)
    @assert expr.head == Symbol("::")
    @assert expr.args[1].head == :call
    f = expr.args[1].args[1]
    args = expr.args[1].args[2:end]
    T = expr.args[2]
    esc(quote
        global io_queue
        if !io_thread_init_done[]
            io_thread_init_done[] = true
            io_thread_init()
        end
        if !isempty(io_queue)
            @warn """
                  UnixIO.@yieldcall is waiting for an available thread.
                  Consider increasing JULIA_NUM_THREADS (`julia --threads N`).
                  """
        end
        #printerr("@yieldcall 🟢 $($f)($(($(args...),)))")
        c = Channel{$T}(0)
        put!(io_queue, ($f, ($(args...),), c))
        r = take!(c)
        Base.close(c)
        #printerr("@yieldcall 🔴 $($f)($($(args...)))")
        r::$T
    end)
end



README"## Opening and Closing Unix Files."


README"""
    UnixIO.open(pathname, [flags = O_RDWR]; [yield=false]) -> UnixFD

Open the file specified by pathname.

The `UnixFD` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
function open(args...; yield=false)
    fd = yield ? @yieldcall(c_open(args...)::Cint) :
                            c_open(args...)
    ufd = UnixFD(fd) 
    if fd == -1
        throw(fd_error(ufd, :open))
    end
    ufd
end


c_open(pathname::AbstractString, flags = O_RDWR) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint


README"""
    UnixIO.tcsetattr(tty::UnixFD;
                     [iflag=0], [oflag=0], [cflag=CS8], [lflag=0], [speed=0])

Set terminal device options.

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", UnixIO.O_RDWR | UnixIO.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=UnixIO.ICANON)
"""
function tcsetattr(tty::UnixFD; iflag = 0,
                                oflag = 0,
                                cflag = TERMIOS.CS8,
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


README"""
    UnixIO.close(fd::UnixFD)

Close a file descriptor, so that it no longer refers to
any file and may be reused.
See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)
"""
close(fd) = @ccall close(fd::Cint)::Cint


README"""
    UnixIO.shutdown(sockfd, [how = SHUT_WR])

Shut down part of a full-duplex connection.
`how` is one of `SHUT_RD`, `SHUT_WR` or `SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
shutdown(fd, how=SHUT_WR) = @ccall shutdown(fd::Cint, how::Cint)::Cint

@static if isdefined(Base, :shutdown)
    Base.shutdown(fd::UnixFD) = UnixIO.shutdown(fd)
end



README"## Reading from Unix Files."


README"""
    UnixIO.read(fd, buf, count; [yield=true]) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
"""
function read(fd::UnixFD, buf, count; yield=true)
    n = bytesavailable(fd.read_buffer)
    #printerr("read($fd,buf,$count), $n bytes in buffer t$(TID())")
    if n > 0
        n = min(n, count)
        unsafe_read(fd.read_buffer, buf, n)
#@info "    returning $n from buffer"
        return n
    end
    n = yield ? @yieldcall(c_read(fd.fd, buf, count)::Cint) :
                           c_read(fd.fd, buf, count)
#@info "    returning $n from fd"
    if n == -1
        throw(fd_error(fd, :read))
    end
    #printerr("RX $fd: \"$(unsafe_string(buf, min(n, 40)))\" t$(TID())")
    return n
end

c_read(fd, buf, count) =
    @ccall read(fd::Cint, buf::Ptr{Cvoid}, count::Csize_t)::Cint


README"## Writing to Unix Files."


README"""
    UnixIO.write(fd, buf, count; [yield=false]) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)
"""
write(fd, buf, count; yield=false) =
    yield ? @yieldcall(c_write(fd, buf, count)::Csize_t) :
                       c_write(fd, buf, count)
c_write(fd, buf, count) =
    @ccall write(fd::Cint, buf::Ptr{Cvoid}, count::Csize_t)::Csize_t



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
    UnixIO.write(fd, buf, length(buf); yield=false)
end



README"## Unix Domain Sockets."


README"""
    socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)
"""
function socketpair()
    v = fill(Cint(-1), 2)
    r = ccall(:socketpair, Cint, (Cint, Cint, Cint, Ptr{Cint}),
                                   AF_UNIX, SOCK_STREAM, 0, v)
    if r == -1
        throw(fd_error(fd, :socketpair))
    end
    (UnixFD(v[1]), UnixFD(v[2]))
end



README"## Polling."

mutable struct pollfd
    fd::Cint
    events::Cshort
    revents::Cshort
end

README"""
    poll(fds, nfds, timeout)
    poll([fd => event_mask, ...], timeout)

Wait for one of a set of file descriptors to become ready to perform I/O.
See [poll(2)](https://man7.org/linux/man-pages/man2/poll.2.html)
"""
poll(fds, nfds, timeout) =
    @ccall poll(fds::Ptr{Cvoid}, nfds::Cint, timeout::Cint)::Cint

function poll(fds, timeout)
    c_fds = [pollfd(fd.fd, events, 0) for (fd, events) in fds]
    n = GC.@preserve c_fds poll(pointer(c_fds), length(c_fds), timeout)
    if n == -1
        throw(Base.SystemError("UnixIO.poll($fds) failed", Base.Libc.errno()))
    end
    result = typeof(fds)()
    for (i, (fd, events)) in enumerate(fds)
        push!(result, fd => c_fds[i].revents )
    end
    return result
end



README"## Executing Unix Commands."

macro sh_str(s)
    s = Meta.parse("\"$s\"")
    esc(:($s |> split |> Vector{String} |> Cmd |> read |> String |> chomp))
end

README"""
    UnixIO.system(command; [yield=true]) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)

e.g.
```
julia> UnixIO.system("uname -srm")
Darwin 20.3.0 x86_64
```
"""
function system(command; yield=false)
    r = yield ? @yieldcall(c_system(command)::Cint) :
                           c_system(command)
    if r == -1
        throw(fd_error(fd, :system))
    elseif r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end
    nothing
end

system(cmd::Cmd) = system(join(cmd.exec, " "))

c_system(command) = @ccall system(command::Cstring)::Cint


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


function execv_args(bin, cmd)
    path = pointer(bin)
    args = [pointer(arg) for arg in cmd.exec]
    push!(args, Base.C_NULL)
    path, args
end


dup2(oldfd, newfd) = @ccall dup2(oldfd::Cint, newfd::Cint)::Cint
execv(path, args) = @ccall execv(path::Ptr{UInt8}, args::Ptr{Ptr{UInt8}})::Cint
_exit(status) = @ccall _exit(status::Cint)::Cvoid

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

    bin = cmd_bin(cmd)
    path, args = execv_args(bin, cmd)
    parent_io, child_io = socketpair()
    stderr_io = capture_stderr ? child_io : STDERR

    pid = GC.@preserve bin cmd ccall(:fork, Cint, ())
    if pid == 0
        close(parent_io)
        dup2(child_io, STDIN)
        dup2(child_io, STDOUT)
        dup2(stderr_io, STDERR)
        execv(path, args)
        _exit(-1) # Only reached if execv() fails.
    end
    close(child_io)

    status = 0
    result = try
        f(parent_io)
    catch
        @ccall kill(pid::Cint, 9::Cint)::Cint
        rethrow()
    finally
        close(parent_io)
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
    r = @ccall waitpid(pid::Cint, status::Ptr{Cint}, 0::Cint)::Cint
    if r == -1
        throw(fd_error(fd, :waitpid))
    end
    @assert r == pid
    return status[]
end



# Base.IO Interface

function Base.close(fd::UnixFD)
    if close(fd) == -1
        throw(fd_error(fd, :close))
    end
    nothing
end

Base.isopen(fd::UnixFD) =
    bytesavailable(fd.read_buffer) > 0 ||
    @yieldcall(c_read(fd, Base.C_NULL, 0)::Cint) == 0


Base.bytesavailable(fd::UnixFD) = bytesavailable(fd.read_buffer)


function Base.eof(fd::UnixFD)
# DEBUG    @info "eof($fd), $(bytesavailable(fd.read_buffer)) bytes in buffer"
    if bytesavailable(fd.read_buffer) == 0
        #printerr("eof($fd) reading into buffer... t$(TID())")
        Base.write(fd.read_buffer, readavailable(fd))
        #printerr("    eof($fd) read done ($(bytesavailable(fd.read_buffer))) t$(TID())")
    end
    return bytesavailable(fd.read_buffer) == 0
end


function Base.unsafe_read(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt)
# DEBUG    @info "unsafe_read($fd, buf, $nbytes)"
    nread = 0
    while nread < nbytes
        n = UnixIO.read(fd, buf + nread, nbytes - nread)
        if n == 0
            throw(EOFError())
        end
        nread += n
    end
    nothing
end



function Base.read(fd::UnixFD, ::Type{UInt8})
# DEBUG    @info "read($fd, UInt8)"
    eof(fd) && throw(EOFError())
    @assert bytesavailable(fd.read_buffer) > 0
    Base.read(fd.read_buffer, UInt8)
end


Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)

function Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true)
    #printerr("readbytes!($fd, buf, $nbytes) t$(TID())")
    lb = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 2, nbytes)
            #printerr("resize to $lb t$(TID())")
            resize!(buf, lb)
        end
        @assert lb > nread
        n = GC.@preserve buf UnixIO.read(fd, pointer(buf) + nread, lb - nread)
        if n == 0 || !all
            break
        end
        nread += n
    end
    return nread
end


const BUFFER_SIZE = 65536

function Base.readavailable(fd::UnixFD)
    buf = Vector{UInt8}(undef, BUFFER_SIZE)
# DEBUG    @info "readavailable($fd), reading into $(length(buf)) byte buffer"
    n = GC.@preserve buf UnixIO.read(fd, pointer(buf), length(buf))
# DEBUG    @info "readavailable($fd), got $n bytes"
    resize!(buf, n)
end


function Base.unsafe_write(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt)
    nwritten = 0
    while nwritten < nbytes
        #printerr("TX: \"$(unsafe_string(buf + nwritten, nbytes - nwritten))\"")
        n = UnixIO.write(fd, buf + nwritten, nbytes - nwritten)
        if n == -1
            throw(fd_error(fd, :write))
        end
        nwritten += n
    end
    return Int(nwritten)
end



end # module UnixIO
