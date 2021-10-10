raw"""
# IOTraits.jl

[Trait types][White] for describing the capabilities and behaviour of
IO interfaces.
"""
module IOTraits

include("idoc.jl")


raw"""
## Background

This collection of Trait types began as a tool for resolving method
selection issues in the UnixIO.jl package. Everything in Unix is a
file, but there are many types of file, many types of Unix, and
many ways a file handled can be configured.

Selection of correct (or most efficient) methods can often be
achieved with a simple type hierarchy. However traits seemed to be
useful way to deal with variations in behaviour that depend
file handle configuration and platform.
In general `libc`'s `write(2)` and `read(2)` can be used to transfer
data to or from any Unix file descriptor. However, the precise
behaviour of these functions depends on many factors.

Will `read` block?, if not, will it return less than the requested
number of bytes? Can I query the number of bytes available to read
first? How should I wait for more bytes? If more than one line is
buffered will `read` return all of them?  Will read ever return a
partial line? Will every call to `write(2)` result in a packet being
transmitted? Is it efficient to write one byte at a time?
Does `lseek` work with this file? Does `FIONREAD` work with this file?

The answers depend on combinations of file type, configuration and
platform.

IOTraits expands on the traits from UnixIO.jl in the hope of making
them more broadly useful.
According to the [law of the hammer][Hammer] some of this is probably 
overkill. The intention is to consider the application of Trait types
to various aspects of IO and to see where it leads.

[White]: https://www.juliabloggers.com/the-emergent-features-of-julialang-part-ii-traits/

[Hammer]: https://en.wikipedia.org/wiki/Law_of_the_hammer

[Duck]: https://en.wikipedia.org/wiki/Duck_typing


## Overview

The IOTraits interface is built around the `transfer(stream, buffer)` function.
This function transfers data between a stream and a buffer.

Traits are used to specify the behaviour of the stream and the buffer.

--------------------------------------------------------------------------------
Trait                      Description
-------------------------- -----------------------------------------------------
`TransferDirection`        Which way is the transfer? \
                           (`In`, `Out` or `Exchange`).

`StreamIndexing`           Is indexing (e.g. `pread(2)`) supported? \
                           (`NotIndexable`, `IndexableIO`)

`FromBufferInterface`      How to get data from the buffer? \
                           (`FromIO`, `FromPop`, `FromTake`, `UsingIndex`,
                            `FromIteration` or `UsingPtr`)

`ToBufferInterface`        How to put data into the buffer? \
                           (`ToIO`, `ToPush`, `ToPut`, `UsingIndex` or
                            `UsingPtr`)

`TotalSize`                How much data is available? \
                           (`UnknownTotalSize`, `VariableTotalSize`,
                            `FixedTotalSize`, or `InfiniteTotalSize`)

`TransferSize`              How much data can be moved in a single transfer? \
                            (`UnknownTransferSize`, `KnownTransferSize`,
                             `LimitedTransferSize` or `FixedTransferSize`)

`ReadFragmentation`         What guarantees are made about fragmentation? \
                            (`ReadsBytes`, `ReadsLines`, `ReadsPackets` or
                             `ReadsRequestedSize`)

`CursorSupport`             Are `mark` and `seek` supported? \
                            (`NoCursors`, `Seekable` or `Markable`)

`WaitingMechanism`          How to wait for activity? \
                            (`WaitBySleeping`, `WaitUsingPosixPoll`,
                             `WaitUsingEPoll`, `WaitUsingPidFD` or
                             `WaitUsingKQueue`)
--------------------------------------------------------------------------------


## IO Interface Model

```julia
julia>
help?> Base.IO
  No documentation found.
```

As it stands Julia doesn't have a well defined generic interface for IO.
It isn't possible to write a generic library that accepts `<: IO` objects
because specification of the `IO` interface is not complete and the reference
implementations are inconsistent. [^IF1] There are also instances where
`IO` behaviour is well defined but function naming isn't ideal, or default
behaviour can be surprising.[^IF2]

[^IF1]: Issue [24526](@jl#) "Review of IO blocking behaviour" describes
inconsistencies in blocking, termination and allocation behaviour. There are
both inconsistencies between behaviour of different functions and between
different methods of the same functions.

[^IF2]: e.g. `eof(io) -> Bool` looks like a simple query function but it
actually blocks to wait for data.


### IO or Stream?

The Julia IO interface is built around the abstract type `Base.IO`. The `IO`
interface specifications refer to `IO` objects as "stream" in some places
and "io" in others.[^IF3] The IOTraits interface defines `IOTraits.Stream`
and uses the word "stream" to refer to instances of this type. To avoid
ambiguity: instances of `IO` are referred to as "a `Base.IO` object".
Also, for clarity `IOTraits.Stream` is not a subtype of `Base.IO`.

[^IF3]: Examples from function signatures:
`close(stream)`, `bytesavailable(io)`, `readavailable(stream)`,
`isreadable(io)`, `read(io::IO, String)`, `eof(stream)`. \
Examples from function descriptions: "The IO stream", "the specified IO object"
"the given I/O stream", "the stream `io`", "the stream or file". \
Note: `Base.IOStream` is a concrete subtype of `IO` that implements local
file system IO. References to "stream" and "IO stream" in existing `IO`
interface specifications are not related to `Base.IOStream`.
"""

"""
The `Stream` type models byte-streams.
Many common operations involve transferring data to and from byte streams.
e.g. writing data to a local file; receiving data from a network server;
or typing commands into a terminal.
"""
abstract type Stream end

"""
`BaseIO(::Stream) -> Base.IO` creates a Base compatible wrapper around a
stream.
Similarities and differences between the `Base.IO` model and the
`IOTraits.Stream` model can be seen by reading the `TraitsIO`
implementations of the `Base.IO` functions below.
"""
struct BaseIO{T<:Stream} <: Base.IO
    stream::T
end

StreamDelegation(::Type{BaseIO}) = DelegatedToSubstream()



