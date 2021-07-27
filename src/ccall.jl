# C Language Interface.


"""
    @gc_safe @ccall f(arg::Type, ...)::Type

Wrap a `@ccall` with `jl_gc_safe_[enter|leave]`.

This allows the GC to run during the `@ccall`.
Without this all threads will be blocked if the GC tries to run
during the `@ccall`.

The `@ccall` must not call back into Julia.
"""
macro gc_safe(ex)
    quote
        old_state = @ccall jl_gc_safe_enter()::Int8
        n = $(esc(ex))
        @ccall jl_gc_safe_leave(old_state::Int8)::Cvoid
        n
    end
end


# End of file: ccall.jl
