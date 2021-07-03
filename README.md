# UnixIO.jl

Unix IO Interface.


## Opening and Closing File Descriptors


```
open(pathname, [flags = JL_O_RDWR]; [yield=true]) -> UnixFD
```

Open the file specified by pathname. See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)


```
close(stream)
```

Close an I/O stream. Performs a [`flush`](@ref) first.

```
close(c::Channel[, excp::Exception])
```

Close a channel. An exception (optionally given by `excp`), is thrown by:

  * [`put!`](@ref) on a closed channel.
  * [`take!`](@ref) and [`fetch`](@ref) on an empty, closed channel.

```
close(fd::UnixFD)
```

Close a file descriptor, so that it no longer refers to any file and may be reused. See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)


## Reading and Writing File Descriptors


```
read(fd, buf, count; [yield=true]) -> number of bytes read
```

Attempt to read up to count bytes from file descriptor `fd` into the buffer starting at `buf`. See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)


```
write(fd, buf, count; [yield=true]) -> number of bytes written
```

Write up to count bytes from `buf` to the file referred to by the file descriptor `fd`. See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)


## Unix Domain Sockets


```
socketpair() -> fd1, fd2
```

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`). See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)


```
shutdown(sockfd, how)
```

Shut down part of a full-duplex connection. See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)


## Executing Unix Commands.


```
system(command) -> exit status
```

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)


```
open(f, cmd::Cmd; [check_status=true, capture_stderr=false])
```

Run `cmd` using `fork` and `execv`. Call `f(fd)` where `fd` is a socket connected to stdin/stdout of `cmd`.


```
read(fd, buf, count; [yield=true]) -> number of bytes read
```

Attempt to read up to count bytes from file descriptor `fd` into the buffer starting at `buf`. See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)

```
read(cmd::Cmd, String; [check_status=true, capture_stderr=false]) -> String
read(cmd::Cmd; [check_status=true, capture_stderr=false]) -> Vector{UInt8}
```

Run `cmd` using `fork` and `execv`. Return byes written to stdout by `cmd`.


```
waitpid(pid) -> status
```

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)

