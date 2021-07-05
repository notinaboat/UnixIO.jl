"""
# UnixIO.jl

Unix IO Interface.
"""
module UnixIO

export UnixFD


using ReadmeDocs



# Unix File Descriptor wrapper.


struct UnixFD <: IO
    fd::Cint
    read_buffer::IOBuffer
    UnixFD(fd) = new(fd, PipeBuffer())
end

Base.convert(::Type{Cint}, fd::UnixFD) = fd.fd
Base.convert(::Type{RawFD}, fd::UnixFD) = RawFD(fd.fd)



# Standard Streams.


const STDIN = UnixFD(Base.STDIN_NO)
const STDOUT = UnixFD(Base.STDOUT_NO)
const STDERR = UnixFD(Base.STDERR_NO)



# Errors.


fd_error(fd::UnixFD, call) =
            Base.SystemError("UnixIO.$call($fd) failed", Base.Libc.errno())



# @ccall wrapper

macro yieldccall(yield, f, rettype, argtypes, argvals...)
    esc(:(if $yield
        if threadcall_pool_is_busy()
            @warn """
                  @threadcall is blocked because libuv threadpool is busy.
                  Consider increasing UV_THREADPOOL_SIZE.
                  See also: https://github.com/JuliaLang/julia/issues/21045
                  """
        end
        @threadcall($f, $rettype, $argtypes, $(argvals...))
    else
        ccall($f, $rettype, $argtypes, $(argvals...))
    end))
end

threadcall_pool_is_busy() = Base.threadcall_restrictor.sem_size ==
                            Base.threadcall_restrictor.curr_cnt



README"## Opening and Closing Unix Files."


const O_RDONLY    = Base.Filesystem.JL_O_RDONLY
const O_WRONLY    = Base.Filesystem.JL_O_WRONLY
const O_RDWR      = Base.Filesystem.JL_O_RDWR
const O_CREAT     = Base.Filesystem.JL_O_CREAT
const O_RDWR      = Base.Filesystem.JL_O_RDWR
const O_EXCL      = Base.Filesystem.JL_O_EXCL
const O_NOCTTY    = Base.Filesystem.JL_O_NOCTTY
const O_TRUNC     = Base.Filesystem.JL_O_TRUNC
const O_APPEND    = Base.Filesystem.JL_O_APPEND


README"""
    open(pathname, [flags = O_RDWR]; [yield=false]) -> UnixFD

Open the file specified by pathname.

The `UnixFD` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc)

See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
open(args...; kw...) = UnixFD(open_raw(args...; kw...))

open_raw(pathname::AbstractString, flags = O_RDWR; yield=false) =
    @yieldccall(yield, :open, Cint, (Cstring, Cint), pathname, flags)


README"""
    close(fd::UnixFD)

Close a file descriptor, so that it no longer refers to
any file and may be reused.
See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)
"""
close(fd) = @ccall close(fd::Cint)::Cint



README"## Reading from Unix Files."


README"""
    read(fd, buf, count; [yield=true]) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
"""
read(fd, buf, count; yield=true) =
    @yieldccall(yield, :read, Cint, (Cint, Ptr{Cvoid}, Csize_t),
                                    fd, buf, count)

function read(fd::UnixFD, buf, count; kw...)
    n = bytesavailable(fd.read_buffer)
    if n > 0
        n = min(n, count)
        unsafe_read(fd.read_buffer, buf, n)
        return n
    end
    n = read(fd.fd, buf, count; kw...)
    if n == -1
        throw(fd_error(fd, :read))
    end
    return n
end



README"## Writing to Unix Files."


README"""
    write(fd, buf, count; [yield=true]) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)
