using Test
using UnixIO

# FIXME
 
#= readline returns parital line

julia> buf = PipeBuffer()
julia> write(buf, "foobar\nxx")
julia> readline(buf)
"foobar"

julia> readline(buf)
"xx"
=# 

#=

Test that readline from /dev/pts reads one line per read(2) call
even if many lines are written at once.

=# 

cd(@__DIR__)

@testset "UnixIO" begin

include("pseudoterminal.jl")

#for mode in ["poll(2)", "epoll(7)", "sleep(0.1)"]

#@testset "UnixIO $mode" begin

#if (!Sys.islinux()) && mode == "epoll(7)"
#    continue
#end
#UnixIO.enable_dumb_polling[] = mode == "sleep(0.1)"
#UnixIO.enable_epoll[] = mode == "epoll(7)"

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
@test eof(jio) == eof(uio)
@test isopen(jio) == isopen(uio)
@test close(jio) == close(uio)
@test eof(jio) == eof(uio)
@test isopen(jio) == isopen(uio)


UnixIO.system(`dd if=/dev/urandom of=testdata bs=1024 count=1000`)
@test read(`hexdump testdata`) == UnixIO.read(`hexdump testdata`)

jio = open("runtests.jl")
uio = UnixIO.open("runtests.jl")

@test [x for x in eachline(jio)] ==
      [x for x in eachline(uio)]

@test UnixIO.open(`hexdump` ) do cmdin, cmdout
    @async begin
        write(cmdin, read(UnixIO.open("runtests.jl")))
        close(cmdin)
    end
    read(cmdout)
end ==
open(`hexdump`, open("runtests.jl"); read = true) do io
    read(io)
end

        
@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)

@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)

cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@test UnixIO.open(cmd) do i, o collect(eachline(o)) end == 
    open(cmd; read = true) do io collect(eachline(io)) end

@sync for i in 1:5
    @async @test UnixIO.read(`bash -c "sleep 2; echo $i"`, String) == "$i\n"
end

@test UnixIO.read(`bash -c "echo FOO; sleep 4; echo FOO"`,
                  String; timeout=2.4) == "FOO\n"
t0 = time()
try
    UnixIO.read(`bash -c "sleep 4; echo FOO"`, String; timeout=2.4)
catch
end
@test abs((time() - t0) - 2.4) < 0.2

sleep(1)
@test isempty(UnixIO.processes)
cmdin, cmdout = UnixIO.open(`bash -c "while true; do date ; sleep 1; done"`)
close(cmdin)
@test !isempty(UnixIO.processes)
@test readline(cmdout) != ""
@test readline(cmdout) != ""
@test readline(cmdout) != ""
close(cmdout)
sleep(5)
@test isempty(UnixIO.processes)


#end #testset

#end #for mode

end #testset
