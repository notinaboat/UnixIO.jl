# Threaded @ccall wrapper


mutable struct IOThreadState
    id::Int
    busy::Bool
    f::Symbol
    args::Tuple
    IOThreadState(id) = new(id, false, :nothing, ())
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

    # Run `io_thread()` on each tread...
    Threads.@threads for i in 1:n
        id = Threads.threadid()
        if  id == n
            threads_ready[id] = true
            @async io_monitor()
        end
        if !threads_ready[id]
            threads_ready[id] = true
            @async io_thread(id)
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


const io_queue = Channel{Tuple{Function, Tuple, Channel}}(0)

function io_thread(id::Int)
    try
        for (f, args, result) in io_queue
            put!(result, f(args...))
            GC.safepoint()
        end
    catch err
        printerr("io_thread($id): error⁉️ : $err")
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
        c = Channel{$T}(0)
        put!(io_queue, ($f, ($(args...),), c))
        r = take!(c)
        Base.close(c)
        r::$T
    end)
end



# End of file: threads.jl
