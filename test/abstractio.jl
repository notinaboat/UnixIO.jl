using Test
using LoggingTestSets
using AsyncLog
using UnixIO
using Preconditions
using UnixIO.IOTraits
using UnixIO: C

-->(a,b) = transferall!(a=>b)
const URI = IOTraits.URI


# FIXME use ReTest.jl
"""
# Test Cases to add

- Close while transfer is waiting.

"""


cd(@__DIR__)

@testset LoggingTestSet "UnixIO" begin


v = Vector{Vector{UInt8}}()
`bash -c "echo FOO; sleep 1; echo BAR; sleep 0.1; echo FUM"` --> v
@test String.(v) == ["FOO\n", "BAR\n", "FUM\n"]

v = Vector{String}()
`bash -c "echo FOO; sleep 1; echo BAR; sleep 0.1; echo FUM"` --> v
@test v == ["FOO\n", "BAR\n", "FUM\n"]

v = Vector{Vector{UInt8}}()
`bash -c "echo FOO; sleep 1; echo BAR; sleep 0.1; echo FUM"` --> v
@test String(vcat(v...)) == "FOO\nBAR\nFUM\n"

v = Vector{String}()
s = IOTraits.openread(`bash -c "echo FOO; sleep 1; echo BAR; sleep 0.1; echo FUM"`)
@test transfer!(s => v) == 1
@test v == ["FOO\n"]
@test transfer!(s => v) == 1
@test v == ["FOO\n", "BAR\n"]
@test transfer!(s => v) == 1
@test v == ["FOO\n", "BAR\n", "FUM\n"]
close(s)


@testset LoggingTestSet "Open Type" begin

let f() = IOTraits.openread(UnixIO.FDType, "foobar")
    info, type = code_typed(f, ())[1]
    @test type == UnixIO.FD{IOTraits.In,UnixIO.FDType,TransferMode{:Immediate}}
end

let f() = IOTraits.openwrite(UnixIO.FDType, "foobar")
    info, type = code_typed(f, ())[1]
    @test type == UnixIO.FD{IOTraits.Out,UnixIO.FDType,TransferMode{:Immediate}}
end

end # testset

@info "Test open(cmd) -> Channel"
c = Channel{NTuple{3,UInt8}}()
cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@asynclog "UnixIO.open(::Cmd)" UnixIO.open(cmd) do i, o
    close(i)
    try
        while !IOTraits.isfinished(o)
            n = transfer!(o => c)#; timeout=2)
            if !IOTraits.isfinished(o) && !IOTraits.isconnected(o) && n == 0
                @warn "disconnected with $(bytesavailable(o)) bytes buffered!"
                break
            end
        end
    finally
        close(c)
    end
end

@test Iterators.flatten(c) |> collect |> String == "FOO\nBA"


c = Channel{Vector{UInt8}}()
cmd = `bash -c "echo FOO; sleep 1; echo BAR; sleep 0.1; echo FUM"`
@asynclog "UnixIO.open(::Cmd)" UnixIO.open(cmd) do i, o
    close(i)
    try
        while !IOTraits.isfinished(o)
            n = transfer!(o => c)
        end
    finally
        close(c)
    end
end

@test String.(collect(c)) == ["FOO\n", "BAR\n", "FUM\n"]


c = Channel{String}()
cmd = `bash -c "echo FOO; sleep 1; echo BAR; sleep 0.1; echo FUM"`
@asynclog "UnixIO.open(::Cmd)" UnixIO.open(cmd) do i, o
    close(i)
    try
        while !IOTraits.isfinished(o)
            n = transfer!(o => c, 3)
        end
    finally
        close(c)
    end
end

@test collect(c) == ["FOO\n", "BAR\n", "FUM\n"]

@info "Test FromTake()"
c = Channel{String}()
@asynclog "FromPop test" begin
    put!(c, "ONE")
    sleep(0.1)
    put!(c, "TWO")
    sleep(0.1)
    put!(c, "THREE")
    close(c)
end
mktempdir() do d
    out = IOTraits.openwrite("$d/tmp")
    try
        transfer!(c => out)
    finally
        close(out)
    end
    @test read("$d/tmp", String) == "ONETWOTHREE"
end

@info "Test FromSet()"
c = Set{String}()
push!(c, "ONE\n")
push!(c, "TWO\n")
push!(c, "THREE\n")
mktempdir() do d
    out = IOTraits.openwrite("$d/tmp")
    try
        transfer!(c => out)
    finally
        close(out)
    end
    @test readall!(IOTraits.openread("$d/tmp")) |> String |> split |> sort ==
          sort(["ONE", "TWO", "THREE"])
end



@info "Test system()"
mktempdir() do d
    UnixIO.system("echo foo > $d/out")
    @test IOTraits.openread("$d/out") |> readall! |> String == "foo\n"
    UnixIO.system("uname -a > $d/out")
    uname = IOTraits.openread("$d/out") |> readall! |> String 
    @test UnixIO.read(`uname -a`, String) == uname
end

@info "Test sh\"...\""
@test sh"echo hello" == "hello"

@info "Test read(::Cmd)"
@test UnixIO.read(`uname -a`, String) |> chomp == sh"uname -a"


@info "Test pread()"
mktempdir() do d
    in, out = UnixIO.openreadwrite("$d/foo")
    try
        transfer!("Hello" => out) 
        v = Vector{UInt8}(undef, 5)
        transfer!(in => v)
        @test String(v) == "Hello"

        transfer!("FooBar" => out; start=(1=>512))
        v = Vector{UInt8}(undef, 5)
        transfer!(in => v; start=(512=>1))
        @test String(v) == "FooBa"

        v = Vector{UInt8}(undef, 5)
        transfer!(in => v; start=(1=>1))
        @test String(v) == "Hello"
    finally
        close(in)
        close(out)
    end
