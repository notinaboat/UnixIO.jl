using ConcurrentCollections

import IOTraits.process_warning_queue

function warning_queue_init()
    global g_warning_queue = LinkedConcurrentRingQueue{FD}()

    # FIXME make this optional
    @asynclog_loop "UnixIO Warning Queue Task" begin
        Base.sleep(10)
        while true
            Base.sleep(1)
            process_warning_queue()
        end
    end
end

warning_queue_push(fd) = push!(g_warning_queue, fd)

function process_warning_queue()
    fd = maybepopfirst!(g_warning_queue)
    if isnothing(fd)
        return
    end 
    fd = something(fd)
    try
        check_warnings(fd)
    finally
        fd.isclosed || warning_queue_push(fd)
    end
    nothing
end

function check_warnings(fd)
    if fd.nwaiting > 0 && !is_registered_with_wait_api(fd)
        @warn "wait(fd) is stuck for: $fd\n" *
               "fd.nwaiting is $(fd.nwaiting) but fd is not registered " *
               "with $(WaitAPI(fd))"
    end
end
