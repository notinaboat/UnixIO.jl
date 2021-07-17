# Debug.


const DEBUG_LEVEL = 1


mutable struct DebugState 
    lock::Threads.SpinLock
    task::Int
    f::String
    indent::Dict{Int,Vector{Tuple{String,String}}}
end

const db = DebugState(Threads.SpinLock(), 0, "?",
                      Dict{Int,Vector{Tuple{String,String}}}())

db_indent(t) = get(db.indent, t, [("","")])[end]

function db_indent_more(t, s)
    pad = repeat(" ", length(s))
    @lock db.lock begin
        if !haskey(db.indent, t)
            db.indent[t] = [(s, pad)]
        else
            v = db.indent[t]
            i, j = v[end]
            i = string(i, " │ ", s)
            j = string(j, " │ ", pad)
            push!(v, (i, j))
        end
    end
end

function db_indent_less(t) 
    @lock db.lock begin
        v = db.indent[t]
        pop!(v)
        if isempty(v)
            delete!(db.indent, t)
        end
    end
end



"""
Global alias as a fallback for local variable `_db_f` created by `@db` macro.
"""
_db_f = "" 
_db_f_n = -1 

db_t(t=time()) = round(t - debug_t0; digits=4)

db_c(c,p) = constant_name(c;prefix=p)

db_taskid() = hash(Int(pointer_from_objref(current_task())) >> 8) & 0xffff

function db_tasklabel(io, t)
    th_id = Threads.threadid()
    ta_id = uppercase(string(t; base=16, pad=4))
    n = th_id % 4
    c = n == 0 ? :blue :
        n == 1 ? :green :
        n == 2 ? :yellow :
        n == 3 ? :red :
                 :white
    printstyled(io, lpad(th_id, 2), ".", ta_id, " "; color=c)
end

function db_line(io, f, l)
    f = basename(f)
    print(io, lpad(f,12), ":", rpad(l,4), " ")
end

using Crayons

const db_bg =
    Iterators.Stateful(
    Iterators.Cycle([
    crayon"bg:16",
    crayon"bg:52",
    crayon"bg:233",
    crayon"bg:234",
    crayon"bg:235",
    crayon"bg:236",
    crayon"bg:237",
    crayon"bg:238",
    crayon"bg:239",
    crayon"bg:240",
    crayon"bg:241",
    crayon"bg:242",
    crayon"bg:17",
    crayon"bg:18",
    crayon"bg:19",
    crayon"bg:20",
    crayon"bg:21",
    crayon"bg:22",
    crayon"bg:23",
    crayon"bg:24",
    crayon"bg:25",
    crayon"bg:58",
    crayon"bg:59",
    crayon"bg:60",]))

function db_taskbg()
    s = current_task().storage
    if s == nothing
        s = IdDict()
        current_task().storage = s
    end
    if !haskey(s, :UNIXIO_DB_BG)
        s[:UNIXIO_DB_BG] = popfirst!(db_bg)
    end
    s[:UNIXIO_DB_BG]
end


"""
Debug function entry.
"""
macro dbf(n::Int, f, s="")
    if DEBUG_LEVEL < n
        return :()
    end
    esc(quote
        _db_f = string($f)
        _db_f_n = $n
        @db $n string(_db_f, " ┐ ", $s) " │ " $(__source__)
        db_indent_more(db_taskid(), _db_f)
        Base.@lock_nofail db.lock db.f = _db_f
    end)
end


"""
Debug function return.
"""
macro dbr(n::Int, s="")
    if DEBUG_LEVEL < n
        return :()
    end
    esc(quote
        @assert $n == _db_f_n
        @db $n $s " └ " $(__source__)
                  #  ▶
        db_indent_less(db_taskid())
    end)
end


"""
Debug message.
"""
macro db(n::Int, s, prefix="", line=nothing)
    if DEBUG_LEVEL < n
        return :()
    end
    levelcolor = n == 5 ? :white :
                 n == 4 ? :blue :
                 n == 3 ? :green :
                 n == 2 ? :yellow :
                 n == 1 ? :magenta :
                          :red
    if line == nothing
       line = __source__
    end
    quote
        prefix = $(esc(prefix))
        f = $(esc(:_db_f))
        task = db_taskid()

        io = IOBuffer()
        ioc = IOContext(io, Base.stdout)
        printstyled(ioc, db_taskbg(), "[ UnixIO: ";
                    bold = true, color = $(QuoteNode(levelcolor)))
        print(ioc, lpad(db_t(), 8), " ")
        db_line(ioc, $(string(line.file)), $(string(line.line)))
        db_tasklabel(ioc,task)

        indent = ""
        @lock db.lock begin
            task_switched = task != db.task
            db.task = task
            indent = db_indent(task)[task_switched ? 1 : 2]
        end
        if prefix  == ""
            prefix = " │ "
        end
        if indent == ""
            prefix = ""
        end

        print(ioc, indent, prefix, string($(esc(s))),
              "\e[0K", # clear to end of line
              inv(db_taskbg()), "\n")

        p = pointer(io.data)
        s = io.size
        @lock db.lock begin
            while s > 0
                n = GC.@preserve io C.write(Base.STDERR_NO, p, s)
                if n > 0
                    s -= n;
                    p += n;
                end
            end
        end
    end
end


sprintcompact(x) = sprint(show, x; context=:compact => true)
printerrcompact(x) = printerr(sprintcompact(x))


macro dblock(l, expr)
    if DEBUG_LEVEL < 1
        return esc(:(@lock $l $expr))
    end
    quote
        l = $(esc(l))
        warn = islocked(l)
        warn && @db 1 "🔒 Waiting $(string(l)) ⁉️ ..." "" $(__source__)
        lock(l)
        warn && @db 1 "🔓 Unlocked." "" $(__source__)
        try
            $(esc(expr))
        finally
            unlock(l)
        end
    end
end


# End of file: debug.jl
