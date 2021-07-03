"""
# UnixIO.jl

Unix IO Interface.
"""
module UnixIO


const STDIN = Base.STDIN_NO
const STDOUT = Base.STDOUT_NO
const STDERR = Base.STDERR_NO


# Opening and Closing Unix Files.


using Base.Filesystem:
JL_O_APPEND,  JL_O_NOCTTY,  JL_O_RDWR,         
JL_O_CREAT,   JL_O_TRUNC,
JL_O_EXCL,    JL_O_RDONLY,  JL_O_WRONLY


"""
    open(pathname, flags; [yield=true]) -> file descriptor

Open the file specified by pathname.
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
"""
function open(pathname, flags; yield=true)
    if yield
        @threadcall(:open, Cint, (Cstring, Cint), pathname, flags)
    else
        @ccall open(pathname::Cstring, flags::Cint)::Cint
    end
end


"""
    close(fd)

Close a file descriptor, so that it no longer refers to
any file and may be reused.
See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)
"""
close(fd) = @ccall close(fd::Cint)::Cint



# Reading from Unix Files.


"""
    read(fd, buf, count; [yield=true]) -> number of bytes read

Attempts to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
"""
function read(fd, buf, count; yield=true)
    if yield
        @threadcall(:read, Cint, (Cint, Ptr{Cvoid}, Csize_t), fd, buf, count)
    else
        @ccall read(fd::Cint, buf::Ptr{Cvoid}, count::Csize_t)::Cint
    end
end


"""
    read(fd, v::Vector{UInt8}) -> number of bytes read

Read bytes from `fd` into `v`.
"""
read(fd, v) = read(fd, v, sizeof(v))


"""
    read(fd) -> Vector{UInt8}
    read(fd, String) -> String

Read bytes from `fd` into a new Vector or String.
"""
function read(fd)
    buf = Vector{UInt8}(undef,1024)
    n = read(fd, buf)
    buf[1:n]
end

read(fd, ::Type{String}) = String(read(fd))



# Writing to Unix Files.


"""
    write(fd, buf, count; [yield=true]) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)
"""
function write(fd, buf, count; yield=true)
    if yield
        @threadcall(:write, Csize_t, (Cint, Ptr{Cvoid}, Csize_t), fd, buf, count)
    else
        @ccall write(fd::Csize_t, buf::Ptr{Cvoid}, count::Csize_t)::Cint
    end
end

"""
    write(fd, s::String; [yield=true]) -> number of bytes written
    write(fd, v::Vector{UInt8}; [yield=true]) -> number of bytes written

Read bytes to `fd` from a Vector or String.
"""
write(fd, s::AbstractString; kw...) = write(fd, codeunits(s); kw...)

write(fd, v::AbstractVector{UInt8}; kw...) = write(fd, v, length(v); kw...)



# Unix Domain Sockets.


const AF_UNIX = 1
const SOCK_STREAM = 1

"""
    socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (AF_UNIX, SOCK_STREAM).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)
"""
function socketpair()
    v = fill(Cint(-1), 2)
    r = ccall(:socketpair, Cint, (Cint, Cint, Cint, Ptr{Cint}),
                                   AF_UNIX, SOCK_STREAM, 0, v)
    if r == -1
        throw(Base.SystemError("waitpid($pid) failed", Base.Libc.errno()))
    end
    (v[1], v[2])
end

const SHUT_RD = 0
const SHUT_WR = 1
const SHUT_RDWR = 2

"""
    shutdown(sockfd, how)

Shut down part of a full-duplex connection.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
"""
shutdown(sockfd, how) = @ccall shutdown(sockfd::Cint, how::Cint)::Cint



# Executing Unix Commands.

"""
    system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)
"""
system(command) = @threadcall(:system, Cint, (Cstring,), command)


WIFSIGNALED(x) = (((x & 0x7f) + 1) >> 1) > 0
WTERMSIG(x) = (x & 0x7f)
WIFEXITED(x) = WTERMSIG(x) == 0
WEXITSTATUS(x) = signed(UInt8((x >> 8) & 0xff))
WIFSTOPPED(x) = (x & 0xff) == 0x7f
WSTOPSIG(x) = WEXITSTATUS(x)


"""
    waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)
"""
function waitpid(pid)
    status = Ref{Cint}(0)
    r = @ccall waitpid(pid::Cint, status::Ptr{Cint}, 0::Cint)::Cint
    if r == -1
        throw(Base.SystemError("waitpid($pid) failed", Base.Libc.errno()))
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


"""
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
    try
        f(parent_io)
    finally
        close(parent_io)
        status = waitpid(pid)
    end
    if check_status
        if !WIFEXITED(status) || WEXITSTATUS(status) != 0
            throw(waitpid_error(cmd, status))
        end
    end
    return status
end


"""
    read(cmd::Cmd, String; [check_status=true, capture_stderr=false]) -> String
    read(cmd::Cmd; [check_status=true, capture_stderr=false]) -> Vector{UInt8}

Run `cmd` using `fork` and `execv`.
Return byes written to stdout by `cmd`.
"""
function read(cmd::Cmd; kw...)
    result = IOBuffer()
    open(cmd; kw...) do io
        shutdown(io, SHUT_WR)
        buf = Vector{UInt8}(undef, 4096)
        n = 1
        while n > 0
            n = read(io, buf)
            Base.write(result, view(buf, 1:n))
        end
    end
    take!(result)
end

read(cmd::Cmd, ::Type{String}; kw...) = String(read(cmd; kw...))



# Documentation.

readme() = join([
    Docs.doc(@__MODULE__),
    "## Interface\n",
    (Docs.@doc open),
    (Docs.@doc close),
    (Docs.@doc read),
    (Docs.@doc write),
    (Docs.@doc socketpair),
    (Docs.@doc shutdown)
    ], "\n\n")



end # module
