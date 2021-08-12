# Debug.

using Crayons
using TextWrap

using REPL


include("debug_recompile_trigger.jl") # The Makefile touches this file to force
                                      # recompilation. e.g. for ENV changes.



# Debug Level.


const DEFAULT_DEBUG_LEVEL = 0

"""
Set `ENV["JULIA_UNIX_IO_DEBUG_LEVEL"]` at compile time to control
the verbosity of debug messages.
Use `set_debug_level(n)` to change the debug level at runtime.
"""
DEBUG_LEVEL = parse(Int, get(ENV, "JULIA_UNIX_IO_DEBUG_LEVEL",
                                  "$DEFAULT_DEBUG_LEVEL"))


"""
### `set_debug_level` -- Control the verbosity of debug messages.

    set_debug_level(n)

`n` can't be higher than the compiled in `BASE_DEBUG_LEVEL`
(because the `@db` marcro reduces these messages to `:()` at compile time.)

Defaults to `ENV["JULIA_UNIX_IO_DEBUG_LEVEL"]`.
"""
function set_debug_level(n)
    global DEBUG_LEVEL
    @require n <= BASE_DEBUG_LEVEL
    DEBUG_LEVEL = n
end

const BASE_DEBUG_LEVEL = DEBUG_LEVEL



# Abbreviations.

db_t(t) = debug_time(t)
db_c(c,p) = constant_name(c;prefix=p)



# State.

"""
`task` is the task that produced the most recent log message.
`t0` is the `time()` the process started.
"""
mutable struct GlobalDebug
    task::Int
    t0::Float64
    lock::Base.ThreadSynchronizer
    GlobalDebug() = new(-1, Inf, Base.ThreadSynchronizer())
end

const global_debug = GlobalDebug()


function debug_init()
    global DEBUG_LEVEL
    global_debug.t0 = time()

    env_level = parse(Int, get(ENV, "JULIA_UNIX_IO_DEBUG_LEVEL", "0"))
    if env_level > DEBUG_LEVEL
        @error "ENV[\"JULIA_UNIX_IO_DEBUG_LEVEL\"] = $env_level, " *
               "but compiled-in DEBUG_LEVEL = $DEBUG_LEVEL.\n" *
               "Debug messages above $DEBUG_LEVEL will not be displayed " *
               "until the the UnixIO module is re-compiled."
    elseif env_level < DEBUG_LEVEL
        @info "ENV[\"JULIA_UNIX_IO_DEBUG_LEVEL\"] = $env_level -> DEBUG_LEVEL"
        DEBUG_LEVEL = env_level
    end
end


"""
`indent` is a stack of string pairs used to indent debug messages.
The first string of the pair contains the full call path.
The second string is padded with whitespace.

`bg_color` is used to render messages for this task.
"""
mutable struct TaskDebug
    indent::Vector{Tuple{String,String}}
    bg_color::Crayon
    prev::Tuple
    leader::String
    TaskDebug() = new([("","")], popfirst!(debug_background_colors), (), "")
end


"""
Get the `TaskDebug` struct for the current task.
"""
function task_local_debug()
    key = :UNIX_IO_DEBUG_STATE
    s = try
        task_local_storage(key)
    catch
        task_local_storage(key, TaskDebug())
    end
    s
end


const DEBUG_FILENAME_WIDTH=24
const DEBUG_BLANK_LINE_INDENT = 35 + DEBUG_FILENAME_WIDTH
const DEBUG_MIN_INDENT=6
"""
Indent this task's debug messages for new call to `function_name`.
"""
@noinline function debug_indent_push(function_name::String)
    function_name = function_name[1:min(length(function_name),
                                    DEBUG_MIN_INDENT)]
    pad = repeat(" ", length(function_name))
    v = task_local_debug().indent
    i, j = v[end]
    i = i == "" ? function_name : string(i, " │ ", function_name)
    j = j == "" ? pad : string(j, " │ ", pad)
    push!(v, (i, j))
end


"""
Revert to the indentation used before `debug_indent_push`.
"""
debug_indent_pop() = pop!(task_local_debug().indent)



# Printing.


"""
IO configuration for printing debug messages.
"""
debug_io_context(io=Base.stderr) =
    IOContext(io, :color => true,
                  :module => @__MODULE__,
                  :compact => true,
                  :limit => true,
                  :displaysize => (1,30))


"""
    debug_print(debug_level, lineno, message; [prefix= " │ "]

Print a debug `message` colored for `debug_level`.
Annotate the message with:
 - a timestamp,
 - `lineno`,
 - Thread and Task IDs.
"""
debug_print(n, l, v; kw...) = debug_print(n, l, "", v; kw...)

