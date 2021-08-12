# Macro Utilities.


macro extend(x, ex)
       fields = (:($v::$t) for (v, t) in zip(fieldnames(eval(x)), fieldtypes(eval(x))))
       append!(ex.args[3].args, fields)
       esc(ex)
end


macro selfdoc(ex)

    @require ex isa Expr && ex.head in (:function, Symbol("="))

    docex = copy(ex)
    Base.remove_linenums!(docex)
    if ex.head == Symbol("=")
        body = docex.args[2]
        if body.head == :block && length(body.args) == 1
            docex.args[2] = body.args[1]
        end
    end
    call = ex.args[1]
    if call.head != :call
        call = call.args[1]
    end
    name = call.args[1]
    doc = string("```\n", docex, "\n```\n")
    esc(quote
        @doc($doc, $name)
        Base.@__doc__($ex)
    end)
end


# FIXME copy/paste from base/util.jl: https://git.io/J8vC5
"""
    @invoke f(arg::T, ...; kwargs...)
Provides a convenient way to call [`invoke`](@ref);
`@invoke f(arg1::T1, arg2::T2; kwargs...)` will be expanded into `invoke(f, Tuple{T1,T2}, arg1, arg2; kwargs...)`.
When an argument's type annotation is omitted, it's specified as `Any` argument, e.g.
`@invoke f(arg1::T, arg2)` will be expanded into `invoke(f, Tuple{T,Any}, arg1, arg2)`.
"""
macro invoke(ex)
    f, args, kwargs = destructure_callex(ex)
    arg2typs = map(args) do x
        Base.is_expr(x, :(::)) ? (x.args...,) : (x, GlobalRef(Core, :Any))
    end
    args, argtypes = first.(arg2typs), last.(arg2typs)
    return esc(:($(GlobalRef(Core, :invoke))($(f), Tuple{$(argtypes...)}, $(args...); $(kwargs...))))
end

function destructure_callex(ex)
    Base.is_expr(ex, :call) || throw(ArgumentError("a call expression f(args...; kwargs...) should be given"))

    f = first(ex.args)
    args = []
    kwargs = []
    for x in ex.args[2:end]
        if Base.is_expr(x, :parameters)
            append!(kwargs, x.args)
        elseif Base.is_expr(x, :kw)
            push!(kwargs, x)
        else
            push!(args, x)
        end
    end

    return f, args, kwargs
end



# End of file: macroutils.jl