raw"""

### Aspects of the Stream interface

Issue
[24526](https://github.com/JuliaLang/julia/issues/24526#issuecomment-431567472)
identified three aspects of behaviour in the `Base.read*` interface that,
without precise specification, lead to ambiguity and inconsistency:

 * allocation: read into the caller's buffer?
   (resize this buffer?) or return a new buffer?
 * termination: read a specified size?, up to a delimiter?
   or read as much as possible?
 * blocking: wait however long it takes for the termination condition to be
   reached? or return early if insufficient data is available?

The IOTraits interface attempts to limit the number of behavioural permutations 
as much as possible by choosing a default behaviour for each aspect and
supporting other behaviours only by addition of clean wrapper layers.

**Allocation:** The `transfer` function never allocates buffers or resizes buffers
it simply transfers bytes to or from the buffer provided. Exceptions to this
rule are possible through the [Buffer Interface Traits](#buffer-interface-traits)
[^AS1]. The interface aims to support implementations that wish to avoid
unnecessary buffering. It should be simple to write a transfer method that
passes a supplied buffer directly to an OS system call. Buffering can be added
in wrapper layers as needed.


[^AS1]: e.g. if `ToBufferInterface(buffer) == ToPush()` data is pushed into the
buffer, which may lead to resizing.

**Termination:** The `transfer` function is specified to "transfer at most `n`
items" and "Return the number of items transferred".
i.e. if some amount of data is available, return it right away rather than
waiting for the entire requested amount. This behaviour can easily be wrapped
with a retry layer to support cases where all `n` items are required.

**Blocking:** By default the `transfer` function waits indefinitely for
data to be available. Control over this behaviour is provided by the optional
`deadline=` argument. `transfer` stops waiting when `deadline > time()`.
This interface allows non-blocking transfers (`deadline=0`), blocking transfers
(`deadline=Inf`) or anything in between.[^AS2]

[^AS2]: Note that `transfer` will always return data that is immediately
available irrespective of the deadline. i.e. There is no race condition when
`deadline ~= time()`.

The combination of the chosen termination and blocking behavior leads to
two cases where `transfer` returns zero: End of stream (EOF), and deadline
expired. This seems like a nice unification of the treatment of streams that
have a distinct end and those that don't. The caller can specify
a deadline that makes sense for their application and not have to worry about
what type of underlying OS stream is involved.[^AS3]

[^AS3]: With the current `IO` interface, there are inconsistencies. e.g.
reading log messages from a pipe with `readline(io)` will block and wait for
a line to be available, but reading log messages from a file will yield
endless empty stings at the end of the file. The empty strings can be avoided
by `while !eof(io) readline(io) ...`, but `eof(io)` returns true when all the
currently available lines have been read, so to wait for more lines we would
need an additional polling loop.

Another relevant aspect is transfer direction. Does a stream support input?,
output? or both?  Most operating systems have a mixture of bi-directional and
uni-directional stream APIs.[^AS6] Streams that are both readable and writable
can be confusing[^AS4] and difficult to implement correctly.[^AS5]
It seems simpler and more general to use a model where all streams are
uni-directional. 

[^AS4]: e.g. What does `close(::IO)` do for a bi-directional stream?
([41995](@jl#)) Does `Base.position(io)` refer to the input position or the
output position?

[^AS5]: [39727](@jl#) "Bi-directional IOStream seems to mix input and output"

[^AS6]: In some places Unix uses bi-directional streams. e.g. files can be
opened for reading and writing and sockets are usually bi-directional.
However, in many instances Unix uses distinct streams for input and output.
e.g. STDIN and STDOUT are distinct streams and  `pipe(2)` returns the
"read end" and the "write end" of a one-way pipe. Even where Unix supports
bi-directional streams there are cases where is is best to use two seperate
streams for a particular resource. e.g. to eliminate ambiguity in `poll(2)`
events.

**Direction:** In general a stream supports input, or output but not both.
The [Transfer Direction Trait](#transfer-direction-trait) specifies which.[^AS7]
This restriction simplifies the specification of things like `position`,
`mark` and `seek`. It also avoids the need for distinctions like `close`
vs `closewrite` ([41995](@jl#)). Bi-directonal streams can easily be
added by a wrapper layer that combines two streams e.g. see DuplexIO.jl.

[^AS7]: Note the [Transfer Direction Trait](#transfer-direction-trait)
supports direction: `Exchange` for interfaces like [SPI][SPI] where data
must be synchronously exchanged between a buffer and the interface (i.e.
input and output are not separable). This can be though of as having exactly
the same behavior as direction `Out` except that incoming data appears in the
output buffer after each output transfer.


### Methods of Base Functions for Streams

The IOTraits interface avoids defining methods of Base functions that have
incomplete or ambiguous specifications. It also avoids local function names
names that shadow Base functions. In some cases a similar function name with
an underscore prefix is used to differentiate local functions.

The IOTraits interface defines methods for the following well defined
Base functions (the default methods for the generic `Stream` type dispatch
to a wrapped delegate stream if the `StreamDelegation` trait is in effect).
"""

Base.isopen(s::Stream) = is_proxy(s) ? isopen(unwrap(s)) : false

Base.close(s::Stream) = is_proxy(s) ? close(unwrap(s)) : nothing

Base.wait(s::Stream) = is_proxy(s) ? wait(unwrap(s)) :
                                     wait(s, WaitingMechanism(s))

function Base.bytesavailable(s::Stream)
    @require is_input(s)
    _bytesavailable(unwrap(s))
end

_bytesavailable(s) = _bytesavailable(s, TransferSize(io))
_bytesavailable(s, ::UnknownTransferSize) = 0
_bytesavailable(s, ::KnownTransferSize) =
    _bytesavailable(s, TransferSizeMechanism(s))


function Base.length(s::Stream)
    @require TotalSize(s) isa KnownTotalSize
    _length(unwrap(s), TotalSizeMechanism(s))
end

_length(stream, ::SupportsStatSize) = stat(stream).size


# FIXME wait timeout ? deadline ? args for wait ?



### Stream Delegation Wrappers

"""
The StreamDelegation trait allows a Stream subtype to delegate most method
calls to a wrapped substream while redefining other methods as needed.

Wrappers are used to augment low level IO drivers with features like buffering
or defragmentation. Wrappers are also used to make `Stream` objects compatible
with `Base.IO`.

`StreamDelegation(stream)` returns one of:

| Interface                | Description                                       |
|:------------------------ |:------------------------------------------------- |
| `NotDelegated()`         | This stream has its own stream interface methods. |
| `DelegatedToSubStream()` | This stream is a proxy for a sub stream.          |
"""
abstract type StreamDelegation end
struct NotDelegated <: StreamDelegation end
struct DelegatedToSubStream <: StreamDelegation end
StreamDelegation(s) = StreamDelegation(typeof(s))
StreamDelegation(::Type) = NotDelegated()

is_proxy(s) = StreamDelegation(s) != NotDelegated()


"""
`unwrap(stream)`
Retrieves the underlying stream that is wrapped by a proxy stream.
"""
unwrap(s) = unwrap(s, StreamDelegation(s))
unwrap(s, ::NotDelegated) = s
unwrap(s, ::DelegatedToSubStream) = s.stream



raw"""
## Unfiled Notes

 - How could `Base.isready` apply to IO? It's definition is nice and concise:
   "Determine whether a Channel has a value stored to it. Returns immediately,
   does not block."
 - Build `ReadlineMux <: IOMux` and `ReadlineDemux <: IODemux` as an example
   of a traits aware IO mechanism. e.g. merge multiple streams onto a single
   IO with a mux/demux header.
 - Consider traits to select special purpose IO functions where appropriate:
   `pread`, `readv`, `writev`, `sendfile` ?
 - Consider using traits to identify inefficient access patterns.
    - Keep stats per file
        - No. tranfers, No. bytes, No. seeks.
        - Time between transfers (rolling avg?)
        - Warn if stats don't align with traits
        - e.g. large number of small reads for high per-call overhead IO.
 - Consider trait to characterise access speed:
    - fast mmap - ok for small and large requests
    - fast local - but slow for small requests
    - fast network - but slow for small requests
    - slow serial - no problem with small requests
 - content:
    - Has bytes
    - no content (links)
    - directory
 - writing
    - needs flush?
    - efficient to write one byte at a time?
    - natural page size?

"""
using Preconditions
using Markdown
using Preferences
using Mmap
include("../../../src/macroutils.jl")



# Transfer Direction Trait

"""
The `TransferDirection` trait describes the direction of data transfer
supported by a stream.

[^SPI]: e.g. a [SPI][SPI] interface receives a byte for every byte transmitted. 

[SPI]: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface

`TransferDirection(stream)` returns one of:

| Interface      | Description                                                 |
|:-------------- |:----------------------------------------------------------- |
| `In()`         | data is "read" from the `IO` into a buffer.                 |
| `Out()`        | data from a buffer is "written" to the `IO`.                |
| `Exchange()`   | data is exchanged between the `IO` and a buffer.[^SPI]      |
"""
abstract type TransferDirection end
struct In <: TransferDirection end
struct Out <: TransferDirection end
struct Exchange <: TransferDirection end
const AnyDirection = TransferDirection
TransferDirection(s) = TransferDirection(typeof(s))
TransferDirection(T::Type) = is_proxy(T) ? TransferDirection(unwrap(T)) :
                                           nothing

is_input(s) = TransferDirection(s) != Out()
is_output(s) = TransferDirection(s) != In()