@noinline function debug_print(n::Int, lineno::String,
                               message::String, value="";
                               new_function="",
                               function_lineno="",
                               function_return="",
                               prefix::String=" │ ")
    @nospecialize
    DEBUG_LEVEL < n && return
    @ccall(jl_generating_output()::Cint) == 1 && return

    io = IOBuffer()
    ioc = debug_io_context(io)

    color = debug_level_colors[max(1,n)]
    bg_color = task_local_debug().bg_color

    # Has anything been logged since function entry?
    task_local = task_local_debug()
    function_indented = task_local.prev != (function_return, function_lineno)
    task_local.prev = (new_function, lineno)

@lock global_debug.lock begin

    # Create a Task ID and check for task-switch.
    task = Int(pointer_from_objref(current_task())) & 0xffff
    task_switched = task != global_debug.task
    global_debug.task = task

    # Use verbose indentation if there was a task-switch.
    indent = task_local.indent[end][2] # FIXMEtask_switched ? 1 : 2]

    if function_return != ""
        task_local.leader = ""
        if length(function_return) > DEBUG_MIN_INDENT
            if function_indented
                prefix = " ╰" *
                         repeat("─", length(function_return) - 1
                                     - DEBUG_MIN_INDENT) *
                         "▶ "
            else
                prefix = repeat(" ", length(function_return)
                                     - DEBUG_MIN_INDENT) *
                         " ╰▶ "
            end
        else
            prefix = " ╰▶ "
        end
    end

    if indent != "" 
        indent *= prefix
    end

    thread_offset = repeat("   ", Threads.threadid()-1)

    if task_switched
        debug_write("\n")
    end

    if function_indented && task_local.leader != ""
        debug_write(task_local.leader)
        task_local.leader = ""
    end

    dbprint(ioc,
        bg_color,

        color, "[ UnixIO $n: ", inv(color),

        # Timestamp.
        lpad(debug_time(time()), 8), " ",

        # File and Line Number.
        lineno, " ",

        # Thread and Task IDs
        (task_switched ? (lpad(Threads.threadid(), 2), ".",
                          uppercase(string(task; base=16, pad=4)), " ")
                       : (repeat(" ", 8),))...,

        # Indented message.
        thread_offset, indent, message, value,

        "\e[0K", # Clear to end of line
        inv(bg_color),
        "\n")

    # Wrap long lines.
    width = displaysize(Base.stdout)[2] - 1
    if io.size > width
        line = String(take!(io))
#        id = task_local_debug().indent[end][2]
        pad = string(repeat(" ", DEBUG_BLANK_LINE_INDENT),
                     thread_offset, indent)
        if new_function != ""
            pad = string(pad, repeat(" ", length(new_function)), prefix)
        else
            pad *= "    "
        end
        if (width - length(pad)) < 16
            pad = ""
        end
        lines = string(wrap(line; width = width, subsequent_indent = pad),
                       "\n")
        debug_write(lines)
    else
        GC.@preserve io debug_write(pointer(io.data), io.size)
    end


# ╰╯ ╮
    if length(new_function) > DEBUG_MIN_INDENT
        io.size = 0
        io.ptr = 1
        print(ioc,
              bg_color,
              repeat(" ", DEBUG_BLANK_LINE_INDENT), thread_offset, indent,
              repeat(" ", DEBUG_MIN_INDENT),
              " ╭", repeat("─", length(new_function) - 1
                                - DEBUG_MIN_INDENT), "╯",
              "\e[0K", # Clear to end of line
              inv(bg_color),
              "\n")
        task_local.leader = String(take!(io))
    end
end # lock
end


"""
Write directly to STDERR.
"""
function debug_write(fd, p, l)
    while l > 0
        n = C.write(fd, p, l)
        if n > 0
            l -= n;
            p += n;
        elseif n == -1
            @assert errno() in (C.EAGAIN, C.EINTR)
        end
    end
    tcdrain(fd)
end
debug_write(p, l) = debug_write(Base.STDERR_NO, p, l)
debug_write(s::String) = GC.@preserve s debug_write(pointer(s), ncodeunits(s))


debug_time(t) = round(t - global_debug.t0; digits=4)



# Macro utilities.

"""
Filename: Line No. String
"""
function debug_lineno_str(source)
    f = basename(string(source.file))
    string(lpad(f,DEBUG_FILENAME_WIDTH), ":", rpad(source.line,4))
