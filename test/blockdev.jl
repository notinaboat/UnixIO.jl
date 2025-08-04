using Test
using LoggingTestSets
using AsyncLog
using UnixIO
using UnixIO.IOTraits
using UnixIO: C
using IOTraits: blocksize, transfer!
using PLists

if Sys.isapple()
bd = sh"hdiutil attach -nobrowse -nomount ram://100" |> rstrip
bd_info(f=bd) = read_xml_plist_string(String(sh"diskutil information -plist $f"))
atexit(()->UnixIO.system("hdiutil eject $bd"))


@testset "Block Device" begin

    @info "Test block device: $bd" bd_info()["Size"] bd_info()["DeviceBlockSize"]

    io = UnixIO.open(bd)
    fdin = io.in.stream.stream
    fdout = io.out.stream
    @show fdin
    @show fdout
    try

        @test length(fdin) == bd_info()["Size"] 
        @test blocksize(fdout) == bd_info()["DeviceBlockSize"]

        transfer!("Hello" => fdout) 
        v = Vector{UInt8}(undef, 5)
        transfer!(fdin => v)
        @test String(v) == "Hello"

        transfer!("FooBar" => fdout; start=(1=>512))
        v = Vector{UInt8}(undef, 5)
        transfer!(fdin => v; start=(512=>1))
        @test String(v) == "FooBa"

        v = Vector{UInt8}(undef, 5)
        transfer!(fdin => v; start=(1=>1))
        @test String(v) == "Hello"

    finally 
        close(io)
    end

end #testset

end #Sys.isapple()