# IO Indexing Trait

"""
Is indexing (e.g. `pread(2)`) supported?
"""
abstract type StreamIndexing end
struct NotIndexable <: StreamIndexing end
struct IndexableIO <: StreamIndexing end
StreamIndexing(s) = StreamIndexing(typeof(s))
StreamIndexing(T::Type) = is_proxy(T) ? StreamIndexing(unwrap(T)) :
                                        NotIndexable

stream_is_indexable(s) = StreamIndexing(s) == IndexableIO()


ioeltype(s) = isabstracttype(eltype(s)) ? UInt8 : eltype(s)



# Data Transfer Function

"""
    transfer(stream, buffer, [n]; start=1, deadline=Inf) -> n_transfered

Transfer at most `n` items between `stream` and `buffer`.[^NITEMS]
Return the number of items transferred.
 
If no items are immediately available, wait until `time() > deadline`
for at least one item to be transferred.[^WAIT] If the optional `timeout=`
argument is provided then the deadline is `time() + timeout`.

[^NITEMS]: If `n` is not specified then the number of items transferred depends
on the number of items available and the capacity of `buffer`.

[^WAIT]: The [`WaitingMechanism`](#event-notification-mechanism-trait) trait
determines what polling mechamism is used.

`start` specifies a buffer index at which the transfer begins.
If `stream` is indexable then `start` can be a tuple of two indexes:
`(stream_start_byte_index, buffer_start_index)`.

The direction of transfer (`In`, `Out` or `Exchange`) depends on
`TransferDirection(stream)`.

The type of items transferred depends on `ioeltype(buffer)`.[^ELTYPE]

[^ELTYPE]: By default `ioeltype(x) = eltype(x)`.

The `buffer` can be an `AbstractArray`, an `AbstractChannel`, a `URI`, an `IO`,
or another `Stream`.  Or, the `buffer` can be any collection that implements
the Iteration Interface, the Indexing Interface, the AbstractChannel
interface, or the `push!`/`pop!` interface.[^BUFIF]

[^BUFIF]: In some cases it is necessary to define a method of
[`ToBufferInterface` or `FromBufferInterface`](#buffer-interface-traits)
to specify the interface to use for a particular buffer type
(e.g. if a buffer implements more than one of the supported interfaces).
Defining these trait methods can also help to ensure that the most efficient
interface is used for a particular buffer type.

If either the `stream` or the `buffer` is a `URI` then items are transferred
to (or from) the identified resource.
A transfer to a `URI` creates a new resource or replaces the resource
(i.e. HTTP PUT semantics).
"""
function transfer(stream, buf, n=missing;
                  start::Union{Integer, NTuple{2,Integer}}=1,
                  timeout=Inf,
                  deadline=Inf)

    @require isopen(stream)
    if timeout != Inf
        deadline = time() + timeout
    end
    n = transfer(stream, buf, n, start, deadline)
    transfer_complete(stream, buf, n)
    return n
end


"""
`transfer_complete` is called at the end of the top-level `transfer` method.
A single call to the top-level `tansfer` method may result in many calls to
low level driver methods. e.g. to transfer every item in a collection.
The `transfer_complete` hook can be used, for example, to flush an output
buffer at end of a transfer.
"""
transfer_complete(stream, buf, n) = nothing


"""
### `transfer(a => b)`

    transfer(stream => buffer, [n]; start=(1 => 1), kw...) -> n_transfered
    transfer(buffer => stream, [n]; start=(1 => 1), kw...) -> n_transfered

`stream` and `buffer` can be passed to `transfer` as a pair.
`In` streams must be on the left.
`Out` streams must be on the right.
"""
function transfer(t::Pair{<:Stream,<:Any}, a...; start=(1 => 1), kw...)
    @require TransferDirection(t[1]) == In()
    if start isa Pair
        start = (start[1], start[2])
    end
    transfer(t[1], t[2], a...; start, kw...)
end

function transfer(t::Pair{<:Any,<:Stream}, a...; start=(1 => 1), kw...)
    @require TransferDirection(t[2]) == Out()
    if start isa Pair
        start = (start[2], start[1])
    end
    transfer(t[2], t[1], a...; start=start, kw...)
end



# Buffer Interface Traits

abstract type BufferInterface end
struct UsingIndex <: BufferInterface end
struct UsingPtr <: BufferInterface end
struct RawPtr <: BufferInterface end
struct FromIO <: BufferInterface end
struct FromPop <: BufferInterface end
struct FromTake <: BufferInterface end
struct FromIteration <: BufferInterface end
struct ToIO <: BufferInterface end
struct ToPush <: BufferInterface end
struct ToPut <: BufferInterface end


"""
The `FromBufferInterface` trait defines what interface is used to take
data from a particular buffer type
(or what interface is preferred for best performance).

`FromBufferInterface(buffer)` returns one of:

| Interface         | Description                                              |
|:----------------- |:-------------------------------------------------------- |
| `FromIO()`        | Take data from the buffer using the `Base.IO` interface. |
| `FromPop()`       | Use `pop!(buffer)` to read from the buffer.              |
| `FromTake()`      | Use `take!(buffer)`.                                     |
| `FromIteration()` | Use `for x in buffer...`.                                |
| `UsingIndex()`    | Use `buffer[i]` (the default).                           |
| `UsingPtr()`      | Use `unsafe_copyto!(pointer(buffer), x, n)`.             | 
| `RawPtr()`        | Use `unsafe_copyto!(buffer, x, n)`.                      | 

Default `FromBufferInterface` methods are built in for common buffer types:
"""
FromBufferInterface(x) = FromBufferInterface(typeof(x))
FromBufferInterface(::Type) = FromIteration()
FromBufferInterface(::Type{<:IO}) = FromIO()
FromBufferInterface(::Type{<:AbstractChannel}) = FromTake()
FromBufferInterface(::Type{<:Ptr}) = RawPtr()
FromBufferInterface(::Type{<:Ref}) = UsingPtr()


"""
Pointers can be used for `AbstractArray` buffers of Bits types.
"""
FromBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)

ArrayIOInterface(::Type{<:Array{T}}) where T =
    isbitstype(T) ? UsingPtr() : UsingIndex()

ArrayIOInterface(::Type{<:Base.FastContiguousSubArray{T,<:Any,<:Array{T}}}) where T =
    isbitstype(T) ? UsingPtr() : UsingIndex()



"""
The `ToBufferInterface` trait defines what interface is used to store data
in a particular type of buffer
(or what interface is preferred for best performance).

`ToBufferInterface(buffer)` one of:

| Interface      | Description                                                 |
|:-------------- |:----------------------------------------------------------- |
| `ToIO`         | Write data to the buffer using the `Base.IO` interface.     |
| `ToPush`       | Use `push!(buffer, data)`.                                  |
| `ToPut`        | Use `put!(buffer, data)`.                                   |
| `UsingIndex`   | Use `buffer[i] = data (the default)`.                       |
| `UsingPtr`     | Use `unsafe_copyto!(x, pointer(buffer), n)`.                |
| `RawPtr`       | Use `unsafe_copyto!(x, buffer, n)`.                         |

Default `ToBufferInterface` methods are built in for common buffer types.
"""

ToBufferInterface(x) = ToBufferInterface(typeof(x))
ToBufferInterface(::Type) = ToPush()
ToBufferInterface(::Type{<:IO}) = ToIO()
ToBufferInterface(::Type{<:AbstractChannel}) = ToPut()
ToBufferInterface(::Type{<:Ref}) = UsingPtr()
ToBufferInterface(::Type{<:Ptr}) = RawPtr()
ToBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)



# Transfer Function Dispatch

