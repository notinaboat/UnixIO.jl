using Test
using IOTraits
using SparseArrays
using DataStructures
using IOTraits: In, Out

mutable struct TestStream{Av} <: IOTraits.Stream
    isopen::Bool
    chunk::Vector{UInt8}
    chunks::Vector{Vector{UInt8}}
    TestStream{Av}(chunks) where Av =
        new{Av}(true, chunks[1], [Vector{UInt8}(chunk) for chunk in chunks[2:end]])
end

IOTraits.Availability(::Type{TestStream{Av}}) where Av = Av()

Base.isopen(s::TestStream) = s.isopen
IOTraits.TransferDirection(::Type{<:TestStream}) = In()


Base.bytesavailable(s::TestStream{PartiallyAvailable}) = length(s.chunk)

function advance!(s::TestStream)
    isempty(s.chunks) || (s.chunk = [s.chunk; popfirst!(s.chunks)])
    @warn "advance!: $s"
end
advance!(s::IOTraits.GenericBufferedInput) = advance!(s.stream)
advance!(s::IOTraits.TimeoutStream) = advance!(s.stream)


test_streams(chunks) = [
    TestStream{PartiallyAvailable}(chunks),
    TestStream{UnknownAvailability}(chunks),
    IOTraits.timeout_stream(TestStream{PartiallyAvailable}(chunks); timeout=100),
    IOTraits.timeout_stream(TestStream{UnknownAvailability}(chunks); timeout=100),
    BufferedInput(TestStream{PartiallyAvailable}(chunks)),
    LazyBufferedInput(TestStream{PartiallyAvailable}(chunks)),
    BufferedInput(TestStream{UnknownAvailability}(chunks)),
    LazyBufferedInput(TestStream{UnknownAvailability}(chunks))
]


function IOTraits.unsafe_transfer(s::TestStream, ::In, buf::Ptr{UInt8}, n::UInt)
    @assert n > 0
    if isempty(s.chunk)
        return UInt(0)
    end
    n::UInt = min(length(s.chunk), n)
    unsafe_copyto!(buf, pointer(s.chunk), n)
    s.chunk = s.chunk[n+1:end]
    if isempty(s.chunk) && !isempty(s.chunks)
        s.chunk = popfirst!(s.chunks)
    end
    return n
end


chunks = ([1,2,3], [4,5,6])


@testset "Transfer Direction" begin

    for s in test_streams(chunks)
        @show s
        @test TransferDirection(s) == In()
    end
end



@testset "Simple transfer" begin

    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))"
            v = zeros(UInt8, 5)
            @test transfer(s => v) == 3
            @test v == [1,2,3,0,0]
            @test transfer(s => v) == 3
            @test v == [4,5,6,0,0]
        end
    end
end


@testset "Simple transferall" begin
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))"
            v = zeros(UInt8, 5)
            @test transferall(s => v) == 5
            @test v == [1,2,3,4,5]
            @test transferall(s => v) == 1
            @test v == [6,2,3,4,5]
        end
    end
end


@testset "Transfer to Ref" begin
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))"
            @info "$(Availability(s))"
            v = Ref{UInt16}()
            @test transfer(s => v) == 1
            @test v[] == 0x0201
            if Availability(s) != UnknownAvailability()
                if !(s isa IOTraits.BufferedInput)
                    @test transfer(s => v) == 0
                    advance!(s)
                end
            end
            @test transfer(s => v) == 1
            @test v[] == 0x0403
            @test transfer(s => v) == 1
            @test v[] == 0x0605
        end
    end
end


@testset "Transfer to IO" begin
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))"
            v = IOBuffer()
            @test transfer(s => v, 1) == 1
            @test take!(v) == [1]
            @test transfer(s => v) == 5
            @test take!(v) == [2,3,4,5,6]
        end
    end
end


@testset "Non-byte transfer" begin
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))" Availability(s)
            v = zeros(UInt16, 2)
            if Availability(s) == UnknownAvailability()
                @test transfer(s => v) == 2
                @test v == [0x0201, 0x0403]
                @test transfer(s => v) == 1
                @test v == [0x0605, 0x0403]
            else
                @test transfer(s => v) == 1
                @test v == [0x0201, 0x0000]
                if !(s isa IOTraits.BufferedInput)
                    @test transfer(s => v) == 0
                    advance!(s)
                end
                @test transfer(s => v) == 2
                @test v == [0x0403, 0x0605]
            end
        end
    end
end

@testset "Non pointer-compatible Vector transfer" begin
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))" Availability(s)
            v = sparsevec([1,2], UInt16[0,0])
            if Availability(s) == UnknownAvailability() || (s isa IOTraits.BufferedInput)
                @test transfer(s => v) == 2
                @test v == [0x0201, 0x0403]
                @test transfer(s => v) == 1
                @test v == [0x0605, 0x0403]
            else
                @test transfer(s => v) == 1
                @test v == [0x0201, 0x0000]
                @test transfer(s => v) == 0
                advance!(s)
                @test transfer(s => v) == 2
                @test v == [0x0403, 0x0605]
            end
        end
    end
end


@testset "transfer to Channel" begin
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))" Availability(s)
            v = Channel{UInt16}(100)
            if Availability(s) == UnknownAvailability() || (s isa IOTraits.BufferedInput)
                @test transfer(s => v, 2) == 2
                @test !isempty(v) && take!(v) == 0x0201
                @test !isempty(v) && take!(v) == 0x0403
                @test isempty(v)
                @test transfer(s => v, 1) == 1
                @test !isempty(v) && take!(v) == 0x0605
            else
                @test transfer(s => v, 2) == 1
                @test !isempty(v) && take!(v) == 0x0201
                @test isempty(v)
                @test transfer(s => v, 1) == 0
                advance!(s)
                @test transfer(s => v, 2) == 2
                @test !isempty(v) && take!(v) == 0x0403
                @test !isempty(v) && take!(v) == 0x0605
                @test isempty(v)
            end
        end
    end
end


struct TestStruct
    a::UInt8
    b::UInt8
end

@testset "Struct transfer" begin
    chunks = ([1,2,3], [4,5,6])
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))" Availability(s)
            v = [TestStruct(0,0), TestStruct(0,0)] 
            if Availability(s) == UnknownAvailability()
                @test transfer(s => v) == 2
                @test v == [TestStruct(1,2), TestStruct(3,4)] 
                @test transfer(s => v) == 1
                @test v == [TestStruct(5,6), TestStruct(3,4)] 
            else
                @test transfer(s => v) == 1
                @test v == [TestStruct(1,2), TestStruct(0,0)] 
                if !(s isa IOTraits.BufferedInput)
                    @test transfer(s => v) == 0
                    advance!(s)
                end
                @test transfer(s => v) == 2
                @test v == [TestStruct(3,4), TestStruct(5,6)] 
            end
        end
    end
end

@testset "Partial-item transfer" begin
    chunks = ([1,2,3], [4,5])
    for s in test_streams(chunks)
        @testset "$(typeof(s))" begin
            @info "$(typeof(s))" Availability(s)
            v = zeros(UInt16, 2)
            if Availability(s) == UnknownAvailability()
                @test transfer(s => v) == 2
                @test_throws IOTraits.IOTraitsError transfer(s => v)
            else
                @test transfer(s => v) == 1
                @test v == [0x0201, 0x0000]
                if !(s isa IOTraits.BufferedInput)
                    @test transfer(s => v) == 0
                    advance!(s)
                end
                @test transfer(s => v) == 1
                @test v == [0x0403, 0x0000]
            end
        end
    end
end
