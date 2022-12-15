using Test
using LoggingTestSets
using AsyncLog
using UnixIO
using UnixIO.IOTraits
using UnixIO: C

@show UnixIO.IOTraits.WaitAPI(UnixIO.FD{UnixIO.In, UnixIO.Stream})
@show UnixIO.IOTraits.WaitAPI(UnixIO.FD{UnixIO.In, UnixIO.File})
@show UnixIO.IOTraits.TransferAPI(UnixIO.FD{UnixIO.In, UnixIO.Stream})
@show UnixIO.IOTraits.TransferAPI(UnixIO.FD{UnixIO.In, UnixIO.File})

cd(@__DIR__)

slowfs_dir = Sys.isapple() ? "macos_slowfs" :
             Sys.islinux() ? "linux_slowfs" : @assert false

cd(slowfs_dir) do
    UnixIO.system(`make mount`)
end

@testset LoggingTestSet "Slow FS" begin

    t0 = nothing
    for x in 1:2
        t0 = time()
        @time @sync for f in ["A", "B", "C", "D", "E", "F"]
            @async begin
                io = UnixIO.open("slowfs_mount/$f")
                if x == 2 && f == "A"
                    @show typeof(io.in.stream)
                    @show UnixIO.IOTraits.WaitAPI(io.in.stream)
                    @show UnixIO.IOTraits.TransferMode(io.in.stream)
                    @show UnixIO.IOTraits.TransferAPI(io.in.stream)
                end
                try
                    x == 1 || @show read(io, String)
                finally
                    close(io)
                end
            end
            x == 2 || break
        end
    end
    @test time() - t0 < 4

end #testset

@testset LoggingTestSet "Slow FS - Disable AsyncTransfer" begin

    t0 = nothing
    for x in 1:2
        t0 = time()
        @time @sync for f in ["A", "B", "C", "D", "E", "F"]
            @async begin
                io = UnixIO.open("slowfs_mount/$f";
                                 transfer_mode=UnixIO.IOTraits.ImmediateTransfer)
                if x == 2 && f == "A"
                    @show typeof(io.in.stream)
                    @show UnixIO.IOTraits.WaitAPI(io.in.stream)
                    @show UnixIO.IOTraits.TransferMode(io.in.stream)
                    @show UnixIO.IOTraits.TransferAPI(io.in.stream)
                end
                try
                    x == 1 || @show read(io, String)
                finally
                    close(io)
                end
            end
            x == 2 || break
        end
    end
    @test time() - t0 > 6

end #testset

@testset LoggingTestSet "Slow FS - BlockingTransfer" begin

    t0 = nothing
    for x in 1:2
        t0 = time()
        @time @sync for f in ["A", "B", "C", "D", "E", "F"]
            @async begin
                io = UnixIO.open("slowfs_mount/$f";
                                 transfer_mode=UnixIO.IOTraits.BlockingTransfer)
                if x == 2 && f == "A"
                    @show typeof(io.in.stream)
                    @show UnixIO.IOTraits.WaitAPI(io.in.stream)
                    @show UnixIO.IOTraits.TransferMode(io.in.stream)
                    @show UnixIO.IOTraits.TransferAPI(io.in.stream)
                end
                try
                    x == 1 || @show read(io, String)
                finally
                    close(io)
                end
            end
            x == 2 || break
        end
    end
    @test time() - t0 > 6

end #testset


cd(slowfs_dir) do
    UnixIO.system(`make umount`)
end
