# Timers.


"""
Global vector of timers `(deadline, condition)` sorted by `deadline`.
"""
const Timer = Tuple{Float64,Base.ThreadSynchronizer}
const timer_vector = Timer[]
const timer_lock = Threads.SpinLock()

function dump_timer_state(msg="")
    now = time()
    printerr("Timers $msg: ", [round(deadline - now; digits=2)
                          for (deadline, _) in timer_vector])
end

const sleep_condition = Base.ThreadSynchronizer()

"""
    UnixIO.sleep(seconds)

Block the current task for a specified number of seconds.
(Waits for a timer based on `UnixIO.poll_wait()`).
"""
function sleep(seconds)                             ;@dbf 1 :sleep "💤$seconds"
    deadline = time() + seconds
    t = register_timer(deadline, sleep_condition)
    lock(sleep_condition)
    try
        while time() < deadline;                             @db 5 "waiting..."
            wait(sleep_condition)
        end
    finally
        unlock(sleep_condition)
        cancel_timer(t)
    end                                                                 ;@dbr 1
end


"""
Restart the clock source responsible for calling `notify_timers()`.
The clock source will be sleeping based on `next_timer_deadline_ms()`,
if timer is registered with a nearer deadline, the clock source needs
to be restarted (it will call `next_timer_deadline_ms()` again and go
back to sleep).
"""
restart_timer_clock() = wakeup_poll(poll_queue)


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
    isempty(timer_vector) ? Inf : timer_vector[1][1]
end



"""
    register_timer(deadline, ::Condition)

Register `condition` to be notified at `time()` `deadline`.
"""
function register_timer(deadline, condition)
    t = convert(Timer, (deadline, condition))
    if deadline < Inf
        register_timer(t)
    end
    return t
end

function register_timer(t::Timer)
    i = 0                             ;@dbf 3 :register_timer "⏱$(db_t(t[1]))"
    @dblock timer_lock begin
        i = searchsortedfirst(timer_vector, t;
                              lt=((a,_),(b,_)) -> a < b)
        insert!(timer_vector, i, t)
    end
    if i == 1                                    ;@db 3 "restart_timer_clock()"
        restart_timer_clock()
    end                                                      ;@dbr 3 db_t(t[1])
    return t
end


"""
Cancel a timer `(deadline, condition)` without notifying `condition`.
"""
function cancel_timer(x::Timer)         ;@dbf 5 :cancel_timer "⏱$(db_t(x[1]))"
    deadline, _ = x
    if deadline < Inf
        @dblock timer_lock begin
            if deadline >= next_timer_deadline()
                i = searchsortedfirst(timer_vector, x;
                                      lt=((a,_),(b,_)) -> a < b)
                if timer_vector[i] == x                           ;@db 3 "⏱🚫"
                    deleteat!(timer_vector, i) 
                end
            end
        end
    end                                                                 ;@dbr 5
    nothing
end


"""
Notify timers whos `deadline` has passed and remove from vector.
"""
function notify_timers(now = time())                     ;@dbf 6 :notify_timers
    ready=Base.ThreadSynchronizer[]
    @dblock timer_lock begin
        expired = 0
        for (i, (deadline, condition)) in enumerate(timer_vector)
            if deadline > now
                break
            end                              
            push!(ready, condition)                               ;@db 3 "⏱->"
            expired = i
        end
        deleteat!(timer_vector, 1:expired)
    end
    for c in ready
        @dblock c notify(c)
    end                                                                 ;@dbr 6
    nothing
end



# End of file: timer.jl