"""
write(fd, buf, count; yield=true) =
    @yieldccall(yield, :write, Csize_t, (Cint, Ptr{Cvoid}, Csize_t),
                                        fd, buf, count)



README"## Unix Domain Sockets."


const AF_UNIX = 1
const SOCK_STREAM = 1

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


const SHUT_RD = 0
const SHUT_WR = 1
const SHUT_RDWR = 2

README"""
    shutdown(sockfd, how)
    shutdown_read(sockfd)
    shutdown_write(sockfd)

Shut down part of a full-duplex connection.
`how` is one of `SHUT_RD`, `SHUT_WR` or `SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
shutdown(sockfd, how) = @ccall shutdown(sockfd::Cint, how::Cint)::Cint
shutdown_read(sockfd) = shutdown(sockfd, SHUT_RD)
shutdown_write(sockfd) =  shutdown(sockfd, SHUT_WR)



README"## Polling."

const POLLIN   = 0x01
const POLLPRI  = 0x02
const POLLOUT  = 0x04
const POLLERR  = 0x08
const POLLHUP  = 0x10
const POLLNVAL = 0x20

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
poll(fds, nfds, timeout; yield=true) = @yieldccall(yield, :poll, Cint,
                                                   (Ptr{Cvoid}, Cint, Cint),
                                                   fds, nfds, timeout)

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


README"""
    system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)
"""
function system(command; yield=true) 
    r = @yieldccall(yield, :system, Cint, (Cstring,), command)
    if r == -1
        throw(fd_error(fd, :system))
    elseif r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end
    nothing
end


WIFSIGNALED(x) = (((x & 0x7f) + 1) >> 1) > 0
WTERMSIG(x) = (x & 0x7f)
WIFEXITED(x) = WTERMSIG(x) == 0
WEXITSTATUS(x) = signed(UInt8((x >> 8) & 0xff))
WIFSTOPPED(x) = (x & 0xff) == 0x7f
WSTOPSIG(x) = WEXITSTATUS(x)


README"""
    waitpid(pid) -> status

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


README"""
    open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `fork` and `execv`.
Call `f(fd)` where `fd` is a socket connected to stdin/stdout of `cmd`.
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


README"""
    read(cmd::Cmd, String; [check_status=true, capture_stderr=false]) -> String
    read(cmd::Cmd; [check_status=true, capture_stderr=false]) -> Vector{UInt8}

Run `cmd` using `fork` and `execv`.
Return byes written to stdout by `cmd`.
"""
read(cmd::Cmd, ::Type{String}; kw...) = String(read(cmd; kw...))

function read(cmd::Cmd; kw...)
    open(cmd; kw...) do io
        shutdown(io, SHUT_WR)
        Base.read(io)
    end
end



# Base.IO Interface

function Base.close(fd::UnixFD)
    if close(fd) == -1
        throw(fd_error(fd, :close))
    end
    nothing
end


Base.bytesavailable(fd::UnixFD) = bytesavailable(fd.read_buffer)


function Base.eof(fd::UnixFD)
    if bytesavailable(fd.read_buffer) == 0
        Base.write(fd.read_buffer, readavailable(fd))
    end
    return bytesavailable(fd.read_buffer) == 0
end


function Base.unsafe_read(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt)
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
    eof(fd) && throw(EOFError())
    @assert bytesavailable(fd.read_buffer) > 0
    Base.read(fd.read_buffer, UInt8)
end


Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(fd, buf, UInt(nbytes); kw...)

function Base.readbytes!(fd::UnixFD, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true)
    lb = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 2, nbytes)
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
    n = GC.@preserve buf UnixIO.read(fd, pointer(buf), length(buf))
    resize!(buf, n)
end


function Base.unsafe_write(fd::UnixFD, buf::Ptr{UInt8}, nbytes::UInt)
    nwritten = 0
    while nwritten < nbytes
        n = UnixIO.write(fd, buf + nwritten, nbytes - nwritten)
        if n == -1
            throw(fd_error(fd, :write))
        end
        nwritten += n
    end
    return Int(nwritten)
end



end # module UnixIO
