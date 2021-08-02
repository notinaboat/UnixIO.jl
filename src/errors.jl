# Errors.


using Base.Libc: errno


"""
    e.g. constant_name(32; prefix="POLL") -> [:POLLNVAL]

Look up name for C-constant(s) with value `n`.
"""
function constant_name(n::Integer; prefix="", first=false)
    @nospecialize

    v = get(C.constants, n, Symbol[])
    if prefix != ""
        v = filter(x -> startswith(String(x), prefix), v)
    end
    if length(v) == 0
        string(n)
    elseif first || length(v) == 1
        string(v[1])
    else
        string("Maybe: ", join(("$(n)?" for n in v), ", "))
    end
end
constant_name(n; kw...) = constant_name(Int(n); kw...)


"""
Throw SystemError with `errno` info for failed C call.
"""
systemerror(p, errno::Cint=errno(); kw...) =
    Base.systemerror(p, errno; extrainfo=errname(errno))

errname(n) = constant_name(n; prefix="E")

"""
    @cerr [allow=C.EINTR] f(args...)

If `f` returns -1 throw SystemError with `errno` info.
"""
macro cerr(a, b=nothing)
    ex = b == nothing ? a : b
    allow = b == nothing ? b : a
    @require ex isa Expr && ex.head == :call
    @require allow == nothing || (
             allow isa Expr && allow.head == Symbol("=") &&
             allow.args[1] == :allow)
    f = ex.args[1]
    args = ex.args[2:end]
    r = gensym()
    condition = allow == nothing ?
                :($r == -1) :
                :($r == -1 && errno() ∉ $(allow.args[2]))
    esc(:(begin
        $r = $ex
        $condition && systemerror(dbstring($f, ($(args...),)))
        @assert $r >= -1
        $r
    end))
end


"""
    @czero f(args...)

If `f` returns non-zero throw SystemError with return value as `errno`.
"""
macro cerr0(ex)
    @require ex isa Expr && ex.head == :call
    f = ex.args[1]
    args = ex.args[2:end]
    r = gensym()
    esc(:(begin
        $r = $ex
        $r != 0 && systemerror(dbstring($f, ($(args...),)), $r)
        nothing
    end))
end



# End of file: errors.jl
