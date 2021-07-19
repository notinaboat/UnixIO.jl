# Timers.


"""
Global vector of timers `(deadline, condition)` sorted by `deadline`.
"""
struct Timer
    deadline::Float64
    ready::Base.ThreadSynchronizer
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
@db 1 function sleep(seconds)
    deadline = time() + seconds
    t = register_timer(deadline, sleep_condition)
    lock(sleep_condition)
    try
        while time() < deadline;                             @db 5 "waiting..."
            wait(sleep_condition)
        end
    finally
        unlock(sleep_condition)
        close(t)
    end
end

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
function next_timer_deadline_ms(timeout_ms)
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
    Base.assert_havelock(timer_lock)
    isempty(timer_vector) ? Inf : timer_vector[1].deadline
end



"""
    register_timer(deadline, ::Condition)

Register `condition` to be notified at `time()` `deadline`.
"""
@db 5 function register_timer(deadline, condition)
    t = Timer(deadline, condition)
    if deadline < Inf
        register_timer(t)
    end
    @db 5 return t
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


"""
Cancel a timer `(deadline, condition)` without notifying `condition`.
"""
@db 5 function Base.close(x::Timer)
    if x.deadline < Inf
        @dblock timer_lock begin
            if x.deadline >= next_timer_deadline()
                i = searchsortedfirst(timer_vector, x)
                if timer_vector[i] == x                           ;@db 3 "⏱🚫"
                    deleteat!(timer_vector, i) 
                end
            end
        end
    end
    nothing
end


"""
Notify timers whos `deadline` has passed and remove from vector.
"""
@db 6 function notify_timers(now = time())
    ready=Base.ThreadSynchronizer[]
    @dblock timer_lock begin
        expired = 0
        for (i, t) in enumerate(timer_vector)
            if t.deadline > now
                break
            end                              
            push!(ready, t.ready)                                 ;@db 3 "⏱->"
            expired = i
        end
        deleteat!(timer_vector, 1:expired)
    end
    for c in ready
        @dblock c notify(c)
    end
    nothing
end



# End of file: timer.jl
