module UnixIOHeaders

open(pathname::AbstractString, flags) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint

open(pathname::AbstractString, flags, mode) =
    @ccall open(pathname::Cstring, flags::Cint, mode::Cint)::Cint

close(fd) = @ccall close(fd::Cint)::Cint

system(command) = @ccall system(command::Cstring)::Cint

using CInclude

#@cinclude "pthread.h"    quiet
@cinclude "errno.h"      quiet
@cinclude "termios.h"    quiet
@cinclude "fcntl.h"      quiet
@cinclude "poll.h"       quiet
@cinclude "unistd.h"     quiet
@cinclude "sys/socket.h" quiet



end # module