idoc"""
The top level `transfer` method promotes the keyword arguments
(`start` and `deadline`) to positional arguments so we can dispatch
on their types.

## `start` Index Normalisation

If `start` is a Tuple of indexes it is normalised by the method below.
The `StreamIndexing` trait is used to check that `stream` supports indexing.
Indexable streams are replaced by a `Tuple` containing `stream` and the
stream index.
"""
function transfer(stream, buf, n, start::Tuple, deadline)
    @require StreamIndexing(stream) == IndexableIO() || start[1] == 1
    if start[1] != 1
        stream = (stream, start[1])
    end
    transfer(stream, buf, n, start[2], deadline)
end

idoc"""
From here on, `start` is always a simple `Integer` index into `buf`.


## Applicaiton of Direction and Buffer Interface Traits

Next, the `IODriection` and `BufferInterface` traits are inserted into the
argument list.[^InOut]

[^InOut]: Note that although the `IODirection` is part of the argument list
and it is best to avoid premature specialisation on direction. Eventually
most transfers will end up calling an OS `read` or `write` function.
However, much of the transfer logic is the same irrespective of direction.
For example, the methods for `UsingPtr` and `UsingIndex` below work for
both input and output. (Another consideration is supporting interfaces with
`IODirection` `Exchange`).
"""
transfer(stream, buf, n, start::Integer, deadline) = 
    transfer(stream, TransferDirection(stream), buf, n, start, deadline)

transfer(stream, ::In, buf, n, start, deadline) =
    transfer(stream, In(), buf, ToBufferInterface(buf), n, start, deadline)

transfer(stream, ::Out, buf, n, start, deadline) =
    transfer(stream, Out(), buf, FromBufferInterface(buf), n, start, deadline)



## Transfer Specialisations for Indexable Buffers

idoc"""
Try to use the whole length of the buffer if `n` is missing.
"""
function transfer(stream, ::AnyDirection,
                  buf, ::Union{RawPtr, UsingPtr, UsingIndex},
                  n::Missing, start, deadline)
    n = length(buffer) - (start - 1)
    transfer(stream, buffer, n, start, deadline)
end


idoc"""
Convert pointer-compatible buffers to pointers.
"""
function transfer(stream, ::AnyDirection, buf, ::UsingPtr, n, start, deadline)
    checkbounds(buf, (start-1) + n)
    GC.@preserve buf transfer(stream, pointer(buf), n, start, deadline)
end


idoc"""
Transfer one item at a time for indexable buffers that are not
accessible through pointers.
"""
function transfer(stream, d::AnyDirection, buf, ::UsingIndex, n, start, deadline)
    T = ioeltype(buf)
    x = Ref{T}()
    count = 0
    for i in eachindex(view(buf, start:(start-1)+n))
        d == In() || (x[] = buf[i])
        n = transfer(stream, x, 1, 1, deadline)
        if n == 0
            break
        end
        d == Out() || (buf[i] = x[])
        count += n
        stream = next_stream_index(stream, T)
    end
    return count
end

next_stream_index((stream, i), T) = (stream, i + sizeof(T))
next_stream_index(stream::Stream, T) = stream


## Transfer Specialisations for Iterable Buffers

idoc"""
Iterate over `buf` (skip items until `start` index is reached).
Transfer each item one at a time.
"""
function transfer(stream, ::In, buf, ::FromIteration, n, start, deadline)
    count = 0
    for x in buf
        if start > 1
            start -= 1
            continue
        end
        n = transfer(stream, Ref(x), 1, 1, deadline)
        if n == 0
            break
        end
        count += n
        stream = next_stream_index(stream, ioeltype(buf))
    end
    return count
end


## Transfer Specialisations for Collection Buffers

transfer(s, dir, buf, ::ToPut, a...) = transfer(s, dir, buf, put!, a...)
transfer(s, dir, buf, ::ToPush, a...) = transfer(s, dir, buf, push!, a...)
transfer(s, dir, buf, ::FromPop, a...) = transfer(s, dir, buf, pop!, a...)
transfer(s, dir, buf, ::FromTake, a...) = transfer(s, dir, buf, take!, a...)

function transfer(s, d::TransferDirection, buf, f::Function, n, start, deadline)
    @require start == 1
    T = ioeltype(buf)
    x = Ref{T}()
    count = 0
    while count < n
        d == In() || (x[] = f(buf))
        n = transfer(s, x, 1, 1, deadline)
        if n == 0
            break
        end
        d == Out() || f(buf, x[])
        count += n
        s = next_stream_index(s, T)
    end
    return count
end


## Transfer Specialisations for IO Buffers

function transfer(s1, ::In, s2, ::ToIO, n, start, deadline)
    n = min(n, max(default_buffer_size(s1),
                   default_buffer_size(s2)))
    buf = Vector{UInt8}(undef, n)
    while true
        n = transfer(s1 => buf)
        if n == 0
            break
        end
        transfer(buf => s2, n)
    end
    @assert false
    #FIXME should this return as soon as something has been transferred?
    #FIXME should it read byteavailable from io1, transfer all of that, then return?
end



# Total Data Size Trait

abstract type TotalSize end
struct UnknownTotalSize <: TotalSize end
struct InfiniteTotalSize <: TotalSize end
abstract type KnownTotalSize end
struct VariableTotalSize <: KnownTotalSize end
struct FixedTotalSize <: KnownTotalSize end

"""
The `TotalSize` trait describes how much data is available from an
IO interface.

`TotalSize(stream)` returns one of:

--------------------------------------------------------------------------------
Total Size              Description
----------------------- --------------------------------------------------------
`VariableTotalSize()`   The total amount of data available can be queried
                        using the `length` function. Note: the total size can
                        change. e.g. new lines might be appended to a log file.

`FixedTotalSize()`      The amount of data is known and will not change.
                        Applicable to block devices.
                        Applicable to some network streams. e.g.
                        a HTTP Message where Content-Length is known.

`InfiniteTotalSize()`   End of file will never be reached. Applicable
                        to some device files.

`UnknownTotalSize()`    No known data size limit.
--------------------------------------------------------------------------------
"""
TotalSize(x) = TotalSize(typeof(x))
TotalSize(T::Type) = is_proxy(T) ? TotalSize(unwrap(T)) :
                                   UnknownTotalSize()

abstract type MmapSupport end
struct Mappable <: MmapSupport end
struct NotMappable <: MmapSupport end
MmapSupport(x) = MmapSupport(typeof(x))
MmapSupport(T::Type) = is_proxy(T) ? MmapSupport(unwrap(T)) :
                                     NotMappable()

abstract type SizeMechanism end
struct NoSizeMechanism <: SizeMechanism end
struct SupportsStatSize <: SizeMechanism end
struct SupportsFIONREAD <: SizeMechanism end
TotalSizeMechanism(x) = TotalSizeMechanism(typeof(x))
TotalSizeMechanism(T::Type) = is_proxy(T) ? TotalSizeMechanism(unwrap(T)) :
                                            NoSizeMechanism()


# Transfer Size Trait

abstract type TransferSize end
struct UnknownTransferSize <: TransferSize end
struct KnownTransferSize <: TransferSize end
struct LimitedTransferSize <: TransferSize end
struct FixedTransferSize <: TransferSize end
const AnyTransferSize = TransferSize

