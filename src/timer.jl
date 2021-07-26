# Timers.


"""
Global vector of timers `(deadline, condition)` sorted by `deadline`.
"""
struct Timer
    deadline::Float64
    f::Any
end

Base.isless(a::Timer, b::Timer) = isless(a.deadline, b.deadline)

const timer_vector = Timer[]
const timer_lock = Threads.SpinLock()

function dump_timer_state(msg="")
    now = time()
    printerr("Timers $msg: ", [round(t.deadline - now; digits=2)
                               for t in timer_vector])
end


"""
    UnixIO.sleep(seconds)

Block the current task for a specified number of seconds.
(Waits for a timer based on `UnixIO.poll_wait()`).
"""
sleep(seconds::Float64) = wait_timeout(sleep_condition, seconds)

const sleep_condition = Base.ThreadSynchronizer()


"""
Restart the clock source responsible for calling `notify_timers()`.
The clock source will be sleeping based on `next_timer_deadline_ms()`,
if timer is registered with a nearer deadline, the clock source needs
to be restarted (it will call `next_timer_deadline_ms()` again and go
back to sleep).
"""
@db 3 function restart_timer_clock()
    wakeup_poll(poll_queue)
end


"""
    next_timer_deadline_ms(timeout_ms)

Time from now to the next timer deadline in ms.
If no timers due before `timeout_ms` return `timeout_ms`.
"""
function next_timer_deadline_ms(timeout_ms::Int)
    @dblock timer_lock begin
        deadline = next_timer_deadline()
        dt = deadline - time()
        if dt < (timeout_ms/1000)
            timeout_ms = max(0, round(Int, dt * 1000))
        end
    end
    return timeout_ms
end

function next_timer_deadline()
    assert_havelock(timer_lock)
    isempty(timer_vector) ? Inf : timer_vector[1].deadline
end


const inf_timer = Timer(Inf, nothing)

"""
    register_timer(f, deadline)

Register `f`` to be called at `time()` `deadline`.
"""
@db 5 function register_timer(f, deadline)
    if deadline == Inf
        return inf_timer
    end
    @db 5 return register_timer(Timer(deadline, f))
end

@db 3 function register_timer(t::Timer)
    i = 0
    @dblock timer_lock begin
        i = searchsortedfirst(timer_vector, t)
        insert!(timer_vector, i, t)
    end
    if i == 1                                    ;@db 3 "restart_timer_clock()"
        restart_timer_clock()
    end
    @db 3 return t
end

@db 3 function cancel_timer(t::Timer)
    @require t.deadline !=  Inf
    @dblock timer_lock begin
        if t.deadline >= next_timer_deadline()
            i = searchsortedfirst(timer_vector, t)
            if timer_vector[i] == t                              ;@db 3 "⏱ 🚫"
                deleteat!(timer_vector, i) 
            end
        end
    end
end

"""
Cancel a timer `(deadline, condition)` without notifying `condition`.
"""
@db 5 function Base.close(t::Timer)
    if t.deadline != Inf
        cancel_timer(t)
    end
    nothing
end


"""
Notify timers whos `deadline` has passed and remove from vector.
"""
@db 6 function notify_timers(now = time())
    ready=[]
    @dblock timer_lock begin
        expired = 0
        for (i, t) in enumerate(timer_vector)
            if t.deadline > now
                break
            end                              
            push!(ready, t.f)
            expired = i
        end
        deleteat!(timer_vector, 1:expired)
    end
    for f in ready                                            ;@db 3 "⏱ -> $f"
        f()
    end
    nothing
end


"""
    wait_until(condition, [predicate=()->false], deadline)

If `predicate()` is false, repeatently `wait(condition)` until
`predicate()` is true (or until `deadline` is reached).
"""
@db 3 function wait_until(condition::Base.GenericCondition,
                          predicate,
                          deadline::Float64)
    if predicate()
        return
    end
    @dblock condition begin
        timer = register_timer(deadline) do
            @lock condition notify(condition)
        end
        try
            while !predicate() && time() < deadline         ;@db 3 "waiting..."
                wait(condition)
            end
        finally
            close(timer)
        end
    end
    nothing
end

wait_until(c, d) = wait_until(c, ()->false, d)
@selfdoc wait_timeout(c, t) = wait_until(c, time() + Float64(t))


# Pretty Printing.

function dbshow(io::IO, t::Timer)
    print(io, "Timer(", debug_time(t.deadline),
                        " [", round(t.deadline - time(); digits=2), "])")
end



# End of file: timer.jl
