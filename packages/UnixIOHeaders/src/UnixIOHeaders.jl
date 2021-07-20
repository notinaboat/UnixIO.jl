baremodule UnixIOHeaders

import Base
using Base:@ccall, Cstring, Cint, Sys, Vector

const __spawn_action = Cvoid

using CInclude

@cinclude([
    "<errno.h>",
    "<pthread.h>",
    "<termios.h>",
    "<fcntl.h>",
    "<poll.h>",
    (Sys.islinux() ? ("<sys/epoll.h>",) : ())...,
    "<unistd.h>",
    "<sys/stat.h>",
    "<sys/socket.h>",
    "<signal.h>",
    "<sys/wait.h>",
    "<spawn.h>"],

    quiet,

    exclude=r"""
        sv_onstack
      | sched_priority | sigcontext_struct
      | ru_first | ru_last 
      | MACH_MSG_TYPE_INTEGER_T | msgh_reserved | msgh_kind | mach_msg_kind_t
    """x
    )


# Need Ptr{Ptr{UInt8}} not Ptr{String} for NULL-terminated string vectors:
execv(path, args::Vector{Ptr{UInt8}}) =
    @ccall execv(path::Ptr{UInt8}, args::Ptr{Ptr{UInt8}})::Cint

posix_spawn(pid, path, file_actions, attrp, argv::Vector{Ptr{UInt8}},
                                            envp::Vector{Ptr{UInt8}}) =
    @ccall posix_spawn(pid::Ptr{pid_t},
                       path::Cstring, 
                       file_actions::Ptr{posix_spawn_file_actions_t}, 
                       attrp::Ptr{posix_spawnattr_t},
                       argv::Ptr{Ptr{UInt8}},
                       envp::Ptr{Ptr{UInt8}})::Cint


# Signal wrongly wrapped as 3-args by CInclude.jl.
if Sys.isapple()
    signal(sig, func) = @ccall signal(sig::Cint, func::sig_t)::sig_t
end
const SIG_DFL = sig_t(0)


# Multiple methods for `open` and `fcntl`:
open(pathname::AbstractString, flags) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint

open(pathname::AbstractString, flags, mode) =
    @ccall open(pathname::Cstring, flags::Cint, mode::Cint)::Cint

fcntl(fd, cmd) = @ccall fcntl(fd::Cint, cmd::Cint)::Cint
fcntl(fd, cmd, arg) = @ccall fcntl(fd::Cint, cmd::Cint, arg::Cint)::Cint


# Need `Cstring` argumnet for `system`.
system(command) = @ccall system(command::Cstring)::Cint



end # module
