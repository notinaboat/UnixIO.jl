README"## Executing Unix Commands."

@doc README"""
### `sh"cmd"` -- Shell command string.

    sh"shell command"

String containing result of shell command. e.g.

    julia> println("Machine is ", sh"uname -m")
    Machine is x86_64

    julia> println("V: ", sh"grep version Project.toml | awk '{print\$3}'")
    V: "0.1.0"
"""
macro sh_str(s)
    @assert false "not tested?"
    s = Meta.parse("\"$s\"")
    cmd = `bash -c "$s"`
    esc(:($cmd |> read |> String |> chomp))
end

@doc README"""
### `UnixIO.system` -- Run a shell command.

    UnixIO.system(command) -> exit status

See [system(3)](https://man7.org/linux/man-pages/man3/system.3.html)

e.g.
```
julia> UnixIO.system("uname -srm")
Darwin 20.3.0 x86_64
```
"""
@db function system(command)
    r = @cerr gc_safe_system(command)
    if r != 0
        throw(ErrorException("UnixIO.system termination status: $r"))
    end
    @db return r
end

system(cmd::Cmd) = system(join(cmd.exec, " "))

gc_safe_system(c) = @gc_safe C.system(c)



@doc README"""
### `UnixIO.open(::Cmd) do...` -- Communicate with a sub-process.

    UnixIO.open(f, cmd::Cmd; [check_status=true, capture_stderr=false])

Run `cmd` using `posix_spawn`.

Call `f(cmdin, cmdout)`
with (STDIN, STDOUT) of `cmd` connected to (`cmdin`, `cmdout`).

If `capture_stderr` is `true` STDERR of `cmd` is merged into `cmdout`.

If `check_status` is `true` an exception is thrown on non-zero exit status.

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
"""
@db function open(f, cmd::Cmd; capture_stderr=false, env=nothing, fork=false, kw...)
    process = socketpair_spawn(cmd; env, capture_stderr, fork)
    run_cmd_function(f, cmd, process; kw...)
end


@doc README"""
### `UnixIO.ptopen(::Cmd) do...` -- Run a sub-process in a pseudoterminal.

    UnixIO.ptopen(f, cmd::Cmd; [env=ENV, check_status=true])

Run `cmd` using `posix_spawn`.

Call `f(cmdin, cmdout)` with (STDIN, STDOUT and STDERR) of `cmd`
connected to (`cmdin`, `cmdout`) via a pseudoterminal.

If `check_status` is `true` an exception is thrown on non-zero exit status.

Run `cmd` using `posix_spawn`.
"""
@db function ptopen(f, cmd::Cmd; env=nothing, kw...)
    process = pseudoterminal_spawn(cmd; env)
    run_cmd_function(f, cmd, process; kw...)
end


@db 1 function run_cmd_function(f, cmd, p; check_status=true)
    @nospecialize

    # Run the IO handling function `f`.
    try                                         ;@db 1 "f ┬─($(p.in),$(p.out))"
                                                ;@db_indent 1 "f"
        result = f(p.in, p.out)                 ;@db_unindent 1
        close(p.in)                             ;@db 1 "  └─▶ 👍"
        close(p.out)

        # If cmd is still running try to kill it softly.
        if isalive(check(p))
            C.kill(p, C.SIGHUP)                           ;@db 3 "SIGHUP -> $p"
            wait(p; timeout=5.0)
            sent_sighup = true
        else
            sent_sighup = false
        end

        if !check_status
            @db 1 return p, result
        elseif (didexit(check(p)) && p.exit_status == 0) || sent_sighup
            @db 1 return result
        else
            throw(ProcessFailedException(p, cmd))
        end
    finally
        kill(p)
    end
end


function open(cmd::Cmd; kw...)
    c = Channel{Tuple{FD{Out},FD{In}}}(0)
    @asynclog "UnixIO.open(::Cmd)" open(cmd; kw...) do cmdin, cmdout
        put!(c, (cmdin, cmdout))
        @sync begin
            @async Base.wait_close(cmdin)
            @async Base.wait_close(cmdout)
        end
    end
    take!(c)
end


@doc README"""
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
"""
@db function read(cmd::Cmd, ::Type{String}; kw...)
    r = String(read(cmd; kw...))
    @db return r
end

@db function read(cmd::Cmd; timeout=Inf, kw...)
    r = open(cmd; kw...) do cmdin, cmdout
        shutdown(cmdin)
        readall!(cmdout; timeout)
    end
    @db return r
end


function find_cmd_bin(cmd::Cmd)
    bin = Base.Sys.which(cmd.exec[1])
    bin != nothing || throw(ArgumentError("Command not found: $(cmd.exec[1])"))
    bin
end


@db 3 function pseudoterminal_spawn(cmd; kw...)

    # Create a Pseudoterminal to communicate with Child Process STDIN/OUT.
    parent_in, parent_out, devpath = openpt()
    cmdin = parent_out
    cmdout = parent_in

    pid = spawn_process(cmd, devpath; kw...)

    process = Process(pid, cmdin, cmdout)
    set_extra(cmdout, :pt_client, process)
    return process
end


@db 3 function socketpair_spawn(cmd; capture_stderr=false, kw...)

    # Create a Unix Domain Socket to communicate with Child Process STDIN/OUT.
    parent_io, child_io = socketpair()
    cmdin = FD{Out}(parent_io)
    cmdout = FD{In}(C.dup(parent_io))
    @db 3 "dup($parent_io) -> $(cmdout.fd)"

    # Merge STDERR into STDOUT?
    # or leave connected to Parent Process STDERR?
    child_err = capture_stderr ? child_io : RawFD(Base.STDERR_NO)

    pid = spawn_process(cmd, child_io, child_io, child_err; kw...)

    # Close the child end of the socketpair.
    C.close(child_io)

    return Process(pid, cmdin, cmdout)
end


@db 3 function spawn_process(cmd, infd, outfd=infd, errfd=outfd; fork=false, kw...)
    if fork
        fork_and_exec(cmd, infd, outfd, errfd; kw...)
    else
        posix_spawn(cmd, infd, outfd, errfd; kw...)
    end
end
