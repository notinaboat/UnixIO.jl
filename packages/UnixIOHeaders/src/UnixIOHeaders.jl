module UnixIOHeaders
using Serialization


"""
Return a vector of system header include paths.
e.g. on macOS, somthing like: [`/Applications/Xcode.app/.../MacOSX.sdk/...`]
"""
function system_include_path()
    if Sys.isapple()
        sdk = chomp(read(`xcrun --show-sdk-path`, String))
        path = [joinpath(sdk, "usr/include")]
    elseif Sys.islinux()
        path = []
        try
            x = eachline(`sh -c "gcc -xc -xc++ -E -v /dev/null 2>&1"`)
            line, state = iterate(x)
            while line != nothing &&
                  line != "#include <...> search starts here:"
                line, state = iterate(x, state)
            end
            line, state = iterate(x, state)
            while line != nothing &&
                  line != "End of search list."
                push!(path, strip(line))
                line, state = iterate(x, state)
            end
        catch err
            @warn err
        end
    end
    path
end


"""
Find `header` by searching under `system_include_path()`.
"""
function find_system_header(header)
    header = replace(header, r"[<>]" => "")
    if !isfile(header)
        for d in system_include_path()
            h = joinpath(d, header)
            if isfile(h)
                return h
            end
        end
    end
    header
end


using Cling_jll

function macro_values(headers, cflags, macro_names, struct_names)

    result = Dict{Symbol,Expr}()

    mktempdir() do d
        cfile = joinpath(d, "tmp.c")
        delim = "aARf6F3fWe6"
        write(cfile,
            ("#include \"$h\"\n" for h in headers)...,
            ("\"$delim\"\n\"$n\"\n$n\n" for n in macro_names)...,
            ("\"$delim\"\n\"$(n)_size\"\nsizeof($n)\n" for n in struct_names)...
        )
        write("cinclude_tmp.$(Sys.MACHINE).c", read(cfile, String))
        cling = Cling_jll.cling_path
        cmd = "$cling --nologo -w $(join(cflags, " ")) < $cfile 2>/dev/null"
        cmd = `sh -c $cmd`
        @info cmd 

        output = split(String(read(cmd)), "(const char [12]) \"$delim\"\n"; keepempty=false)
        #@show output

        for x in output
            n, v = split(x, "\n")
            n = match(r"[(][^)]*[)].*\"([^\"]*)\"", n)[1]

            #@show x

            v = replace(v, r"^[(][(]anonymous[)][)][^:]*: *" => "")
            m = match(r"^[(](.*)[)] (.*)$", v)
            expr = nothing
            if m != nothing
                t, v = m[1], m[2]

                # Simple numeric types (e.g. int -> Cint).
                if t in keys(Generators.C_DATATYPE_TO_JULIA_DATATYPE)
                    t = Generators.C_DATATYPE_TO_JULIA_DATATYPE[t]

                # Pointer constants.
                elseif t == "void *"
                    if v == "nullptr"
                        expr = :(Base.C_NULL)
                    else
                        v = replace(v, r" <invalid memory address>" => "")
                        expr = Meta.parse("bitcast(Ptr{Cvoid}, UInt($v))")
                    end

                # Long floats not supported by Julia.
                elseif t == "long double"
                    @warn "long double is not supported" n t v
                    continue

                # String constants.
                elseif startswith(t, "const char [")
                    expr = :(String($v))

                # Function constants.
                elseif startswith(v, "Function")
                    m = match(r"@(.*)", v)
                    expr = Meta.parse("bitcast(Ptr{Cvoid}, UInt($(m[1])))")
                else
                    @error "Unknown type: $t" x n t v
                    continue
                end

                if t == :Float32
                    v = replace(v, r"f$" => "")
                end

                # '0x00' => 0x00
                if t == :Cchar && startswith(v, "'")
                    v = replace(v, "'" => "")
                end

                if expr == nothing
                    try
                        expr = Meta.parse("$t($v)")
                    catch err
                        @error err x n t v "$t($v)"
                        continue
                    end
                end
                #@show n, expr
                result[Symbol(n)] = expr

            elseif v != ""
                @error n v
            end
        end
    end
    result
end


using Clang.Generators

