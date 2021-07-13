using Test
using UnixIO

cd(@__DIR__)

@testset "UnixIO" begin


@test UnixIO.read(`uname -a`) ==
             read(`uname -a`)


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
@test isopen(jio) == isopen(uio)
@test close(jio) == close(uio)
@test isopen(jio) == isopen(uio)

UnixIO.system(`dd if=/dev/urandom of=testdata bs=1024 count=1000`)
@test read(`hexdump testdata`) == UnixIO.read(`hexdump testdata`)

jio = open("runtests.jl")
uio = UnixIO.open("runtests.jl")

@test [x for x in eachline(jio)] ==
      [x for x in eachline(uio)]

@test UnixIO.open(`hexdump`) do io
    write(io, read(UnixIO.open("runtests.jl")))
    UnixIO.shutdown(io)
    read(io)
end ==
open(`hexdump`, open("runtests.jl"); read = true) do io
    read(io)
end
        
@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)

@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)

cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@test UnixIO.open(cmd) do io collect(eachline(io)) end == 
    open(cmd; read = true) do io collect(eachline(io)) end

@sync for i in 1:5
    @async @test UnixIO.read(`bash -c "sleep 2; echo $i"`, String) == "$i\n"
end

@test_throws UnixIO.ReadTimeoutError begin
    UnixIO.read(`bash -c "sleep 4; echo FOO"`, String; timeout=2.4)
end
t0 = time()
try
    UnixIO.read(`bash -c "sleep 4; echo FOO"`, String; timeout=2.4)
catch
end
@test abs((time() - t0) - 2.4) < 0.1

sleep(1)
@test isempty(UnixIO.child_pids)
io = UnixIO.open(`bash -c "while true; do date ; sleep 1; done"`)
@test !isempty(UnixIO.child_pids)
@test readline(io) != ""
@test readline(io) != ""
@test readline(io) != ""
close(io)
sleep(1)
@test isempty(UnixIO.child_pids)


end #testset
