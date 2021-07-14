# UnixIO.jl

Unix IO Interface.

For Julia programs that need to interact with Unix-specific IO interfaces.

e.g. Character devices, Terminals, Unix domain sockets, Block devices etc.

```
using UnixIO
const C = UnixIO.C

UnixIO.read(`curl https://julialang.org`, String; timeout=5)

io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)
readline(io; timeout=5)

fd = C.open("file.txt", C.O_CREAT | C.O_WRONLY)
C.write(fd, "Hello!", 7)
C.close(fd)

io = UnixIO.open("file.txt", C.O_CREAT | C.O_WRONLY)
write(io, "Hello!")
close(io)
```

Blocking IO is multiplexed by running [`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html) under a task started by `Threads.@spawn`. See [`src/poll.jl`](src/poll.jl)

If `UnixIO.enable_dumb_polling[]` is set to `true` IO polling is done by a dumb loop with a 10ms delay. This may be more efficient for small systems with simple IO requirements (e.g. communicating with a few serial ports and sub-processes on a Raspberry Pi).


## Opening and Closing Unix Files.

    UnixIO.open(pathname, [flags = C.O_RDWR]; [timeout=Inf]) -> UnixFD <: IO

Open the file specified by pathname.

The `UnixFD` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)


---

    UnixIO.set_timeout(fd::UnixFD, timeout)

Configure `fd` to throw `UnixIO.ReadTimeoutError` when read operations take
longer than `timeout` seconds.


---

    UnixIO.fcntl_setfl(fd::UnixFD, flag)

Set `flag` in the file status flags.
Uses `F_GETFL` to read the current flags and `F_SETFL` to store the new flag.
See [fcntl(2)](https://man7.org/linux/man-pages/man2/fcntl.2.html).


---

    UnixIO.tcsetattr(tty::UnixFD;
                     [iflag=0], [oflag=0], [cflag=C.CS8], [lflag=0], [speed=0])

Set terminal device options.

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)


---

    UnixIO.close(fd::UnixFD)

Close a file descriptor, so that it no longer refers to
any file and may be reused.
See [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)


    UnixIO.shutdown(sockfd, [how = C.SHUT_WR])

Shut down part of a full-duplex connection.
`how` is one of `C.SHUT_RD`, `C.SHUT_WR` or `C.SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)


## Reading from Unix Files.

    UnixIO.read(fd, buf, [count=length(buf)];
                [timeout=Inf] ) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)

Throw `UnixIO.ReadTimeoutError` if read takes longer than `timeout` seconds.


## Writing to Unix Files.

    UnixIO.write(fd, buf, [count=length(buf)];
                 [timeout=Inf] ) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)

Throw `UnixIO.WriteTimeoutError` if write takes longer than `timeout` seconds.


    UnixIO.println(x...)
    UnixIO.printerr(x...)

Write directly to `STDOUT` or `STDERR`.
Does not yield control from the current task.


## Unix Domain Sockets.

    socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)


## Executing Unix Commands.

    UnixIO.system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)

e.g.
```
julia> UnixIO.system("uname -srm")
Darwin 20.3.0 x86_64
```


---

    open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `fork` and `execv`.
Call `f(fd)` where `fd` is a socket connected to stdin/stdout of `cmd`.

e.g.
```
julia> UnixIO.open(`hexdump -C`) do io
           write(io, "Hello World!")
           shutdown(io)
           read(io, String)
       end |> println
00000000  48 65 6c 6c 6f 20 57 6f  72 6c 64 21              |Hello World!|
0000000c
```


---

    read(cmd::Cmd; [timeout=Inf,
                    check_status=true,
                    capture_stderr=false]) -> Vector{UInt8}
    read(cmd::Cmd, String; kw...) -> String

Run `cmd` using `fork` and `execv`.
Return byes written to stdout by `cmd`.

e.g.
```
julia> UnixIO.read(`uname -srm`, String)
"Darwin 20.3.0 x86_64\n"
```


---

    UnixIO.waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)



