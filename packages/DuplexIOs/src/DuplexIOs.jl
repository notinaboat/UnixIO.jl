"""
# DuplexIOs.jl

Combine two one-direction `IO` objects into a single bi-direction `IO` object.
"""
module DuplexIOs

export DuplexIO


struct DuplexIO{IN <: IO, OUT <: IO} <:IO
    in::IN
    out::OUT
end


# Duplex methods.

Base.isopen(d::DuplexIO) = (Base.isopen(d.in) && Base.isopen(d.out))
Base.close(d::DuplexIO) = (Base.close(d.in); Base.close(d.out))
Base.lock(d::DuplexIO) = (Base.lock(d.in); Base.lock(d.out))
Base.unlock(d::DuplexIO) = (Base.unlock(d.in); Base.unlock(d.out))

Base.skipchars(p, d::DuplexIO; k...) = Base.skipchars(p, d.in; k...)


function Base.stat(d::DuplexIO)
    s1 = stat(d.in)
    s2 = stat(d.out)
    s1 == s2 || throw(ArgumentError("""
        Can't `stat` a DuplexIO unless `.in` and `.out` refer to the same file.
        Try `stat(io.in)` or `stat(io.out)`.
        """))
    return s1
end


@static if isdefined(Base, :shutdown)
    Base.shutdown(d::DuplexIO) = close(d.out)
end


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


# Output methods.

@wrap out Base.iswritable
@wrap out Base.buffer_writes
@wrap out Base.flush
@wrap out Base.write
@wrap out Base.unsafe_write


# Input methods.

@wrap in Base.isreadable
@wrap in Base.eof
@wrap in Base.bytesavailable
@wrap in Base.read
@wrap in Base.read!
#@wrap in Base.readbytes! FIXME "WARNING: Method definition readbytes...." ???
@wrap in Base.readuntil
@wrap in Base.readline
@wrap in Base.countlines
@wrap in Base.eachline
@wrap in Base.readeach
@wrap in Base.unsafe_read
@wrap in Base.peek
@wrap in Base.readavailable
@wrap in Base.mark
@wrap in Base.ismarked
@wrap in Base.unmark
@wrap in Base.reset



end #module DuplexIOs