"""
The `TransferSize` trait describes how much data can be moved in a single
transfer.

`TransferSize(stream)` returns one of:

--------------------------------------------------------------------------------
Transfer Size           Description
----------------------- --------------------------------------------------------
`UnknownTransferSize()` Transfer size is not known in advance.
                        The only way to know how much data is available is to
                        attempt a transfer.

`KnownTransferSize()`   The amount of data immediately available for transfer
                        can be queried using the `bytesavailable` function.

`LimitedTransferSize()` The amount of data that can be moved in a single
                        transfer is limited. e.g. by a device block size or
                        buffer size. The maximum transfer size can queried
                        using the `max_transfer_size` function.
                        The amount of data immediately available for transfer
                        can be queried using the `bytesavailable` function.

`FixedTransferSize()`   The amount of data moved by a single transfer is fixed.
                        e.g. `/dev/input/event0` device always transfers
                        `sizeof(input_event)` bytes.
--------------------------------------------------------------------------------
"""
TransferSize(s) = TransferSize(typeof(s))
TransferSize(T::Type) = is_proxy(T) ?
                        TransferSize(unwrap(T)) :
                            TransferSizeMechanism(T) == NoSizeMechanism() ?
                            UnknownTransferSize() :
                            KnownTransferSize()

max_transfer_size(stream) = max_transfer_size(stream, TransferSize(stream))
max_transfer_size(stream, ::Union{UnknownTransferSize,
                                  KnownTransferSize}) = typemax(Int)


"""
`TransferSizeMechanism(stream)` returns one of:

 * `SupportsFIONREAD()` -- The underlying device supports `ioctl(2), FIONREAD`.
 * `SupportsStatSize()` -- The underlying device supports  `fstat(2), st_size`.
"""
TransferSizeMechanism(s) = TransferSizeMechanism(typeof(s))
TransferSizeMechanism(T::Type) = is_proxy(T) ?
                                 TransferSizeMechanism(unwrap(T)) :
                                 NoSizeMechanism()



# Data Fragmentation Trait

abstract type ReadFragmentation end
struct ReadsBytes         <: ReadFragmentation end
struct ReadsLines         <: ReadFragmentation end
struct ReadsPackets       <: ReadFragmentation end
struct ReadsRequestedSize <: ReadFragmentation end
const AnyReadFragmentation = ReadFragmentation 

"""
The `ReadFragmentation` trait describes what guarantees a stream makes
about fragmentation of data returned by the underlying `read(2)` system call.

`ReadFragmentation(stream)` returns one of:

--------------------------------------------------------------------------------
Data Fragmentation      Description
----------------------- --------------------------------------------------------
`ReadsBytes()`          No special guarantees about what is returned by
                        `read(2)`.  This is the default.

`ReadsLines()`          `read(2)` returns exactly one line at a time.
                        Does not return partially buffered lines unless an
                        explicit `EOL` or `EOF` control character is received.
                        Applicable to Character devices in canonical mode.
                        See [termios(3)](https://man7.org/linux/man-pages/man3/termios.3.html).

`ReadsPackets()`        `read(2)` returns exactly one packet at a time.
                        Does not return partially buffered packets.
                        Applicable to some sockets and pipes depending on configuration.
                        e.g. See the `O_DIRECT` flag in
                        [pipe(2)](https://man7.org/linux/man-pages/man2/pipe.2.html).

`ReadsRequestedSize()`  `read(2)` returns exactly the number of elements
                        requested.
                        Applicable to local files and some virtual files
                        (e.g. `/dev/random`, `/dev/null`).
--------------------------------------------------------------------------------
"""
ReadFragmentation(s) = ReadFragmentation(typeof(s))
ReadFragmentation(T::Type) = is_proxy(T) ? ReadFragmentation(unwrap(T)) :
                                           ReadsBytes()


# Performance Traits

abstract type TransferCost end
struct HighTransferCost <: TransferCost end
struct LowTransferCost <: TransferCost end
TransferCost(s) = TransferCost(typeof(s))
TransferCost(T::Type) = is_proxy(T) ? TransferCost(T) :
                                      HighTransferCost()

const kBytesPerSecond = Int(1e3)
const MBytesPerSecond = Int(1e6)
const GBytesPerSecond = Int(1e9)
DataRate(s) = DataRate(typeof(s))
DataRate(T::Type) = is_proxy(T) ? DataRate(unwrap(T)) :
                                  MBytesPerSecond


# Cursor Traits (Mark & Seek)

abstract type CursorSupport end
abstract type AbstractSeekable <: CursorSupport end
struct NoCursors <: CursorSupport end
struct Seekable  <: AbstractSeekable end
struct Markable  <: AbstractSeekable end

"""
The `CursorSupport` trait describes mark and seek capabilities.

`CursorSupport(stream)` returns one of:

--------------------------------------------------------------------------------
Cursor Support   Description
---------------- ---------------------------------------------------------------
`NoCursors()`

`Seekable()`     Supports `seek`, `skip`, `seekstart` and `seekend`.

`Markable()`     Is seekable, and also supports
                 `mark`, `ismarked`, `unmark`, `reset`.
--------------------------------------------------------------------------------
"""
CursorSupport(s) = CursorSupport(typeof(s))
CursorSupport(T::Type) = is_proxy(T) ? CursorSupport(unwrap(T)) :
                                       NoCursors()
const NotMarkable = Union{NoCursors,Seekable}

trait_error(s, trait) =
    throw(ArgumentError("$(typeof(s)) does not implement $trait"))

Base.seek(io::TraitsIO, pos) = seek(io.stream, CursorSupport(io.stream), pos)
_seek(s, ::NoCursors, pos) = trait_error(s, Seekable)

Base.skip(io::TraitsIO, offset) = _skip(io.stream, CursorSupport(io.stream), offset)
_skip(s, ::NoCursors, offset) = trait_error(s, Seekable)

Base.position(io::TraitsIO) = _position(io.stream, CursorSupport(io.stream))
_position(s, ::NoCursors) = nothing

Base.seekend(io::TraitsIO) = _seekend(io.stream, CursorSupport(io.stream))
_seekend(s, ::NoCursors) = nothing

Base.mark(io::TraitsIO) = _mark(io.stream, CursorSupport(io.stream))
_mark(s, ::NotMarkable) = trait_error(s, Markable)

Base.unmark(io::TraitsIO) = _unmark(io.stream, CursorSupport(io.stream))
_unmark(s, ::NotMarkable) = trait_error(s, Markable)

Base.reset(io::TraitsIO) = _reset(io.stream, CursorSupport(io.stream))
_reset(s, ::NotMarkable) = trait_error(s, Markable)

Base.ismarked(io::TraitsIO) = _ismarked(io.stream, CursorSupport(io.stream))
_ismarked(s, ::NotMarkable) = trait_error(s, Markable)



# Event Notification Mechanism Trait

abstract type WaitingMechanism end
struct WaitBySleeping     <: WaitingMechanism end
struct WaitUsingPosixPoll <: WaitingMechanism end
struct WaitUsingEPoll     <: WaitingMechanism end
struct WaitUsingPidFD     <: WaitingMechanism end
struct WaitUsingKQueue    <: WaitingMechanism end


