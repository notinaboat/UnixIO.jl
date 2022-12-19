# Unix Processes.

mutable struct Process
    pid::C.pid_t
    in::FD
    out::FD
    stopped::Bool
    code::Union{Nothing, Cint}
    exit_status::Union{Nothing, Cint}
    signal::Union{Nothing, Cint}
    cmd::Cmd
end

isstopped(p::Process) = p.stopped
isrunning(p::Process) = isalive(p) && !isstopped(p)
isalive(p::Process) = p.exit_status == nothing &&
                      (p.signal == nothing || p.stopped)
didexit(p::Process) = p.exit_status != nothing
waskilled(p::Process) = !isstopped(p) && p.signal != nothing

IOTraits.WaitAPI(::Type{Process}) = IOTraits.firstvalid(WaitAPI{:PidFD}(),
                                                        WaitAPI{:Sleep}())

@db function Base.wait(p::Process; timeout=Inf,
                                   deadline=timeout+time())
    if !isrunning(p)
        @db return p "Already stopped or terminated"
    end
    wait(p, WaitAPI(p); deadline)
    @ensure time() >= deadline || !isrunning(p)
    return p
end

check(p::Process) = wait(p; deadline=0.0)

Base.wait(p::Process, ::WaitAPI{:Sleep}; kw...) = waitpid(p; kw...)
Base.wait(p::Process, ::WaitAPI{:PidFD}; kw...)= waitpidfd(p; kw...)



# Sub Processes.

function Process(pid, infd, outfd; cmd=``)
    p = Process(pid, infd, outfd, false, nothing, nothing, nothing, cmd)
    @dblock processes_lock push!(processes, p)
    return p
end

Base.convert(::Type{C.pid_t}, p::Process) = p.pid


const processes_lock = Threads.SpinLock()
const processes = Set{Process}()


@doc README"""
### `UnixIO.waitpid` -- Wait for a sub-process to terminate.

    UnixIO.waitpid(pid) -> status

See [waitpid(3)](https://man7.org/linux/man-pages/man3/waitpid.3.html)
"""
@db function waitpid(p::Process; deadline::Float64=Inf)

    status = Ref{Cint}(0)
    delay = nothing

    while true
        r = C.waitpid(p.pid, status, C.WNOHANG | C.WUNTRACED)          ;@db 3 r
        if r == -1
            err = errno()
            if err == C.EINTR                                    ;@db 3 "EINTR"
                @db_not_tested :a
                continue
            elseif err == C.ECHILD
                @db_not_tested :b
                @db return nothing "ECHILD (No child process)"
            end
            systemerror(string("C.waitpid($(p.pid))"), err)
        end
        if r == p.pid
            s = status[]
            if C.WIFEXITED(s)
                p.exit_status = C.WEXITSTATUS(s)
            elseif C.WIFSTOPPED(s)
                p.stopped = true
                p.signal = WSTOPSIG(s)
                @db_not_tested :c
            elseif C.WIFCONTINUED(s)
                p.stopped = false
                p.signal = nothing
                @assert p.exit_status == nothing
                @db_not_tested :d
            elseif C.WIFSIGNALED(s)
                p.signal = C.WTERMSIG(s)
            else
                @error "Unhandedl termination status: $s" p
                @db_not_tested :f
            end
            if !p.stopped
                @dblock processes_lock delete!(processes, p)
            end
            @db return nothing "terminated"
        end
        if time() >= deadline
            @db return nothing "timeout!"
        end

        if delay == nothing
            delay = exponential_delay()
        end
        t = popfirst!(delay)                                 ;@db 3 "sleep($t)"
        sleep(t)
    end
end

exponential_delay() =
    Iterators.Stateful(ExponentialBackOff(n=typemax(Int); factor=2))



@db function waitpidfd(p::Process; deadline::Float64=Inf)

    waitpid(p; deadline=0.0)

    while deadline >= time() && isrunning(p)
        r = @cerr allow=C.ESRCH C.pidfd_open(p.pid, 0)
        if r != -1
            fd = FD{In,PidFD}(r)
            try
                @dblock fd.ready wait(fd; deadline)
            finally
                close(fd)
            end
        end
        waitpid(p; deadline=0.0)
    end

    nothing
end


@db function kill(p::Process)
    if isalive(check(p))
        C.close(p.in)
        C.close(p.out)
        C.kill(p, C.SIGKILL)                             ;@db 3 "SIGKILL -> $p"
        @asynclog "UnixIO.kill(::Process) -> waitpid()" wait(p)
    else
        @db "Already terminated!"
    end
end


@db 1 function kill_all_processes()
    @sync for p in processes                             ;@db 1 "SIGKILL -> $p"
        C.kill(p, C.SIGKILL)
        @async wait(p)
    end
end


struct ProcessFailedException <: Exception
    p::Process
    cmd::Cmd
end
