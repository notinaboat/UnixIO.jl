module UnixIOHeaders

open(pathname::AbstractString, flags) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint

open(pathname::AbstractString, flags, mode) =
    @ccall open(pathname::Cstring, flags::Cint, mode::Cint)::Cint

fcntl(fd, cmd) = @ccall fcntl(fd::Cint, cmd::Cint)::Cint
fcntl(fd, cmd, arg) = @ccall fcntl(fd::Cint, cmd::Cint, arg::Cint)::Cint

close(fd) = @ccall close(fd::Cint)::Cint

system(command) = @ccall system(command::Cstring)::Cint

execv(path, args) = @ccall execv(path::Ptr{UInt8}, args::Ptr{Ptr{UInt8}})::Cint

using CInclude

#@cinclude "pthread.h"    quiet
@cinclude "errno.h"      quiet
@cinclude "termios.h"    quiet
@cinclude "fcntl.h"      quiet
@cinclude "poll.h"       quiet
@cinclude "sys/epoll.h"  quiet
@cinclude "unistd.h"     quiet
@cinclude "sys/socket.h" quiet
@cinclude "signal.h"     quiet exclude=r"^_|sigcontext_struct|sv_onstack"
@cinclude "sys/wait.h"   quiet exclude=r"^_|ru_first|ru_last|sigcontext_struct|sv_onstack"



end # module