end


"""
String representation of function argument.
"""
function dbtiny(x; limit=16)
    s = dbshort(x)
    if length(s) > limit
        s = string(s[1:nextind(s,16)], "...")
    end
    return s
end

dbtiny(x::Cmd) = repr(x)

function dbshort(x)
    io = IOBuffer()
    dbshow(debug_io_context(io), x)
    String(take!(io))
end


"""
Function argument types (for arguments that have types).
"""
function argtypes(ex)
  f, args, kwargs = destructure_callex(ex)
  args = map(x->Base.is_expr(x, :(::)) ? (x.args...,) : missing, args)
  last.(skipmissing(args))
end


"""
Symbol for function argument.
"""
argsym(s::Symbol) = s
argsym(s::Expr) = s.head == :(::)        ? argsym(s.args[1]) :
                  s.head == :kw          ? argsym(s.args[1]) :
                  s.head == :...         ? argsym(s.args[1]) :
                  s.head == :parameters  ? missing           :
                                           " ?"

"""
Split body at end of "header" lines (e.g. `@nospecialize`).
"""
function body_split(body)
    line1(::LineNumberNode) = false
    line1(e::Expr) = e.args[1] != Symbol("@nospecialize")
    line1(::Any) = true
    i = findfirst(line1, body.args)
    while i > 2 && body.args[i-1] isa LineNumberNode
        i -= 1
    end
    head = body
    body = copy(head)
    deleteat!(head.args, i:length(head.args))
    deleteat!(body.args, 1:i-1)
    head, body
end



# Instrumentation macros.


"""
Like `Base.@lock`, but with logging when blocked waiting for lock.
"""
macro dblock(l, expr)
    if DEBUG_LEVEL < 0
        return esc(:(@lock $l $expr))
    end

    lineno = debug_lineno_str(__source__)

    quote
        l = $(esc(l))
        warn = islocked(l)
        warn && debug_print(1, $lineno, "🔒 Waiting $(string(l)) ⁉️ ...")
        lock(l)
        warn && debug_print(1, $lineno, "🔓 Unlocked.")
        try
            $(esc(expr))
        finally
            unlock(l)
        end
    end
end


"""
Wrap the body of function `ex` wtih calls to `@debug_function_entry` and
`finally @debug_function_exit`.
(Do not use directly. Called by `@db`)
"""
macro debug_function(n::Int, ex::Expr, lineno::String)
    DEBUG_LEVEL < n && return esc(ex)

    @require ex.head == :function
    @require length(ex.args) == 2
    call, body = ex.args
    @require call.head in (:call, :where)
    @require body.head == :block
    if call.head != :call
        call = call.args[1]
    end
    @assert call.head == :call

    @info "@db Wrapping $call"

    # Split function Expr into parts.
    name = string(call.args[1])
    types = join(argtypes(call), ", ")
    if types != ""
        types = "($types)"
    end
    args = tuple((skipmissing(argsym(a) for a in call.args[2:end]))...)
    head, body = body_split(body)

    # Rewrite function body.
    body = quote

        _db_lineno::String = $lineno
        _db_fname::String = $name
        _db_level::Int = $n
        _db_returned::Bool = false
        _db_prefix::String = " │ "

        debug_print(
            _db_level,
            _db_lineno,
            string(_db_fname, " ┬", $types, " <- (", #┌─┐
                join(((dbtiny(_x) for _x in ($(args...),))...,), ", "),
            ")");
            new_function=_db_fname)

        debug_indent_push(_db_fname)

        _db_result = nothing
        try
            # Original function body.
            _db_result = $body

        catch _db_err
            _db_result = "⚠️  $_db_err"
            rethrow(_db_err)
        finally
            if ! _db_returned
                debug_print(_db_level, _db_lineno,
                            _db_result == nothing ? "👍" : dbshort(_db_result);
                            function_lineno = _db_lineno,
                            function_return = _db_fname)
            end
            debug_indent_pop()
        end
        _db_result
    end
    append!(head.args, body.args)
    esc(ex)
end


"""
Print the return value before returning.
(Do not use directly. Called by `@db`)
"""
macro debug_return(n::Int, ex::Expr, message, lineno)
    DEBUG_LEVEL < n && return esc(ex)

    @require ex.head == :return
    v = gensym()
    message = something(message, :(dbshort($v)))
    esc(quote
        $v = $(ex.args[1])
        debug_print(_db_level, $lineno, $message; function_lineno = _db_lineno,
                                                  function_return = _db_fname)
        _db_returned = true
        return $v
    end)
