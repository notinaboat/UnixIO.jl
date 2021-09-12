"""
Types of arg 2 for methods of f.
"""
arg2_types(f) = (m.nargs < 3 || m.sig isa UnionAll ? missing :
                 m.sig.types[3] == Vararg          ? missing :
                                                     m.sig.types[3]
                 for m in methods(f)
                ) |> skipmissing |> unique


"""
    @wrap f T x
 
Wrap method `f` for `T` field `x`:

    Base.f(io::T, a...) = Base.f(io.x, a...)
"""
macro wrap(f, T, x)
    Expr(:block, 
         esc(:(($f(io::$T; k...) = $f(io.$x; k...)))),
        (esc(:(($f(io::$T, a::$t, aa...; k...) =
                $f(io.$x, a, aa...; k...))))
         for t in arg2_types(Main.eval(:($f))))...
    )
end
