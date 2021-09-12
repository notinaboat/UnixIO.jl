# IO Info

using InteractiveUtils

function io_method_info(T, io, methods)

    rows = []
    push!(rows, ["Function", "Args", "File", "Method"])

    for (m, argt) in methods
        astr = join((string(t) for t in argt), ", ")
        try
            w = which(m, (T, argt...))
            file = string(basename(string(w.file)), ":", w.line)
            w = replace(string(w), r" in [A-Za-z]+.*$" => "")
            push!(rows, [string(m), astr, file, w])
        catch err
            push!(rows, [string(m), astr, "⚠️", string(err)])
            if io != nothing
                try
                    args = []
                    for t in argt
                        if t <: Type
                            push!(args, t.parameters[1])
                        elseif t <: Integer
                            push!(args, 7)
                        else
                            push!(args, t())
                        end
                    end
                    eval(:($m($io, $args...)))
                catch err
                    lines = split(sprint(showerror, err), "\n")
                    for line in lines
                        push!(rows, ["", "", "", line])
                    end
                end
            end
        end
    end

    Markdown.Table(rows, [:r, :l, :l, :l])
end

ioinfo(io) = ioinfo(typeof(io), io)
function ioinfo(T::Type, io=nothing)

    content = []

    push!(content, md"## IO Traits")
    rows = []
    push!(rows, ["Trait", "Value"])
    for f in [
        TransferDirection
        TotalSize
        TransferSize
        ReadFragmentation
        WaitingMechanism
    ]
        push!(rows, [string(f), string(f(T))])
    end

    push!(content, Markdown.Table(rows, [:l, :l, :l]))

    push!(content, md"## Core Read Methods")
    push!(content, io_method_info(T, io, [

        (Base.isreadable, ())
        (Base.read, (Type{UInt8},))
        (Base.unsafe_read, (Ptr{UInt8}, UInt))
        (Base.eof, ())
        (Base.reseteof, ())
        (Base.peek, ())
        (Base.peek, (Type{UInt8},))
        (Base.peek, (Type{Int},))
    ]))

    push!(content, md"## Core Write Methods")
    push!(content, io_method_info(T, io, [
        (Base.iswritable, ())
        (Base.write, (UInt8,))
        (Base.unsafe_write, (Ptr{UInt8}, UInt))
        (Base.flush, ())
    ]))

    push!(content, md"## State Methods")
    push!(content, io_method_info(T, io, [
        (Base.close, ())
        (Base.isopen, ())
        (Base.lock, ())
        (Base.unlock, ())
    ]))

    push!(content, md"## Cursor Methods")
    push!(content, io_method_info(T, io, [
        (Base.skip, (Integer,))
        (Base.seek, (Integer,))
        (Base.position, ())
        (Base.seekstart, ())
        (Base.seekend, ())
        (Base.mark, ())
        (Base.unmark, ())
        (Base.reset, ())
        (Base.ismarked, ())
    ]))

    push!(content, md"## Extra Read Methods")
    push!(content, io_method_info(T, io, [
        (Base.bytesavailable, ())
        (max_transfer_size, ())
        (Base.readavailable, ())
        (Base.readline, ())
        (Base.read, (Type{Int},))
        (Base.read, (Type{String},))
        (Base.read, (Integer,))
        (Base.readbytes!, (Vector{UInt8},))
        (Base.readbytes!, (AbstractVector{UInt8}, Number))
        (Base.read!, (AbstractArray,))
        (Base.readuntil, (Any,))
        (Base.countlines, ())
        (Base.eachline, ())
        (Base.readeach, (Type{Char},))
        (Base.readeach, (Type{Int},))
        (Base.readeach, (Type{UInt8},))
    ]))


    Markdown.MD(content)
end

function dump_info()
    println(md"""
    # Method Resolution Info
    
    ## BufferedIn
    $(ioinfo(BufferedIn(NullIn())))

    ## NullIn
    $(ioinfo(NullIn()))
    """)
end
