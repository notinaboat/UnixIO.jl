using Test
using LoggingTestSets
using AsyncLog
using UnixIO
using UnixIO.IOTraits
using UnixIO: C

@show UnixIO.IOTraits.WaitingMechanism(UnixIO.FD{UnixIO.In, UnixIO.Stream})
@show UnixIO.IOTraits.WaitingMechanism(UnixIO.FD{UnixIO.In, UnixIO.File})
@show UnixIO.IOTraits.TransferMechanism(UnixIO.FD{UnixIO.In, UnixIO.Stream})
@show UnixIO.IOTraits.TransferMechanism(UnixIO.FD{UnixIO.In, UnixIO.File})

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
                try
                    @show read(io, String)
                finally
                    close(io)
                end
            end
        end
    end
    @test time() - t0 < 3

end #testset


cd(slowfs_dir) do
    UnixIO.system(`make umount`)
end
