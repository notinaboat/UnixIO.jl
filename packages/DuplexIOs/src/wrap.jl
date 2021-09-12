"""
Types of arg 2 for methods of f.
"""
arg2_types(f) = (m.nargs < 3 || m.sig isa UnionAll ? missing :
                 m.sig.types[3] == Vararg          ? missing :
                                                     m.sig.types[3]
                 for m in methods(f)
                ) |> skipmissing |> unique


"""
    @wrap [x] f

Wrap method `f` for DuplexIO field `x` (`in` or `out`):

    Base.f(d::DuplexIO, a...) = Base.f(d.x, a...)

Or if `x` is omitted, wrap for both fields:

    Base.f(d::DuplexIO, a...) = (Base.f(d.in, a...); Base.f(d.out, a...))
"""
macro wrap(a, b=nothing)

    x, f = (b == nothing) ? (nothing, a) : (a, b)

    if x != nothing
        Expr(:block, 

             esc(:(($f(d::DuplexIO; k...) = $f(d.$x; k...)))),

            (esc(:(($f(d::DuplexIO, a::$T, aa...; k...) =
                    $f(d.$x, a, aa...; k...))))
             for T in arg2_types(Main.eval(:($f))))...
        )
    else
         esc(:(($f(d::DuplexIO, a...; k...) = ($f(d.in, a...; k...),
                                              ($f(d.out, a...; k...))))))
    end
end
