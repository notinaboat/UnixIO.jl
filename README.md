# UnixIO.jl

Unix IO Interface.


## Opening and Closing File Descriptors


```
open(pathname, flags; [yield=true]) -> file descriptor
```

Open the file specified by pathname. See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)


```
close(fd)
```

Close a file descriptor, so that it no longer refers to any file and may be reused. See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)


## Reading and Writing File Descriptors


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
write(fd, buf, count; [yield=true]) -> number of bytes written
```

Write up to count bytes from `buf` to the file referred to by the file descriptor `fd`. See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)

```
write(fd, s::String; [yield=true]) -> number of bytes written
write(fd, v::Vector{UInt8}; [yield=true]) -> number of bytes written
```

Read bytes to `fd` from a Vector or String.


## Unix Domain Sockets


```
socketpair() -> fd1, fd2
```

Create a pair of connected Unix Domain Sockets (AF*UNIX, SOCK*STREAM). See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)


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
open(pathname, flags; [yield=true]) -> file descriptor
```

Open the file specified by pathname. See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)


```
read(fd) -> Vector{UInt8}
read(fd, String) -> String
```

Read bytes from `fd` into a new Vector or String.


```
waitpid(pid) -> status
```

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)

