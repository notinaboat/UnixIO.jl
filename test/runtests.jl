using Test
using LoggingTestSets
using AsyncLog
using UnixIO
using UnixIO.IOTraits
using UnixIO: C

# FIXME use ReTest.jl
"""
# Test Cases to add

- Close while transfer is waiting.

"""
 

cd(@__DIR__)

@testset LoggingTestSet "UnixIO" begin

@testset LoggingTestSet "Open Type" begin

let f() = UnixIO.open(UnixIO.FDType, "foobar")
    info, type = code_typed(f, ())[1]
    @test type == DuplexIO{IOTraits.BaseIO{LazyBufferedInput{UnixIO.FD{UnixIO.In,UnixIO.FDType}}},
                           IOTraits.BaseIO{UnixIO.FD{UnixIO.Out,UnixIO.FDType}}}
end

let f() = UnixIO.open(UnixIO.FDType, "foobar", C.O_RDWR)
    info, type = code_typed(f, ())[1]
    @test type == DuplexIO{IOTraits.BaseIO{LazyBufferedInput{UnixIO.FD{UnixIO.In,UnixIO.FDType}}},
                           IOTraits.BaseIO{UnixIO.FD{UnixIO.Out,UnixIO.FDType}}}
end

let f() = UnixIO.open(UnixIO.FDType, "foobar", C.O_RDONLY)
    info, type = code_typed(f, ())[1]
    @test type == IOTraits.BaseIO{LazyBufferedInput{UnixIO.FD{UnixIO.In,UnixIO.FDType}}}
end

let f() = UnixIO.open(UnixIO.FDType, "foobar", C.O_WRONLY)
    info, type = code_typed(f, ())[1]
    @test type == IOTraits.BaseIO{UnixIO.FD{UnixIO.Out,UnixIO.FDType}}
end

end # testset

@info "Test read(::Cmd)"
@test UnixIO.read(`uname -a`) ==
             read(`uname -a`)


@info "Test open, readline, read, readbytes!, eof, isopen (with file)"
jio = open("runtests.jl")
uio = UnixIO.open("runtests.jl")

@test readline(jio) == readline(uio)
@test read(jio, UInt8) == read(uio, UInt8)
@test read(jio, UInt32) == read(uio, UInt32)
@info "Test readline"
@test readline(jio) == readline(uio)
@info "Test readbytes(2)"
jv = UInt8[]; readbytes!(jio, jv, 2)
uv = UInt8[]; readbytes!(uio, uv, 2)
@test jv == uv
@info "Test readbytes(100)"
jv = UInt8[]; readbytes!(jio, jv, 100)
@show typeof(uio) typeof(uv)
@show which(readbytes!, (typeof(uio), typeof(uv), Int))
uv = UInt8[]; readbytes!(uio, uv, 100)
@show length(jv), length(uv)
@show String(copy(jv)), String(copy(uv))
@test jv == uv
@info "Test readbytes(100)"
readbytes!(jio, jv, 100)
readbytes!(uio, uv, 100)
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
        c = UnixIO.read(`hexdump $f`)
        d = UnixIO.open(`hexdump`) do cin, cout
            cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
            cin=IOTraits.BaseIO(cin)
            @sync begin
                @async try
                    write(cin, UnixIO.open(f))
                    close(cin)
                catch err
                    UnixIO.printerr("ERROR: $err")
                    exception=(err, catch_backtrace())
                    UnixIO.printerr(exception)
                    @error "ERROR" exception
                end
                read(cout)
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
uio = UnixIO.open("runtests.jl")

@test [x for x in eachline(jio)] ==
      [x for x in eachline(uio)]


@info "Test open(:Cmd) using fork/exec"
@test UnixIO.open(`hexdump`; fork=true) do cmdin, cmdout
    cmdin = IOTraits.BaseIO(cmdin) # FIXME
    cmdout = IOTraits.BaseIO(cmdout) # FIXME
    @sync begin
        @async try
            write(cmdin, read(UnixIO.open("runtests.jl")))
            close(cmdin)
        catch err
            UnixIO.printerr("ERROR: $err")
            exception=(err, catch_backtrace())
            UnixIO.printerr(exception)
            @error "ERROR" exception
        end
        read(cmdout)
    end
end ==
open(`hexdump`, open("runtests.jl"); read = true) do io
    read(io)
end

        
@info "Test read(`hexdump`)"
@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)


cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@info "Test open($cmd)"
@test UnixIO.open(cmd) do i, o collect(eachline(IOTraits.BaseIO(IOTraits.LazyBufferedInput(o)))) end == 
    open(cmd; read = true) do io collect(eachline(io)) end


@info "Test @async read(::Cmd) with delay"
results = []
@sync for i in 1:5
    @async try
        push!(results, (i, UnixIO.read(`bash -c "sleep 2; echo $i"`, String)))
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
@test UnixIO.read(`bash -c "echo FOO; sleep 4; echo FOO"`,
                  String; timeout=2.4) == "FOO\n"

times = []
@sync for i in 1:4
    @async try
        t0 = time()
        UnixIO.read(`bash -c "sleep 4; echo FOO"`, String; timeout=2.4)
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
cmdout = IOTraits.LazyBufferedInput(cmdout)
@test !isempty(UnixIO.processes)
@test readline(cmdout) != ""
@test readline(cmdout) != ""
@test readline(cmdout) != ""


@info "Test sub-process cleanup."
close(cmdout)
sleep(1)
@test isempty(UnixIO.processes)


include("pseudoterminal.jl")



end #testset