function parse_headers()

    headers = map(find_system_header, [
        "<errno.h>",
        "<string.h>",
        "<limits.h>",
        "<stdlib.h>",
        "<pthread.h>",
        "<sys/ioctl.h>",
        "<termios.h>",
        "<fcntl.h>",
        "<poll.h>",
        (Sys.islinux() ? ("<sys/epoll.h>",) : ())...,
        (Sys.isapple() ? ("<dispatch/dispatch.h>",) : ())...,
        (Sys.isapple() ? ("<sys/disk.h>",) : ())...,
        "<unistd.h>",
        "<sys/stat.h>",
        "<net/if.h>",
        "<sys/socket.h>",
        "<signal.h>",
        "<sys/wait.h>",
        "<sys/syscall.h>",
        "<spawn.h>",
    ])
    cflags = [
        ("-isystem$p" for p in system_include_path())...,
        "-D_REENTRANT",
        "-D_GNU_SOURCE",
        "-D_POSIX_SOURCE",
        "-D_DARWIN_C_SOURCE",
        "-D_POSIX_C_SOURCE=200809L"
    ]

    Generators.add_definition(:__builtin_va_list => Generators.JuliaUnsupported())
    Generators.add_definition(Symbol("") => Generators.JuliaUnsupported())

    ctx = Generators.create_context(headers, copy(cflags),
        Dict{String,Any}(
            "general" => Dict{String,Any}(
                "is_local_header_only" => false,
                "auto_mutability" => true,
                "auto_mutability_includelist" => ["termios"],
                "auto_mutability_ignorelist" => ["posix_spawnattr_t",
                                                 "__sigset_t"],
                "library_name" => ""
            ),
            "codegen" => Dict{String,Any}(
                "use_ccall_macro" => true,
                "wrap_variadic_function" => false
            ),
            "codegen.macro" => Dict{String,Any}(
                "macro_mode" => "aggressive",
                "ignore_pure_definition" => true
            )
        )
    )


    build!(ctx, BUILDSTAGE_NO_PRINTING)

    # Filter out symbols that break wrapper generation.
    nodes = filter(node -> node.id ∉ [
        :imaxdiv,           # imaxdiv_t missing ??
        :errno,             # not constant
        :wait,              # fn/struct clash
        :sigvec,            # "
        :if_nameindex,      # "
        :if_freenameindex,
        :MSG_TRYHARD
    ], ctx.dag.nodes)

    # Filter out macros begining with underscore.
    nodes = filter(node -> ! (node isa ExprNode{Generators.MacroDefault})
                        || ! startswith(string(node.id), "_"),
                   nodes)

    structs = filter(x -> (   x isa ExprNode{Generators.StructDefinition}
                           || x isa ExprNode{Generators.StructAnonymous})
                          && !startswith(string(x.id), "#"), nodes)
    struct_names = [(n.id for n in structs)...]

    simple_macros = filter(x -> x isa ExprNode{Generators.MacroDefault}, nodes)
    macro_names = [(n.id for n in simple_macros)...]

    macro_exprs = try
        open(deserialize, ".macro_exprs_cache.$(Sys.MACHINE)")
    catch e
        macro_exprs = macro_values(headers, cflags, macro_names, struct_names)
        open(".macro_exprs_cache.$(Sys.MACHINE)"; write=true) do io
            serialize(io, macro_exprs)
        end
        macro_exprs
    end

    exprs = [:(const $n = $(macro_exprs[n]))
             for n in filter(x -> endswith(string(x), "_size"),
                             keys(macro_exprs))]

    for node in simple_macros
        if node.id in keys(macro_exprs)
            old = copy(node.exprs)
            empty!(node.exprs)
            push!(node.exprs, :(const $(node.id) = $(macro_exprs[node.id])))
            #@info "replaced $(node.id) $old -> $(node.exprs)"
        else
            #@warn "not found $(node.id) $(typeof(node.id))" node.exprs
                
            toks = Generators.tokenize(node.cursor)
            empty!(node.exprs)
            push!(node.exprs, Generators.get_comment_expr(toks))
        end
    end

    # Fix `@cenum` expressions.
    for node in nodes
        if node isa ExprNode{<:AbstractEnumNodeType}
            let x = node.exprs[1]
                x = Expr(x.head, x.args..., Expr(:block, node.exprs[2:end]...))
                empty!(node.exprs)
                push!(node.exprs, x)
            end
        end
        append!(exprs, node.exprs)
    end

    exprs
end

macro include_headers()
    quote
        let exprs = UnixIOHeaders.parse_headers()
            write(joinpath(@__DIR__, "include_headers_dump.$(Sys.MACHINE).jl"),
                  join(string.(exprs), "\n"))
            #=
            for ex in exprs
                @show ex
                try
                    Base.eval(@__MODULE__, ex)
                catch err
                    @error err ex
                end
            end
            =#
            Base.eval(@__MODULE__, Expr(:block, exprs...))
            x = UnixIOHeaders.find_constants(@__MODULE__)
            Base.eval(@__MODULE__, :(const constants = $x))
        end
    end
end


function find_constants(m)
   result = Dict{Int,Vector{Symbol}}()
   for n in names(m; all=true)
       x = getfield(m, n)
       if x isa Integer
           names = get(result, x, Symbol[])
           if isempty(names)
               result[signed(x)] = names
           end
           push!(names, n)    
       end
   end
   result
