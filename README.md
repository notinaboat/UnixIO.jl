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

fd = C.open("file.txt", C.O_CREAT | C.O_WRONLY, 0o644)
C.write(fd, pointer("Hello!"), 7)
C.close(fd)

io = UnixIO.open("file.txt", C.O_CREAT | C.O_WRONLY)
write(io, "Hello!")
close(io)
```

Blocking IO is multiplexed by running [`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html) under a task started by `Threads.@spawn`. See [`src/poll.jl`](src/poll.jl)

If `ENV["JULIA_IO_EVENT_SOURCE"]` is set to `epoll` the Linux [`epoll(7)`](https://man7.org/linux/man-pages/man7/epoll.7.html) API is used instead.

If `ENV["JULIA_IO_EVENT_SOURCE"]` is set to `sleep` IO polling is done by a dumb loop with a 10ms delay. This may be more efficient for small systems with simple IO requirements. (e.g. communicating with a few serial ports and sub-processes on a Raspberry Pi).


## Opening and Closing Unix Files.

### `UnixIO.open` -- Open Files.

    UnixIO.open(pathname, [flags = C.O_RDWR, [mode = 0o644]];
                          [timeout=Inf]) -> IO

Open the file specified by pathname.

Use `Base.close` to close the file.

The `IO` returned by `UnixIO.open` can be used with
`UnixIO.read` and `UnixIO.write`. It can also be used with
the standard `Base.IO` functions
(`Base.read`, `Base.write`, `Base.readbytes!`, `Base.close` etc).
See [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)


### `UnixIO.set_timeout` -- Configure Timeouts.

    UnixIO.set_timeout(fd::UnixFD, timeout)

Configure `fd` to limit IO operations to `timeout` seconds.


### `UnixIO.tcsetattr` -- Configure Terminals and Serial Ports.

    UnixIO.tcsetattr(tty::UnixFD;
                     [iflag=0], [oflag=0], [cflag=C.CS8], [lflag=0], [speed=0])

Set terminal device options.

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io; speed=9600, lflag=C.ICANON)


### `UnixIO.shutdown` -- Signal end of transmission or reception.

    UnixIO.shutdown(sockfd, how)

Shut down part of a full-duplex connection.
`how` is one of `C.SHUT_RD`, `C.SHUT_WR` or `C.SHUT_RDWR`.
See [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)


## Reading from Unix Files.

### `UnixIO.read` -- Read bytes into a buffer.

    UnixIO.read(fd, buf, [count=length(buf)];
                [timeout=Inf] ) -> number of bytes read

Attempt to read up to count bytes from file descriptor `fd`
into the buffer starting at `buf`.
See [read(2)](https://man7.org/linux/man-pages/man2/read.2.html)


## Writing to Unix Files.

### `UnixIO.write` -- Write bytes from a buffer.

    UnixIO.write(fd, buf, [count=length(buf)];
                 [timeout=Inf] ) -> number of bytes written

Write up to count bytes from `buf` to the file referred to by
the file descriptor `fd`.
See [write(2)](https://man7.org/linux/man-pages/man2/write.2.html)


### `UnixIO.println` -- Write messages to the terminal.

    UnixIO.println(x...)
    UnixIO.printerr(x...)

Write directly to `STDOUT` or `STDERR`.
Does not yield control from the current task.


## Unix Domain Sockets.

### `UnixIO.socketpair()` -- Unix Domain Sockets for IPC.

    UnixIO.socketpair() -> fd1, fd2

Create a pair of connected Unix Domain Sockets (`AF_UNIX`, `SOCK_STREAM`).
See [socketpair(2)](https://man7.org/linux/man-pages/man2/socketpair.2.html)


## Executing Unix Commands.

### `sh"cmd"` -- Shell command string.

    sh"shell command"

String containing result of shell command. e.g.

    julia> println("Machine is ", sh"uname -m")
    Machine is x86_64

    julia> println("V: ", sh"grep version Project.toml | awk '{print\$3}'")
    V: "0.1.0"  


### `UnixIO.system` -- Run a shell command.

    UnixIO.system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)

e.g.
```
julia> UnixIO.system("uname -srm")
Darwin 20.3.0 x86_64
```


### `UnixIO.open(::Cmd) do...` -- Communicate with a sub-process.

    UnixIO.open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `posix_spawn`.
Connect (STDIN, STDOUT) to (`cmdin`, `cmdout`).
Call `f(cmdin, cmdout)`.

e.g.
```
julia> UnixIO.open(`hexdump -C`) do cmdin, cmdout
           write(cmdin, "Hello World!")
           close(cmdin)
           read(cmdout, String)
       end |> println
00000000  48 65 6c 6c 6f 20 57 6f  72 6c 64 21              |Hello World!|
0000000c
```


### `UnixIO.read(::Cmd)` -- Read sub-process output.

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


### `UnixIO.waitpid` -- Wait for a sub-process to terminate.

    UnixIO.waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)



