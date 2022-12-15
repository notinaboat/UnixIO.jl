"""
    posix_spawn(cmd, in, out, err; [env=ENV]) -> pid

Run `cmd` using `posix_spawn`.
Connect child process (STDIN, STDOUT, STDERR) to (`in`, `out`, `err`).
See [posix_spawn(3)](https://man7.org/linux/man-pages/man3/posix_spawn.3.html).
"""
@db 3 function posix_spawn(cmd::Cmd, infd::Union{String,RawFD},
                                     outfd::Union{String,RawFD,Nothing}=nothing,
                                     errfd::Union{String,RawFD,Nothing}=nothing;
                                     env=nothing)
    @nospecialize

    # Find path to binary.
    cmd_bin = find_cmd_bin(cmd)

    # Prepare NULL-terminated vector of Argument Pointers.
    argv = [pointer.(cmd.exec); Ptr{UInt8}(0)]

    # Prepare NULL-terminated vector of Environment Variables.
    if env != nothing
        env_vector = ["$k=$v" for (k, v) in env]
    else
        env_vector = String[]
        i = 0
        while (s = @ccall jl_environ(i::Int32)::Any) != nothing
            push!(env_vector, s)
            i += 1
        end
    end
    envp = [pointer.(env_vector); Ptr{UInt8}(0)]

    # Allocate Attribute and File Action structs (destoryed in `finally`).
    pid = Ref{C.pid_t}()
    @assert C.posix_spawnattr_t == Ptr{Cvoid} ||
            sizeof(C.posix_spawnattr_t) == C.posix_spawnattr_t_size
    attr = Ref{C.posix_spawnattr_t}()
    @assert C.posix_spawn_file_actions_t == Ptr{Cvoid} ||
            sizeof(C.posix_spawn_file_actions_t) ==
                   C.posix_spawn_file_actions_t_size
    actions = Ref(C.posix_spawn_file_actions_t())
    @cerr0 C.posix_spawnattr_init(attr)
    @cerr0 C.posix_spawn_file_actions_init(actions)
    try
        # Set flags.
        @cerr0 C.posix_spawnattr_setflags(attr, C.POSIX_SPAWN_SETSIGDEF |
                                                C.POSIX_SPAWN_SETSIGMASK |
                                                C.POSIX_SPAWN_SETSID )

        # Set all signals to default behaviour.
        @assert C.sigset_t == Cuint ||
                sizeof(C.sigset_t) == C.__sigset_t_size
        sigset = Ref{C.sigset_t}()
        @cerr0 C.sigfillset(sigset)
        @cerr0 C.sigdelset(sigset, C.SIGKILL)
        @cerr0 C.sigdelset(sigset, C.SIGSTOP)
        @cerr0 C.posix_spawnattr_setsigdefault(attr, sigset)

        # Un-mask all signals.
        emptyset = Ref{C.sigset_t}()
        @cerr0 C.sigemptyset(emptyset)
        @cerr0 C.posix_spawnattr_setsigmask(attr, emptyset)

        # Connect Child Process STDIN/OUT to socket.
        previous_stdno=-1
        for (fd, stdno) in ( infd => Base.STDIN_NO,
                            outfd => Base.STDOUT_NO,
                            errfd => Base.STDERR_NO)
            if fd isa String
                @db 4 "addopen($stdno, $fd)"
                @cerr C.posix_spawn_file_actions_addopen(
                    actions, stdno, fd, C.O_RDWR, 0)
            else
                @db 4 "adddup2($stdno, $fd, $stdno)"
                @cerr0 C.posix_spawn_file_actions_adddup2(
                    actions, something(fd, previous_stdno), stdno)
                previous_stdno = stdno
            end
        end

        # Start the Child Process
        GC.@preserve cmd env_vector begin
            @cerr0 C.posix_spawn(pid, cmd_bin, actions, attr, argv, envp)
        end
        @assert pid[] > 0

        @db 3 return pid[]

    finally
        @cerr0 C.posix_spawn_file_actions_destroy(actions)
        @cerr0 C.posix_spawnattr_destroy(attr)
    end
end