end

    

baremodule C

import Base
using Base: @ccall, @generated,
            Cstring, Cchar, Cuchar,
            Cshort, Cushort,
            Cuint, Cint,
            Culong, Clong, 
            Clonglong, Culonglong,
            Cfloat, Cdouble,
            GC, Sys,
            Vector,
            signed,
            getproperty,
            unsafe_store!,
            (&), (-), (+), (*), (<<), (>>), (>), (==), (|), (~)

import Core.Intrinsics.bitcast

using CEnum

const NULL = 0
if Sys.isapple()
const __spawn_action = Cvoid
end

ioctl(fd, cmd, arg::Ref{T}) where T =
    @ccall ioctl(fd::Cint, cmd::Culong, arg::Ptr{T})::Cint


const __builtin_va_list = nothing

using ..UnixIOHeaders
UnixIOHeaders.@include_headers

const termios_m = termios
const tcgetattr_m = tcgetattr
const tcsetattr_m = tcsetattr

# Need Ptr{Ptr{UInt8}} not Ptr{String} for NULL-terminated string vectors:
execv(path, args::Vector{Ptr{UInt8}}) =
    @ccall execv(path::Ptr{UInt8}, args::Ptr{Ptr{UInt8}})::Cint

posix_spawn(pid, path, file_actions, attrp, argv::Vector{Ptr{UInt8}},
                                            envp::Vector{Ptr{UInt8}}) =
    @ccall posix_spawn(pid::Ptr{pid_t},
                       path::Cstring, 
                       file_actions::Ptr{posix_spawn_file_actions_t}, 
                       attrp::Ptr{posix_spawnattr_t},
                       argv::Ptr{Ptr{UInt8}},
                       envp::Ptr{Ptr{UInt8}})::Cint


# Signal wrongly wrapped as 3-args by CInclude.jl.
if Sys.isapple()
# FIXME     signal(sig, func) = @ccall signal(sig::Cint, func::sig_t)::sig_t
end
# FIXME const SIG_DFL = sig_t(0)
#
if Sys.isapple()
sigset_t() = sigset_t(0)
sigaddset(arg1, arg2) = @ccall sigaddset(arg1::Ptr{sigset_t}, arg2::Cint)::Cint
sigdelset(arg1, arg2) = @ccall sigdelset(arg1::Ptr{sigset_t}, arg2::Cint)::Cint
sigfillset(arg1) = @ccall sigfillset(arg1::Ptr{sigset_t})::Cint
sigemptyset(arg1) = @ccall sigemptyset(arg1::Ptr{sigset_t})::Cint
end


# Need multiple methods for `open` and `fcntl`:
open(pathname::AbstractString, flags) =
    @ccall open(pathname::Cstring, flags::Cint)::Cint

open(pathname::AbstractString, flags, mode) =
    @ccall open(pathname::Cstring, flags::Cint, mode::Cint)::Cint

fcntl(fd, cmd) = @ccall fcntl(fd::Cint, cmd::Cint)::Cint
fcntl(fd, cmd, arg) = @ccall fcntl(fd::Cint, cmd::Cint, arg::Cint)::Cint


#= FIXME
# Need variants for _m struct
tcsetattr_m(fd, action, p) =
    @ccall tcsetattr(fd::Cint, action::Cint, p::Ptr{termios_m})::Cint

tcgetattr_m(fd, p) =
    @ccall tcgetattr(fd::Cint, p::Ptr{termios_m})::Cint

cfsetspeed_m(p, speed) =
    @ccall cfsetspeed(p::Ptr{termios_m}, speed::speed_t)::Cint
    =#


# Not yet in glibc.
#const SYS_pidfd_open=434 # https://git.io/J4j1A
pidfd_open(pid, flags) = @ccall syscall(SYS_pidfd_open::Cint,
                                        pid::pid_t, flags::Cint)::Cint

#= FIXME
const P_PIDFD = 3
waitid(idtype, id, infop, options) = 
    @ccall syscall(SYS_waitid::Cint,
                   idtype::Cint,
                   id::id_t,
                   infop::Ptr{siginfo_t},
                   options::Cint,
                   Base.C_NULL::Ptr{Cvoid})::Cint
                   =#


# Function-like mactos not yet wrapped.
WIFSIGNALED(x) = (((x & 0x7f) + 1) >> 1) > 0
WTERMSIG(x) = (x & 0x7f)
WIFEXITED(x) = WTERMSIG(x) == 0
WEXITSTATUS(x) = signed(UInt8((x >> 8) & 0xff))
WIFSTOPPED(x) = (x & 0xff) == 0x7f
WSTOPSIG(x) = WEXITSTATUS(x)
WIFCONTINUED(x) = x == 0xffff
WCOREDUMP(x) = x & 0x80



end # baremodule C

end # module