"""
The `WaitingMechanism` trait describes ways of waiting for OS resources
that are not immediately available. e.g. when `read(2)` returns
`EAGAIN` (`EWOULDBLOCK`), or when `waitpid(2)` returns `0`.

Resource types, `R`, that have an applicable `WaitingMechanism`, `T`,
define a method of `Base.wait(::T, r::R)`.
`WaitBySleeping` is the default.[^SLEEP]

If a `WaitingMechanism`, `T`, is not available on a particular OS
then `Base.isvalid(::T)` should be defined to return `false`.[^AIO]

[^AIO]: ⚠️ Consider Linux AIO `io_getevents` for disk io?

`WaitingMechanism(stream)` returns one of:

--------------------------------------------------------------------------------
Waiting Mechanism     Description 
--------------------- ----------------------------------------------------------
`WaitBySleeping`      Wait using a dumb retry/sleep loop.

`WaitUsingPosixPoll`  Wait using the POXSX `poll` mechanism.
                      Wait for activity on a set of file descriptors.
                      Applicable to FIFO pipes, sockets and character devices
                      (but not local files).  See [`poll(2)`][poll]

`WaitUsingEPoll`      Wait using the Linux `epoll` mechanism.
                      Like `poll` but scales better for workloads with a large
                      number of waiting streams.
                      See [`epoll(7)`][epoll]

`WaitUsingKQueue`     Wait using the BSD `kqueue` mechanism.
                      Like `epoll` but can also wait for files, processes,
                      signals etc. See [`kqueue(2)`][kqueue]

`WaitUsingPidFD()`    Wait for process termination using the Linux `pidfd`
                      mechanism. A `pidfd` is a special process monitoring
                      file descriptor that can in turn be monitored by `poll` or
                      `epoll`. See [`pidfd_open(2)`][pidfd]
--------------------------------------------------------------------------------

[poll]: https://man7.org/linux/man-pages/man2/poll.2.html
[epoll]: https://man7.org/linux/man-pages/man7/epoll.7.html
[kqueue]: https://www.freebsd.org/cgi/man.cgi?kqueue
[pidfd]: http://man7.org/linux/man-pages/man2/pidfd_open.2.html

[^SLEEP]: This may be the most efficient mechanism for small systems with
simple IO requirements, for large systems where throughput is more important
than latency, or for systems that simply do not spend a lot of time
waiting for IO. Sleeping allows other Julia tasks to run immediately, whereas
the other polling mechanisms all have some amount of book-keeping and system
call overhead.
"""
WaitingMechanism(x) = WaitingMechanism(typeof(x))
WaitingMechanism(T::Type) = is_proxy(T) ? WaitingMechanism(unwrap(T)) :
                                          WaitBySleeping()

Base.isvalid(::WaitingMechanism) = true
Base.isvalid(::WaitUsingEPoll) = Sys.islinux()
Base.isvalid(::WaitUsingPidFD) = Sys.islinux()
Base.isvalid(::WaitUsingKQueue) = Sys.isbsd() && false # not yet implemented.

firstvalid(x, xs...) = isvalid(x) ? x : firstvalid(xs...)

const default_poll_mechanism = firstvalid(WaitUsingKQueue(),
                                          WaitUsingEPoll(),
                                          WaitUsingPosixPoll(),
                                          WaitBySleeping())

Base.wait(x, ::WaitBySleeping) = sleep(0.1)


"""
## Preferred Polling Mechanism

    set_poll_mechanism(name)

Configure the preferred event polling mechanism:
"kqueue", "epoll", "poll", or "sleep".[^POLL]
This setting is persistently stored through [Preferences.jl][Prefs].

[^POLL]: This setting applies only to `poll(2)`-compatible file descriptors
(i.e. it does not apply to local disk files).

By default, IOTraits will try to choose the best available mechanism
(see `default_poll_mechanism`).


To find out what mechanism is used for a particular `FD` call:
`WaitingMechanism(fd)`

[Prefs]: https://github.com/JuliaPackaging/Preferences.jl
"""
function set_poll_mechanism(x)
    @require poll_mechanism(x) != nothing
    @require isvalid(poll_mechanism(x))
    @set_preferences!("waiting_mechanism" => x)
    @warn "Preferred IOTraits.WaitingMechanism set to $(poll_mechanism(x))." *
          "UnixIO must be recompiled for this setting to take effect."
end

poll_mechanism(name) = name == "kqueue" ? WaitUsingKQueue() :
                       name == "epoll"  ? WaitUsingEPoll() :
                       name == "poll"   ? WaitUsingPosixPoll() :
                       name == "sleep"  ? WaitBySleeping() :
                                          default_poll_mechanism

const preferred_poll_mechanism =
    poll_mechanism(@load_preference("waiting_mechanism"))


# Null Streams

"""
`NullIn()` is an input stream that does nothing.
It is intended to be used for testing Delegate Streams.
"""
struct NullIn <: Stream end

TransferDirection(::Type{NullIn}) = In()

transfer(io::NullIn, buf::Ptr{UInt8}, n; kw...) = n



include("wrap.jl")

"""
`@delegate_io f` creates wrapper methods for function `f`.
A separate method is created with a specific 2nd argument type for
each 2nd argument type used in pre-existing methods of `f`
(to avoid method selection ambiguity). e.g.

    f(io::IODelegate; kw...) = f(unwrap(io); kw...)
    f(io::IODelegate, a2::T, a...; kw...) = f(unwrap(io), a2, a...; kw...)
"""
macro delegate_io(f, D=FullInDelegate, u=unwrap)
    methods = [
      esc(:(( $f(io::$D              ; k...) = $f($u(io)          ; k...)   ))),
    ( esc(:(( $f(io::$D, a::$T, aa...; k...) = $f($u(io), a, aa...; k...)   )))
                         for T in arg2_types(Main.eval(:($f)))
    )...]
    (m->@debug m).(methods)
    Expr(:block, methods...)
end


@delegate_io Base.read!
@delegate_io Base.readuntil
@delegate_io Base.readline
@delegate_io Base.countlines
@delegate_io Base.eachline
@delegate_io Base.readeach
@delegate_io Base.unsafe_read
@delegate_io Base.peek
@delegate_io Base.readavailable
@delegate_io Base.mark
@delegate_io Base.ismarked
@delegate_io Base.unmark
@delegate_io Base.reset
@delegate_io Base.seek
@delegate_io Base.position
@delegate_io Base.seekend
@delegate_io Base.seekstart



# BufferedIO

"""
Generic type for Buffered Input Wrappers.

See `BufferedIn` and `LazyBufferedIn` below.
"""
abstract type GenericBufferedInput end

StreamDelegation(::Type{GenericBufferedInput}) = DelegatedToSubstream()

TransferCost(::Type{GenericBufferedInput}) = LowTransferCost()

ReadFragmentation(::Type{GenericBufferedInput}) = ReadsBytes()

function buffered_in_warning(stream)
    if ReadFragmentation(stream) != ReadsBytes()
        @warn "Wrapping $(typeof(stream)) with `BufferedInput` causes " *
              "the $(ReadFragmentation(stream)) trait to be ignored!"
    end
    if TransferCost(stream) == LowTransferCost()
        @warn "$(typeof(stream)) already has LowTransfterCost. " *
              "Wrapping with `BufferedInput` may degrade performance."
    end
end

Base.close(s::GenericBufferesInput) = ( take!(s.buffer);
                                        Base.close(s.io) )


"""
Size of the internal buffer.
"""
buffer_size(s::GenericBufferedInput) = s.buffer_size


"""
Buffer ~1 second of data by default.
"""
default_buffer_size(stream) = DataRate(stream)


"""
Transfer bytes from the wrapped IO to the internal buffer.
"""
function refill_internal_buffer(s::GenericBufferedInput,
                                n=io.buffer_size; kw...)

    # If needed, expand the buffer.
    iob = s.buffer
    @assert iob.append
    Base.ensureroom(iob, n)
    checkbounds(iob.data, iob.size+n)

    # Transfer from the IO to the buffer.
    p = pointer(iob.data, iob.size+1)
    n = GC.@preserve iob transfer(s.stream, p, n; kw...)
    iob.size += n
end


#= FIXME
idoc"""
Shortcut to read one byte directly from buffer.
Or, if the buffer is empty refill it.
"""
function Base.read(io::GenericBufferedIn, ::Type{UInt8}; kw...)
    if bytesavailable(io.buffer) != 0
        return Base.read(io.buffer, UInt8)
    end
    eof(io.io; kw...) && throw(EOFError())
    refill_internal_buffer(io; kw...)
    return Base.read(io.buffer, UInt8)
end


