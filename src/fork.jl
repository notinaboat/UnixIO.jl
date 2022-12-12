"""
    fork_and_exec(cmd, in, out, err) -> pid

Run `cmd` using `fork` and `execv`.
Connect child process (STDIN, STDOUT, STDERR) to (`in`, `out`, `err`).
"""
@db function fork_and_exec(cmd::Cmd, infd::RawFD, outfd::RawFD, errfd::RawFD;
                           env=nothing)
    @nospecialize

    GC.@preserve cmd begin

        # Find path to binary.
        cmd_bin = find_cmd_bin(cmd)

        # Prepare arguments for `C.execv`.
        args = [pointer.(cmd.exec); Ptr{UInt8}(0)]

        # Mask all signals.
        oldmask = Ref{C.sigset_t}()
        newmask = Ref{C.sigset_t}()
        C.sigfillset(newmask)
        C.pthread_sigmask(C.SIG_SETMASK, newmask, oldmask);

        # Start Child Process ─────────────────────╮
        #                                          ▼
        pid = C.fork();                  if pid == 0

                                             # Set Default Signal Handlers.
                                             for n in 1:31
                                                 C.signal(n, C.SIG_DFL)
                                             end

                                             # Clear Signal Mask.
                                             emptyset = Ref{C.sigset_t}()
                                             C.sigemptyset(emptyset)
                                             C.pthread_sigmask(C.SIG_SETMASK,
                                                               emptyset,
                                                               C_NULL);

                                             # Connect STDIN/OUT to socket.
                                             C.dup2(infd,  Base.STDIN_NO)
                                             C.dup2(outfd, Base.STDOUT_NO)
                                             C.dup2(errfd, Base.STDERR_NO)

                                             # Execute command.
                                             C.execv(cmd_bin, args)
                                             C._exit(-1)
                                         end

        # Restore old signal mask.
        C.pthread_sigmask(C.SIG_SETMASK, oldmask, C_NULL);

        @assert pid > 0

        @db return pid
    end
end