end


@info "Test pread()"
mktempdir() do d
    io = UnixIO.openreadwrite("$d/foo")
    try
        transfer!("Hello" => io) 
        v = Vector{UInt8}(undef, 5)
        transfer!(io => v)
        @test String(v) == "Hello"

        transfer!("FooBar" => io; start=(1=>512))
        v = Vector{UInt8}(undef, 5)
        transfer!(io => v; start=(512=>1))
        @test String(v) == "FooBa"

        v = Vector{UInt8}(undef, 5)
        transfer!(io => v; start=(1=>1))
        @test String(v) == "Hello"
    finally
        close(io)
    end
end

@info "Test open, readline, read, readbytes!, eof, isopen (with file)"
jio = open("runtests.jl")
uio = LazyBufferedInput(IOTraits.openread("runtests.jl"))

@test readline(jio) == readline(uio)
@test read(jio, UInt8) == IOTraits.readbyte(uio)
@test read(jio, UInt32) == read(uio, UInt32)
@info "Test readline"
@test readline(jio) == readline(uio)
@info "Test readbytes(2)"
jv = UInt8[]; readbytes!(jio, jv, 2)
uv = Vector{UInt8}(undef, 2); transfer!(uio => uv)
@test jv == uv
@info "Test readbytes(100)"
jv = UInt8[]; readbytes!(jio, jv, 100)
uv = read(uio, 100)
@test jv == uv
@info "Test read(100)"
jv = read(jio, 100)
uv = read(uio, 100)
@test jv == uv
@info "Test read"
@test read(jio) == read(uio)
@info "Test eof"
@test eof(jio) == eof(uio)
@test isopen(jio) == isopen(uio)
@test close(jio) == close(uio)
@test eof(jio) == eof(uio)
@test isopen(jio) == isopen(uio)

@info "Test system() and read(::Cmd) with large data"
for _ in 1:1
    mktempdir() do d
        f = joinpath(d, "testdata")
        UnixIO.system("dd if=/dev/urandom of=$f bs=1024 count=10000 " *
                      "> /dev/null 2>&1")
        @test stat(f).size == 1024 * 10000
        UnixIO.system("hexdump $f > $f.hex")

        a = read("$f.hex")
        b = read(`hexdump $f`) 
        c = readall!(`hexdump $f`)
        @time d = UnixIO.open(`hexdump`) do cin, cout
            @sync begin
                @async try
                    IOTraits.URI(f) --> cin
                    close(cin)
                catch err
                    UnixIO.printerr("ERROR: $err")
                    exception=(err, catch_backtrace())
                    UnixIO.printerr(exception)
                    @error "ERROR" exception
                end
                readall!(cout)
            end
        end
                
        @test b == a
        @test c == a
        @test d == a
        if a != c
            @show length(a) length(b) length(c)
            a = String(a)
            b = String(b)
            c = String(c)
            @show a[1:100] a[end-100:end]
            @show b[1:100] b[end-100:end]
            @show c[1:100] c[end-100:end]
        end
    end
end



@info "Test eachline()"
jio = open("runtests.jl")
uio = IOTraits.openread("runtests.jl")

@test [x for x in eachline(jio)] ==
      [x for x in eachline(IOTraits.BaseIO(uio))]



@info "Test open(:Cmd) using fork/exec"
@test UnixIO.open(`hexdump`; fork=true) do cmdin, cmdout
    @show cmdin cmdout
    @sync begin
        @async try
            URI("runtests.jl") --> cmdin
            close(cmdin)
        catch err
            UnixIO.printerr("ERROR: $err")
            exception=(err, catch_backtrace())
            UnixIO.printerr(exception)
            @error "ERROR" exception
        end
        readall!(cmdout)
    end
end ==
open(`hexdump`, open("runtests.jl"); read = true) do io
    read(io)
end

@info "Test read(`hexdump`)"
@test readall!(`hexdump runtests.jl`) ==
      Base.read(`hexdump runtests.jl`)


cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@info "Test open($cmd)"
@test UnixIO.open(cmd) do i, o collect(eachline(o)) end == 
    open(cmd; read = true) do io collect(eachline(io)) end


@info "Test @async read(::Cmd) with delay"
results = []
@sync for i in 1:5
    @async try
        push!(results, (i, readall!(`bash -c "sleep 2; echo $i"`) |> String))
    catch err
        UnixIO.printerr("ERROR: $err")
        exception=(err, catch_backtrace())
        UnixIO.printerr(exception)
        @error "ERROR" exception
    end
end
for (i, r) in results
    @test r == "$i\n"
end

@info "Test read(::Cmd) with timeout."
@test readall!(`bash -c "echo FOO; sleep 4; echo FOO"`, timeout=2.4) |>
    String == "FOO\n"


times = []
@sync for i in 1:4
    @async try
        t0 = time()
        readall!(`bash -c "sleep 4; echo FOO"`; timeout=2.4)
        push!(times, time() - t0)
    catch err
        UnixIO.printerr("ERROR: $err")
        exception=(err, catch_backtrace())
        UnixIO.printerr(exception)
        @error "ERROR" exception
    end
end
@show times
for t in times
    @test abs(t - 2.4) < 0.2
end


@info "Test open(::Cmd) -> cin, cout."
sleep(1)
@test isempty(UnixIO.processes)
cmdin, cmdout = UnixIO.open(`bash -c "while true; do date ; sleep 1; done"`)
close(cmdin)
@test !isempty(UnixIO.processes)
@test readline(cmdout) != ""
@test readline(cmdout) != ""
@test readline(cmdout) != ""


@info "Test sub-process cleanup."
close(cmdout)
sleep(1)
@test isempty(UnixIO.processes)


end #testset