idoc"""
Shortcut to peek into the buffer.
Or, if the buffer is empty refill it.
"""
function Base.peek(io::GenericBufferedIn, ::Type{T}; kw...) where T
    if bytesavailable(io.buffer) >= sizeof(T)
        return Base.peek(io.buffer, T)
    end
    eof(io.io; kw...) && throw(EOFError())
    refill_internal_buffer(io; kw...)
    return Base.peek(io.buffer, T)
end
=#



## Buffered Input

"""
    BufferedInput(stream; [buffer_size]) -> Stream

Create a wrapper around `stream` to buffer input transfers.

The wrapper will try to read `buffer_size` bytes into its buffer
every time it transfers data from `stream`.

The default `buffer_size` depends on `IOTratis.DataRate(stream)`.

`stream` must not be used directly after the wrapper is created.
"""
struct BufferedInput{T<:Stream} <: GenericBufferedInput
    stream::T
    buffer::IOBuffer
    buffer_size::Int
    function BufferedIn(stream::T; buffer_size=default_buffer_size(stream)) where T
        @require TransferDirection(stream) == In()
        buffered_in_warning(stream)
        new{T}(stream, PipeBuffer(), buffer_size)
    end
end

TransferSize(::Type{BufferedInput{T}}) where T = LimitedTransferSize()

max_transfer_size(s::BufferedInput) = s.buffer_size

Base.bytesavailable(s::BufferedInput) = bytesavailable(s.buffer) 


function transfer(s::BufferedInput,
                  buf::Ptr{UInt8}, n, start::Integer, deadline)
    @info "transfer(t::BufferedIn, ...)"

    iob = s.buffer
    # If there are not enough bytes in `iob`, read more from the wrapped IO.
    if bytesavailable(iob) < n
        refill_internal_buffer(s)
    end

    # Read available bytes from `iob` into the caller's `buffer`.
    n = min(n, bytesavailable(iob))
    unsafe_read(iob, buf + (start-1), n)
    return n
end


#= FIXME
idoc"""
Shortcut to delegate `readavailable` to the internal buffer.
"""
function Base.readavailable(io::BufferedIn; kw...)
    if bytesavailable(io.buffer) == 0
        refill_internal_buffer(io; kw...)
    end
    return readavailable(io.buffer)
end
=#



## LazyBufferedIn

"""
    LazyBufferedIn(stream; [buffer_size]) -> Stream

Create a wrapper around `stream` to buffer input transfers.

The internal buffer is only used when a small transfer is attempted
or if `peek` is called.
Most reads are fulfilled directly from the underling stream.
This avoids the overhead of double buffering in situations where there is
an occasional need to read one byte at a time (e.g. `readuntil()`) but most
reads are already of a reasonable size.

The default `buffer_size` depends on `IOTratis.DataRate(io)`.

`stream` must not be used directly after the wrapper is created.
"""
struct LazyBufferedIn{T<:Stream} <: GenericBufferedIn
    stream::T
    buffer::IOBuffer
    buffer_size::Int
    function LazyBufferedIn(stream::T; buffer_size=default_buffer_size(stream)) where T
        @require TransferDirection(stream) == In()
        buffered_in_warning(stream)
        new{T}(stream, PipeBuffer(), buffer_size)
    end
end


Base.bytesavailable(s::LazyBufferedIn) = bytesavailable(s.buffer) + 
                                         bytesavailable(s.stream);


function transfer(s::LazyBufferedIn, buf::Ptr{UInt8}, n, start::Integer, deadline)
    @info "transfer(t::LazyBufferedIn, ...)"

    buf += (start-1)

    # First take bytes from the buffer.
    iob = s.buffer
    count = bytesavailable(iob)
    if count > 0
        count = min(count, n)
        unsafe_read(iob, buf, count)
    end

    # Then read from the wrapped IO.
    if n > count
        count += transfer(s.stream, buf + count, n - count; deadline)
    end

    @ensure count <= n
    return count
end



# Timeout Stream

"""
    TimeoutStream(io; timeout) -> Stream

The `TimeoutStream` wrapper adds a default timeout deadline to a stream
It is used to add timeout capability to Base.IO functions.
"""
struct TimeoutStream{T<:Stream} <: Stream
    stream::T
    deadline::Float64
    function TimeoutIO(stream::T, timeout) where T
        @require timeout < Inf
        new{T}(stream, time() + timeout)
    end
end

StreamDelegation(::Type{TimeoutStream}) = DelegatedToSubstream()

timeout_stream(s, t) = t == Inf ? s : TimeoutStream(s, t)

function transfer(s::TimeoutStream{T}, buffer, n; start, kw...) where T
    @info "transfer(t::TimeoutStream, ...)"
    transfer(s.stream, buffer, n; start, deadline = s.deadline)
end



# Base.IO Interface

function transfer(s::BaseIO, buffer, n; kw...)
    @info "transfer(t::BaseIO, ...)"
    transfer(s.stream, buffer, n; kw...)
end


Base.isreadable(stream::BaseIO) = is_input(stream.stream)
Base.iswritable(stream::BaseIO) = is_output(stream.stream)


## Function `eof`

idoc"""
`eof` is specialised on Total Size.
"""
function Base.eof(stream::BaseIO; timeout=Inf)
    @require is_input(stream)
    eof(stream, TotalSize(stream); timeout)
end

idoc"""
If Total Size is known then `eof` is reached when there are
zero `bytesavailable`.
"""
Base.eof(stream, ::KnownTotalSize; kw...) = bytesavailable(stream) == 0


idoc"""
If Total Size is not known then `eof` must "block to wait for more data".
"""
function Base.eof(stream, ::UnknownTotalSize; kw...)
    n = bytesavailable(stream)
    if n == 0
        wait(stream; kw...)
        n = bytesavailable(stream)
    end
    return n == 0
end

Base.eof(stream, ::InfiniteTotalSize; kw...) = (wait(stream; kw...); false)



## Function `read(io, T)`

idoc"""
Single byte read is specialized based on the Transfer Cost.
(Single byte read for High Transfer Cost falls through to the 
"does not support byte I/O" error from Base).
"""
function Base.read(stream::TraitsIO, ::Type{UInt8}; timeout=Inf)
    @require is_input(io)
    _read(io, TransferCost(io), UInt8; timeout)
end


idoc"""
Allow single byte read for interfaces with Low Transfter Cost,
but warn if a special Read Fragmentation trait is available.
"""
function _read(stream, ::LowTransferCost, ::Type{UInt8}; kw...)
    if ReadFragmentation(stream) == ReadsLines()
        @warn "read(::$(typeof(stream)), UInt8): " *
              "$(typeof(io)) implements `IOTraits.ReadsLines`." *
              "Reading one byte at a time may not be efficient." *
              "Consider using `readline` instead."
    end
    x = Ref{UInt8}()
    n = GC.@preserve x transfer(stream => pointer(x), 1; kw...)
    n == 1 || throw(EOFError())
    return x[]
end


idoc"""
Read as String. \
Wrap with `TimeoutIO` if timeout is requested.
"""
function Base.read(stream::BaseIO, ::Type{String}; timeout=Inf)
    @require is_input(stream)
    @invoke String(Base.read(timeout_io(stream, timeout)::IO))
end



## Function `readbytes!`

