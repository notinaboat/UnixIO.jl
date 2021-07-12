# Threaded @ccall wrapper


TID() = Threads.threadid()
TID(t) = Threads.threadid(t)


mutable struct IOThreadState
    id::Int
    busy::Bool
    f::Symbol
    args::Tuple
    IOThreadState(id) = new(id, false, :nothing, ())
end


function thread_state(id)
    global io_thread_state
    for st in io_thread_state
        if st.id == id
            return st
        end
    end
    @assert false "Bad io_thread id: $id"
end


const io_thread_init_done = Ref(false)

function io_thread_init()

    if Threads.nthreads() < 6
        @error "UnixIO requires at least 6 threads. e.g. `julia --threads 6`"
        @async io_thread()
        return
    end

    n = Threads.nthreads()
    threads_ready = fill(false,n)

    # Only use half of the available threads.
    threads_ready[1:n÷2] .= true

    global io_thread_state
    io_thread_state = [IOThreadState(id) for id in n÷2+1:n-1]

    # Run `io_thread()` on each tread...
    Threads.@threads for i in 1:n
        id = Threads.threadid()
        if  id == n
            threads_ready[id] = true
            @async io_monitor()
        end
        if !threads_ready[id]
            threads_ready[id] = true
            @async io_thread(id, thread_state(id))
        end
    end
    yield()

    # Wait for all threads to start...
    while !all(threads_ready)
        sleep(1)
        if !all(threads_ready)
            x = length(threads_ready) - count(threads_ready)
            @info "Waiting to Initialise $x UnixIO Threads..."
        end
    end
end


"""
    UnixIO.@uassert cond [text]

Print a message directly to `STDERR` if `cond` is false,
then throw `AssertionError`.
"""
macro uassert(ex, msgs...)
    msg = isempty(msgs) ? ex : msgs[1]
    if isa(msg, AbstractString)
        msg = msg # pass-through
    elseif !isempty(msgs) && (isa(msg, Expr) || isa(msg, Symbol))
        # message is an expression needing evaluating
        msg = :(Main.Base.string($(esc(msg))))
    else
        msg = Main.Base.string(msg)
    end
    return quote
        if $(esc(ex))
            $(nothing)
        else
            printerr("UnixIO.@uassert failed ⁉️ :",
                     @__FILE__, ":", @__LINE__, ": ", $msg)
            throw(AssertionError($msg))
        end
    end
end


const io_queue = Channel{Tuple{Function, Tuple, Channel}}(0)

function io_thread(id::Int, state::IOThreadState)
    msg(x) = UnixIO.printerr("    io_thread($id): $x")
                                                            #msg("starting...")
    try
        @uassert TID() == id
        for (f, args, result) in io_queue
            @uassert state.busy == false
            state.busy = true
            state.f = Symbol(f)
            state.args = args
                                                           #msg("🟢 $f($args)")
            @uassert TID() == id
            put!(result, f(args...))
            @uassert TID() == id
                                                           #msg("🔴 $f($args)")
            @uassert state.busy == true
            state.busy = false
            GC.safepoint()
        end
    catch err
        msg("error⁉️ : $err")
    end
                                                               #msg("exiting!")
end


function io_monitor()
    msg(x) = UnixIO.printerr("io_monitor(): $x")
    while true
        try
            sleep(10)
            #msg("...")

            # Check Task Workqueues.
            for t in io_thread_state
                q = Base.Workqueues[t.id]
                l = length(q.queue)
                if l > 0
                    msg("io_thread($(t.id)): $l Tasks queued ⁉️ ")
                end
                if t.busy
                    msg("io_thread($(t.id)) busy: $(t.f)($(t.args))")
                end
            end

            # Check io_queue
            if !isempty(io_queue)
                msg("io_queue waiting ⁉️ ")
            end
        catch err
            msg("error⁉️ : $err")
        end
        GC.safepoint()
    end
end


macro yieldcall(expr)
    @assert expr.head == Symbol("::")
    @assert expr.args[1].head == :call
    f = expr.args[1].args[1]
    args = expr.args[1].args[2:end]
    T = expr.args[2]
    esc(quote
        global io_queue

        if !io_thread_init_done[]
            io_thread_init_done[] = true
            io_thread_init()
        end
        if !isempty(io_queue)
            @warn """
                  UnixIO.@yieldcall is waiting for an available thread.
                  Consider increasing JULIA_NUM_THREADS (`julia --threads N`).
                  """
        end
        #printerr("@yieldcall 🟢 $($f)($(($(args...),)))")
        c = Channel{$T}(0)
        put!(io_queue, ($f, ($(args...),), c))
        r = take!(c)
        Base.close(c)
        #printerr("@yieldcall 🔴 $($f)($($(args...)))")
        r::$T
    end)
end



# End of file: threads.jl
