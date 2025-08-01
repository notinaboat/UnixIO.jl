import IOTraits.process_warning_queue

function warning_queue_init()

    # FIXME make this optional
    @asynclog_loop "UnixIO Warning Queue Task" begin
        Base.sleep(5)
        while true
            Base.sleep(1)
            process_warning_queue()
        end
    end

    global warning_queue_i = 0
end

function process_warning_queue()
    global warning_queue_i
    fd = nothing
    while fd == nothing
        fd = get_weak_fd(warning_queue_i)
        warning_queue_i += 1
        if warning_queue_i > MAX_FD
            warning_queue_i = 0
        end
    end
    check_warnings(fd)
    nothing
end

function check_warnings(fd)
    #@info "check_warnings $fd"
    if fd.state == FD_WAITING
        ok = is_registered_with_wait_api(fd)
        if !ismissing(ok) && !ok
            @warn "wait(fd) is stuck for: $fd\n" *
                  "fd.state is FD_WAITING  but fd is not registered " *
                  "with $(WaitAPI(fd))"
        end
    end
end
