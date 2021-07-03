# UnixIO.jl

Unix IO Interface.


## Interface


```
open(pathname, flags; [yield=true]) -> file descriptor
```

Open the file specified by pathname. See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)

```
open(f, cmd::Cmd; [check_status=true, capture_stderr=false])
```

Run `cmd` using `fork` and `execv`. Call `f(fd)` where `fd` is a socket connected to stdin/stdout of `cmd`.


```
close(fd)
```

Close a file descriptor, so that it no longer refers to any file and may be reused. See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)


```
read(fd, buf, count; [yield=true]) -> number of bytes read
```

Attempts to read up to count bytes from file descriptor `fd` into the buffer starting at `buf`. See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)

```
read(fd, v::Vector{UInt8}) -> number of bytes read
```

Read bytes from `fd` into `v`.

```
read(fd) -> Vector{UInt8}
read(fd, String) -> String
```

Read bytes from `fd` into a new Vector or String.

```
read(cmd::Cmd, String; [check_status=true, capture_stderr=false]) -> String
read(cmd::Cmd; [check_status=true, capture_stderr=false]) -> Vector{UInt8}
```

Run `cmd` using `fork` and `execv`. Return byes written to stdout by `cmd`.


```
write(fd, buf, count; [yield=true]) -> number of bytes written
```

Write up to count bytes from `buf` to the file referred to by the file descriptor `fd`. See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)

```
write(fd, s::String; [yield=true]) -> number of bytes written
write(fd, v::Vector{UInt8}; [yield=true]) -> number of bytes written
```

Read bytes to `fd` from a Vector or String.


```
socketpair() -> fd1, fd2
```

Create a pair of connected Unix Domain Sockets (AF*UNIX, SOCK*STREAM). See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)


```
shutdown(sockfd, how)
```

Shut down part of a full-duplex connection. See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)