end

const _db_prefix = " │ [ "

"""
Print a debug message.
(Do not use directly. Called by `@db`)
"""
macro debug_print(n::Int, ex, lineno)
    DEBUG_LEVEL < n && return :()
    esc(:(debug_print($n, $lineno, $ex; prefix=_db_prefix)))
end


"""
Print a debug message for `name` and `value`.
(Do not use directly. Called by `@db`)
"""
macro debug_show(n::Int, name, value, lineno)
    DEBUG_LEVEL < n && return :()
    esc(:(debug_print($n, $lineno, $name, $value; prefix=_db_prefix)))
end


"""
    @db [n] message

    @db [n] function name(args...)
        ...
        @db return x ["message"]
    end

`@db` prints debug messages.
The optional `n` parameter causes a message to be disabled
if `DEBUG_LEVEL < n`. Disabled messages have zero-cost.
The macro generates an empty expression `:()` for disabled messages.

When applied to a function definition, `@db` will print messages
for function entry and exit (both by `return` and by `throw`).

When applied to a return statement, `@db` will print the return
value (or an optional `message`) before returning.
"""
macro db(args...)

    db_level = args[1]
    if db_level isa Int
        args = args[2:end]
    else
        db_level =1
    end

    ex, message = (args..., nothing)

    lineno = debug_lineno_str(__source__)

    if ex isa Expr && ex.head == :return
        return esc(:(@debug_return $db_level $ex $message $lineno))
    elseif ex isa Expr && ex.head == :function
        return esc(:(@debug_function $db_level $ex $lineno))
    else
        if ex isa String || (ex isa Expr && ex.head == :string)
            return esc(:(@debug_print $db_level $ex $lineno))
        else
            return esc(Expr(
                :block,
                (:(@debug_show $db_level $(string(v, " = ")) $v $lineno)
                for v in args)...))
        end
    end

    @assert false
end


macro db_indent(n, f)
    DEBUG_LEVEL < n && return :()
    esc(:(debug_indent_push($f)))
end

macro db_unindent(n)
    DEBUG_LEVEL < n && return :()
    esc(:(debug_indent_pop()))
end



# Colors.

const debug_level_colors = [
    crayon"bold fg:202",
    crayon"bold fg:208",
    crayon"bold fg:220",
    crayon"bold fg:46",
    crayon"bold fg:51",
    crayon"bold fg:27"]

const debug_background_colors =
    Iterators.Stateful(
    Iterators.Cycle([
    crayon"bg:16",
    crayon"bg:18",
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



# Pretty Printing.

dbprint(io::IO, v::String) = print(io, v)
dbprint(io::IO, a) = print(io, a)

dbshow(io::IO, a) = show(io, a)

function dbprint(io::IO, a, args...)
    for a in (a, args...)
        if a isa String || a isa Crayon
            dbprint(io, a)
        else
            dbshow(io, a)
        end
    end
end


function dbshow(io::IO, v::Union{AbstractVector,AbstractSet})
    if get(io, :compact, false)
        print(IOContext(io, :typeinfo => typeof(v)), v)
    else
        print(io, v)
    end
end


function dbstring(args...)
    io = IOBuffer()
    ioc = debug_io_context(io)
    dbprint(ioc, args...)
    String(take!(io))
end



# Box Drawing.

"""
╔══╦══╗ ┌──┬──┐ ╭──╮ ┏━━┳━━┓    ▲     ■●◠ ◢◣ ░       
║  ║  ║ │  │  │ │  │ ┃  ┃  ┃ ╌┈┉│┇┋╏ ▢□◯◡ ◥◤ ▒       
╠══╬══╣ ├──┼──┤ │  │ ┣━━╋━━┫ ◀──┼──▶         ▓       
║  ║  ║ │  │  │ │  │ ┃  ┃  ┃ ╍┅┄│┆┊╎  ▁▂▃▄▅▆▇█▉▊▋▌▍▎▏
╚══╩══╝ └──┴──┘ ╰──╯ ┗━━┻━━┛    ▼                    
"""



# Optional Exports.

module Debug

    for x in (Symbol("@db"),
              Symbol("@debug_print"),
              Symbol("@debug_function"),
              Symbol("@debug_return"),
              Symbol("@debug_show"),
              :dbshow,
              :dbtiny,
              :dbprint,
              :dbshort,
              :debug_print,
              :debug_indent_push,
              :debug_indent_pop,
              :_db_prefix)

       eval(:(import ..UnixIO:$x; export $x))
   end
end



# End of file: debug.jl
