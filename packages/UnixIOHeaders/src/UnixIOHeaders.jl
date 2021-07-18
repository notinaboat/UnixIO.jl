baremodule UnixIOHeaders

import Base
using Base:@ccall, Cstring, Cint, Sys

open(pathname::AbstractString, flags) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint

open(pathname::AbstractString, flags, mode) =
    @ccall open(pathname::Cstring, flags::Cint, mode::Cint)::Cint

fcntl(fd, cmd) = @ccall fcntl(fd::Cint, cmd::Cint)::Cint
fcntl(fd, cmd, arg) = @ccall fcntl(fd::Cint, cmd::Cint, arg::Cint)::Cint

system(command) = @ccall system(command::Cstring)::Cint

execv(path, args) = @ccall execv(path::Ptr{UInt8}, args::Ptr{Ptr{UInt8}})::Cint


using CInclude

@cinclude([
    "errno.h",
    "pthread.h",
    "termios.h",
    "fcntl.h",
    "poll.h",
    (Sys.islinux() ? ("sys/epoll.h") : ())...,
    "unistd.h",
    "sys/stat.h",
    "sys/socket.h",
    "signal.h",
    "sys/wait.h"],
    quiet,
    exclude=r"sv_onstack|ru_first|ru_last"
    )

end # module