Base.readbytes!(s::BaseIO, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(s, buf, UInt(nbytes); kw...)

function Base.readbytes!(s::BaseIO, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, timeout=Inf)
    @require is_input(s)
    deadline = timeout_deadline(timeout)

    lb::Int = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
            resize!(buf, lb)
        end
        @assert lb > nread
        n = transfer(s, buf, lb - nread, nread + 1, deadline)
        if n == 0 || !all
            break
        end
        nread += n
    end
    @ensure nread <= nbytes
    return nread
end

timeout_deadline(timeout) = timeout == Inf ? Inf : time() + timeout


## Function `read(stream)`

idoc"""
Read until end of file.
Specialise on Total Size, Cursor Support and Mmap Support.
"""
function Base.read(stream; timeout=Inf)
    @require is_input(stream)
    _read(stream, TotalSize(stream), CursorSupport(stream); timeout)
end


function _read(stream, ::UnknownTotalSize, ::NoCursors; timeout=Inf)
    n = default_buffer_size(stream)
    buf = Vector{UInt8}(undef, n)
    readbytes!(stream, buf, n; timeout)
    return buf
end


idoc"""

"""
function _read(stream, ::KnownTotalSize, ::AbstractSeekable; kw...)
    n = length(stream) - position(stream)
    buf = Vector{UInt8}(undef, n)
    transfer_n(stream => buffer, n; kw...)
    return buf
end


"""
Transfer `n` items between `stream` and `buf`.

Call `transfer` repeatedly until all `n` items have been Transferred, 
stopping only if end of file is reached.

Return the number of items transferred.
"""
function transfer_n(stream, buf::Vector{UInt8}, n, start, deadline)
    @require length(buf) == (start-1) + n
    nread = 0
    while nread < n
        n = transfer(stream, buf, n - nread, start + nread, deadline)
        if n == 0
            break
        end
        nread += n
    end
    return n
end


## Function `read(stream, n)`

function Base.read(stream::BaseIO, n::Integer; timeout=Inf)
    @require is_input(stream)
    @invoke Base.read(timeout_io(stream, timeout)::IO, n::Integer)
end


## Function `unsafe_read`

idoc"""
`unsafe_read` must keep trying until `nbytes` nave been transferred.
"""
function Base.unsafe_read(stream::TraitsIO, buf::Ptr{UInt8}, nbytes::UInt;
                          deadline=Inf)
    @require is_input(stream)
    nread = 0
    @debug "Base.unsafe_read(stream::BaseIO, buf::Ptr{UInt8}, nbytes::UInt)"
    while nread < nbytes
        n = transfer(stream => buf + nread, nbytes - nread; deadline)
        if n == 0
            throw(EOFError())
        end
        nread += n
    end
    @ensure nread == nbytes
    nothing
end



## Function `readavailable`

"""
    readavailable(stream::BaseIO; [timeout=0]) -> Vector{UInt8}

Read immediately available data from a stream.

If `TransferSize(stream)` is `UnknownTransferSize()` the only way to know how
much data is available is to attempt a transfer.

Otherwise, the amount of data immediately available can be queried using the
`bytesavailable` function.
"""
function Base.readavailable(stream::BaseIO; timeout=0)
    @require is_input(stream)
    n = bytesavailable(stream)
    if n == 0 
        n = default_buffer_size(stream)
    end
    buf = Vector{UInt8}(undef, n)
    n = transfer(stream, buf; timeout)
    resize!(buf, n)
end



## Function `readline`

idoc"""
`readline` is specialised based on the Read Fragmentation trait.
"""
function Base.readline(stream::BaseIO; timeout=Inf, kw...)
    @require is_input(stream)
    _readline(stream, ReadFragmentation(stream); timeout, kw...)
end

idoc"""
If there is no special Read Fragmentation method,
use `TimeoutStream` to support the timeout option.
"""
_readline(stream::BaseIO, ::AnyReadFragmentation; timeout, kw...) =
    @invoke Base.readline(timeout_stream(stream, timeout)::IO; kw...)


"""
### `readline(io, ::ReadsLines)`

Character or Terminal devices (`S_IFCHR`) are usually used in
"canonical mode" (`ICANON`).

> "In canonical mode: Input is made available line by line."
[termios(3)](https://man7.org/linux/man-pages/man3/termios.3.html).

For these devices calling `read(2)` will usually return exactly one line.
It will only ever return an incomplete line if length exceeded `MAX_CANON`.
Note that in canonical mode a line can be terminated by `CEOF` rather than
"\n", but `read(2)` does not return the `CEOF` character (e.g. when the
shell sends a "bash\$ " prompt without a newline).

If `stream` has the `ReadsLines` trait calling `transfer` once will
read one line.
"""
function _readline(stream, ::ReadsLines; keep::Bool=false, kw...)

    v = Base.StringVector(max_line)
    n = transfer(stream => v; kw...)
    if n == 0
        return ""
    end

    # Trim end of line characters.
    while !keep && n > 0 && (v[n] == UInt8('\r') ||
                             v[n] == UInt8('\n'))
        n -= 1
    end

    return String(resize!(v, n))
end

const max_line = 1024 # UnixIO.C.MAX_CANON


## Function `readuntil`

Base.readuntil(stream::BaseIO, d::AbstractChar; timeout=Inf, kw...) =
    @invoke Base.readuntil(timeout_stream(stream, timeout)::IO, d; kw...)



# Exports

export TraitsIO, TransferDirection, transfer

export TotalSize,
       UnknownTotalSize, InfiniteTotalSize, KnownTotalSize, VariableTotalSize,
       FixedTotalSize

export TransferSize,
       UnknownTransferSize, KnownTransferSize, LimitedTransferSize,
       FixedTransferSize

export TransferSizeMechanism,
       NoSizeMechanism, SupportsFIONREAD, SupportsStatSize

export ReadFragmentation,
       ReadsBytes, ReadsLines, ReadsPackets, ReadsRequestedSize

export WaitingMechanism,
       WaitBySleeping, WaitUsingPosixPoll, WaitUsingEPoll, WaitUsingPidFD,
       WaitUsingKQueue

export CursorSupport, AbstractSeekable,
       NoCursors,
       Seekable,
       Markable


"""
## Possibly Related Issues

--------------------------------------------------------------------------------
Issue
-------------- -----------------------------------------------------------------
[14747](@jl#)  Intermittent deadlock in readbytes(open(echo \$text)) on Linux ?

[22832](@jl#)  Deadlock in reading stdout from cmd.

[1970](@uv#)   Serial Port support.

[2640](@uv#)   Pseudo-tty support.

[10292](@uv#)  write on IOBuffer with a maxsize 

[484](@uv#)    add uv_device_t as stream on windows and Linux to handle device IO

[3887](@jl#)   refactor I/O to do more buffering

[28975](@jl#)  readline not working for ls

[24440](@jl#)  Spawning turns IO race into process hang

[20812](@jl#)  Redirected STDOUT on macOS is hanging when more than 512 bytes
               are written at once

[24717](@jl#)  Pipe objects have lost their asyncness

[36639](@jl#)  slow printing in terminals

[39727](@jl#)  Bi-directional IOStream seems to mix input and output
               "Things work fine when I replace open/read/write with ccall
               to open/read/write, i.e. when I bypass julia IO."

[17070](@jl#)  Keyword argument docs for read are misleading. (all=true)

[40793](@jl#)  readbytes!: support the all keyword for all methods.
               "I've encountered cases where it doesn't seems block."

[24526](@jl#)  Review of IO blocking behaviour

[33799](@jl#)  Don't export position. Position is zero-based.

[36954](@jl#)  Rename `position` to `streampos`.

[40500](@jl#)  `peek` breaks `mark`.
               "...any plans to publish a proper interface for io one day?"

[41291](@jl#)  PR: added docs for IO interface

[40966](@jl#)  sendfile: operation not supported error

[35907](@jl#)  Slow disk IO on MacOS

[30044](@jl#)  massive slowdowns using stdin/stdout
               "It seems like PipeEndpoint is just really, really slow."

[24810](@jl#)  Improve documentation for process interaction using pipes

[24242](@jl#)  Add isseekable to Stream/IO interface?


--------------------------------------------------------------------------------
"""


using ReadmeDocs

include("ioinfo.jl") # Generate Method Resolution Info

end # module IOTraits
