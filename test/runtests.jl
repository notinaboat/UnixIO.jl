using Test
using LoggingTestSets
using AsyncLog
using UnixIO
using UnixIO: C

"""
# Test Cases to add

- Close while transfer is waiting.

"""
 

cd(@__DIR__)

@testset LoggingTestSet "UnixIO" begin


@info "Test read(::Cmd)"
@test UnixIO.read(`uname -a`) ==
             read(`uname -a`)


@info "Test open, readline, read, readbytes!, eof, isopen (with file)"
jio = open("runtests.jl")
uio = UnixIO.open("runtests.jl")

@test readline(jio) == readline(uio)
@test read(jio, UInt8) == read(uio, UInt8)
@test read(jio, UInt32) == read(uio, UInt32)
@test readline(jio) == readline(uio)
jv = UInt8[]; readbytes!(jio, jv, 2)
uv = UInt8[]; readbytes!(uio, uv, 2)
@test jv == uv
jv = UInt8[]; readbytes!(jio, jv, 100)
uv = UInt8[]; readbytes!(uio, uv, 100)
@test jv == uv
readbytes!(jio, jv, 100)
readbytes!(uio, uv, 100)
@test jv == uv
@test read(jio) == read(uio)
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
            @sync begin
                @async begin
                    write(cin, UnixIO.open(f))
                    close(cin)
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


@info "Test open(:Cmd)"
@test UnixIO.open(`hexdump`) do cmdin, cmdout
    @async begin
        write(cmdin, read(UnixIO.open("runtests.jl")))
        close(cmdin)
    end
    read(cmdout)
end ==
open(`hexdump`, open("runtests.jl"); read = true) do io
    read(io)
end

        
@info "Test read(`hexdump`)"
@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)


cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@info "Test open($cmd)"
@test UnixIO.open(cmd) do i, o collect(eachline(o)) end == 
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
