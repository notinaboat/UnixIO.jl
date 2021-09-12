baremodule UnixIOHeaders

import Base
using Base:@ccall, Cstring, Cint, Sys, Vector, signed, (&), (+), (>>), (>), (==)

const __spawn_action = Cvoid

ioctl(fd, cmd, arg) = @ccall ioctl(fd::Cint, cmd::Cint, arg::Ptr{Cint})::Cint


using CInclude

@cinclude([
    "<errno.h>",
    "<string.h>",
    "<limits.h>",
    "<stdlib.h>",
    "<pthread.h>",
    "<sys/ioctl.h>",
    "<termios.h>",
    "<fcntl.h>",
    "<poll.h>",
    (Sys.islinux() ? ("<sys/epoll.h>",) : ())...,
    "<unistd.h>",
    "<sys/stat.h>",
    "<sys/socket.h>",
    "<signal.h>",
    "<sys/wait.h>",
    "<sys/syscall.h>",
    "<spawn.h>"],

    args = ["-D_GNU_SOURCE"],

    quiet,

    exclude=r"""
        sv_onstack
      | sched_priority | sigcontext_struct
      | ru_first | ru_last 
      | NR_OPEN | ARG_MAX | LINK_MAX
      | MACH_MSG_TYPE_INTEGER_T | msgh_reserved | msgh_kind | mach_msg_kind_t
      | ^SIOC | TC[SG]ETS[FW]?2
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


# Need multiple methods for `open` and `fcntl`:
open(pathname::AbstractString, flags) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint

open(pathname::AbstractString, flags, mode) =
    @ccall open(pathname::Cstring, flags::Cint, mode::Cint)::Cint

fcntl(fd, cmd) = @ccall fcntl(fd::Cint, cmd::Cint)::Cint
fcntl(fd, cmd, arg) = @ccall fcntl(fd::Cint, cmd::Cint, arg::Cint)::Cint


# Need variants for _m struct
tcsetattr_m(fd, action, p) =
    @ccall tcsetattr(fd::Cint, action::Cint, p::Ptr{termios_m})::Cint

tcgetattr_m(fd, p) =
    @ccall tcgetattr(fd::Cint, p::Ptr{termios_m})::Cint

cfsetspeed_m(p, speed) =
    @ccall cfsetspeed(p::Ptr{termios_m}, speed::speed_t)::Cint


# Not yet in glibc.
const SYS_pidfd_open=434 # https://git.io/J4j1A
pidfd_open(pid, flags) = @ccall syscall(SYS_pidfd_open::Cint,
                                        pid::pid_t, flags::Cint)::Cint

const P_PIDFD = 3
waitid(idtype, id, infop, options) = 
    @ccall syscall(SYS_waitid::Cint,
                   idtype::Cint,
                   id::id_t,
                   infop::Ptr{siginfo_t},
                   options::Cint,
                   Base.C_NULL::Ptr{Cvoid})::Cint


# Function-like mactos not yet wrapped.
WIFSIGNALED(x) = (((x & 0x7f) + 1) >> 1) > 0
WTERMSIG(x) = (x & 0x7f)
WIFEXITED(x) = WTERMSIG(x) == 0
WEXITSTATUS(x) = signed(UInt8((x >> 8) & 0xff))
WIFSTOPPED(x) = (x & 0xff) == 0x7f
WSTOPSIG(x) = WEXITSTATUS(x)
WIFCONTINUED(x) = x == 0xffff
WCOREDUMP(x) = x & 0x80



end # module
