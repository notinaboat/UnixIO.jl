using Test
using UnixIO

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
@test close(jio) == close(uio)

jio = open("runtests.jl")
uio = UnixIO.open("runtests.jl")

@test [x for x in eachline(jio)] ==
      [x for x in eachline(uio)]

@test UnixIO.open(`hexdump`) do io
    write(io, read(UnixIO.open("runtests.jl")))
    UnixIO.shutdown_write(io)
    read(io)
end ==
open(`hexdump`, open("runtests.jl"); read = true) do io
    read(io)
end
        
@test UnixIO.read(`hexdump runtests.jl`) ==
             read(`hexdump runtests.jl`)

cmd = `bash -c "echo FOO; sleep 1; echo BAR"`
@test UnixIO.open(cmd) do io collect(eachline(io)) end == 
    open(cmd; read = true) do io collect(eachline(io)) end