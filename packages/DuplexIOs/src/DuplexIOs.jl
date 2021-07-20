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

@static if isdefined(Base, :shutdown)
    Base.shutdown(d::DuplexIO) = close(d.out)
end

"""
Types of arg 2 for methods of f.
"""
arg2_types(f) = unique(skipmissing(
    m.nargs < 3 || m.sig isa UnionAll ? missing :
    m.sig.types[3] == Vararg ? missing : m.sig.types[3]
for m in methods(f)))


"""
    @wrap x f

Wrap method `f` for DuplexIO field `x`:
    Base.f(d::DuplexIO, a...) = Base.f(d.x, a...)
"""
macro wrap(x, f)
    Expr(:block, 

         esc(:((Base.$f(d::DuplexIO; k...) = Base.$f(d.$x; k...)))),

        (esc(:((Base.$f(d::DuplexIO, a::$T, aa...; k...) =
                Base.$f(d.$x, a, aa...; k...))))
         for T in arg2_types(eval(:(Base.$f))))...
    )
end


# Output methods.

@wrap out iswritable
@wrap out buffer_writes
@wrap out flush
@wrap out write
@wrap out unsafe_write


# Input methods.

@wrap in isreadable
@wrap in eof
@wrap in bytesavailable
@wrap in read
@wrap in read!
#@wrap in readbytes! FIXME "WARNING: Method definition readbytes...." ???
@wrap in readuntil
@wrap in readline
@wrap in countlines
@wrap in eachline
@wrap in readeach
@wrap in unsafe_read
@wrap in peek
@wrap in readavailable
@wrap in mark
@wrap in ismarked
@wrap in unmark
@wrap in reset



end #module DuplexIOs
