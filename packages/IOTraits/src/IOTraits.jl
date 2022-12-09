raw"""
# IOTraits.jl

[Trait types][White] for describing the capabilities and behaviour of
IO interfaces.
"""
module IOTraits

using Preconditions
using Markdown
using Preferences
using Mmap
include("../../../src/macroutils.jl")

    using UnixIOHeaders
    const C = UnixIOHeaders
    include("../../../src/debug.jl")

    @db function __init__()
        @ccall(jl_generating_output()::Cint) == 1 && return
        debug_init()
        @db 1 "UnixIO.DEBUG_LEVEL = $DEBUG_LEVEL. See `src/debug.jl`."
    end

include("idoc.jl")


raw"""
## Background

This collection of Trait types began as a tool for resolving method
selection issues in the UnixIO.jl package.

Everything in Unix is a file, but there are many different types of file,
a few different types of Unix, and many ways a file handle can be configured.

Selection of correct (or most efficient) methods can often be
achieved with a simple type hierarchy. However traits seem to be
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
However, according to the [law of the hammer][Hammer] some of this is probably 
overkill. The intention is to consider the application of Trait types
to various aspects of IO and to see where it leads.

[White]: https://www.juliabloggers.com/the-emergent-features-of-julialang-part-ii-traits/

[Hammer]: https://en.wikipedia.org/wiki/Law_of_the_hammer

[Duck]: https://en.wikipedia.org/wiki/Duck_typing


## Overview

The IOTraits interface is built around the function `transfer!(stream, buffer)`.
This function transfers data between a stream and a buffer.

Traits are used to specify the behaviour of the stream and the buffer.

--------------------------------------------------------------------------------
Trait                      Description
-------------------------- -----------------------------------------------------
`TransferDirection`        Which way is the transfer? \
                           (`In`, `Out` or `Exchange`).

`StreamIndexing`           Is indexed stream access supported? (e.g. `pread(2)`) \
                           (`NotIndexable`, `IndexableIO`)

`FromBufferInterface`      How to get data from the buffer? \
                           (`FromIO`, `FromStream`, `FromPop`, `FromTake`,
                            `UsingIndex`, `FromIteration` or `UsingPtr`)

`ToBufferInterface`        How to put data into the buffer? \
                           (`ToIO`, `ToStream`, `ToPush`, `ToPut`,
                            `UsingIndex` or `UsingPtr`)

`TotalSize`                How much data is available? \
                           (`UnknownTotalSize`, `VariableTotalSize`,
                            `FixedTotalSize`, or `InfiniteTotalSize`)

`TransferSize`              How much data can be moved in a single transfer? \
                            (`UnlimitedTransferSize`, `LimitedTransferSize`
                            or `FixedTransferSize`)

`ReadFragmentation`         What guarantees are made about fragmentation? \
                            (`ReadsBytes`, `ReadsLines`, `ReadsPackets` or
                             `ReadsRequestedSize`)

`CursorSupport`             Are `mark` and `seek` supported? \
                            (`NoCursors`, `Seekable` or `Markable`)

`WaitingMechanism`          How to wait for activity? \
                            (`WaitBySleeping`, `WaitUsingPosixPoll`,
                             `WaitUsingEPoll`, `WaitUsingPidFD`,
                             `WaitUsingKQueue` or `WaitUsingIOURing`)

FIXME update summaries
--------------------------------------------------------------------------------


## The IO Interface Model

```julia
julia>
help?> Base.IO
  No documentation found.
```

As things stand Julia doesn't have a well defined generic interface for IO.

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
and "io" in others[^IF3].

The IOTraits interface defines `IOTraits.Stream`
and uses the word "stream" to refer to instances of this type. To avoid
ambiguity: instances of `IO` are referred to as "a `Base.IO` object".

[^IF3]: Examples from function signatures:
`close(stream)`, `bytesavailable(io)`, `readavailable(stream)`,
`isreadable(io)`, `read(io::IO, String)`, `eof(stream)`. \
Examples from function descriptions: "The IO stream", "the specified IO object"
"the given I/O stream", "the stream `io`", "the stream or file". \
(Also note: `Base.IOStream` is a concrete subtype of `IO` that implements local
file system IO. References to "stream" and "IO stream" in existing `IO`
interface specifications are not related to `Base.IOStream`.)

[^BaseIO]: Similarities and differences between the `Base.IO`
model and the `IOTraits.Stream` model can be seen by reading the
`IOTraits.BaseIO` implementations of the `Base.IO` functions below.
"""

"""
The `Stream` type models byte-streams.
Many common operations involve transferring data to and from byte streams.
e.g. writing data to a local file; receiving data from a network server;
or typing commands into a terminal.

Note that `IOTraits.Stream` is not a subtype of `Base.IO`.[^BaseIO]
"""
abstract type Stream end

"""
The constructor `BaseIO(::Stream) -> Base.IO` creates a Base.IO compatible
wrapper around a stream.
"""
struct BaseIO{T<:Stream} <: Base.IO
    stream::T
end



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

**Allocation:** The `transfer!` function never allocates buffers or resizes buffers
it simply transfers bytes to or from the buffer provided. Exceptions to this
rule are possible through the [Buffer Interface Traits](#buffer-interface-traits)
[^AS1]. The interface aims to support implementations that wish to avoid
unnecessary buffering. It should be simple to write a transfer method that
passes a supplied buffer directly to an OS system call. Buffering can be added
in wrapper layers as needed.


[^AS1]: e.g. if `ToBufferInterface(buffer) == ToPush()` data is pushed into the
buffer, which may lead to resizing.

**Termination:** The `transfer!` function is specified to "transfer at most `n`
items" and "Return the number of items transferred".
i.e. if some amount of data is available, return it right away rather than
waiting for the entire requested amount. This behaviour can easily be wrapped
with a retry layer to support cases where all `n` items are required.

**Blocking:** By default the `transfer!` function waits indefinitely for
data to be available. Control over this behaviour is provided by the optional
`deadline=` argument. The `transfer!` function stops waiting when `deadline > time()`.
This interface allows non-blocking transfers (`deadline=0`), blocking transfers
(`deadline=Inf`) or anything in between.[^AS2]

[^AS2]: Note that `transfer!` will always return data that is immediately
available irrespective of the deadline. i.e. There is no race condition when
`deadline ~= time()`.

The combination of the chosen termination and blocking behavior leads to
two cases where `transfer!` returns zero: End of stream (EOF), and deadline
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


### Atomicity of Transfers

FIXME
 - byte transfers always atomic
 - multi-byte items
    - return zero if bytesavailable < ioelsize ?
    - if Unknown Availability try a transfer and error if not enough bytes
        - include the partial bytes in the exception object
        - warning with suggestion to wrap with a buffer


### Generic Code and Dependance on Traits

FIXME
 - Generic code may rely on e.g. Low Transfer Cost, or Known Transfer Size
 - Generic code should have assertions for these traits.
 - Generic code could promote streams to have required traits as needed
   (i.e. wrap with buffered stream).


### Stream Interface Functions

#### Stream Data Transfer Core Functions

--------------------------------------------------------------------------------
Function                       Description
----------------------------   -------------------------------------------------
`transfer!(stream, buf, [n])`  Transfer at least one and at most `n` items
                               between `stream` and `buf`.
                               Return the number of items transferred.
                               See `TransferDirection`, `FromBufferInterface`
                               and `ToBufferInterface` traits.

`wait(stream; timeout=Inf)`    Wait until `stream` is ready to transfer data.
                               `transfer!` calls `wait` if there are no items
                               available.
                               See `WaitingMechanism` trait and
                               `set_poll_mechanism`.

`lock(stream)`                 Acquire a task-exclusive lock on `stream`.
                               A `Stream` must be locked before `wait` is
                               called.

`unlock(stream)`               Reverse the effect of `lock`.

`max_transfer_size(stream)`    Maximum number of bytes per call to `transfer!`.
                               See `TransferSize` trait.
--------------------------------------------------------------------------------


#### Stream Data Transfer Conveniance Methods

--------------------------------------------------------------------------------
Function                               Description
-------------------------------------- -----------------------------------------
`transfer!(...; timeout=Inf)`          Wait `timeout` seconds if no items
                                       are available to transfer.

`transfer!(stream => buf, [n])`        Transfer data from `stream` to `buf`.

`transfer!(buf => stream, [n])`        Transfer data from `buf` to `stream`.

`transfer!(stream, buf; start=i)`      Transfer data starting at `buf` index `i`.

`transfer!(stream, buf; start=(i,j))`  Transfer data starting at
                                       `stream` index `i` and `buf` index `j`.
                                       See `StreamIndexing` trait.

`transferall!(stream, buf, [n])` \     Transfer all `n` items between
`transferall!(stream => buf, [n])` \   `stream` and `buf`.
`transferall!(buf => stream, [n])` \   

`transferall!(...; timeout=Inf)`       Stop waiting for more items after
                                       `timeout`.

`readall!(stream) -> Vector{UInt8}`    Transfer all items from `stream` into
                                       a new byte buffer.
--------------------------------------------------------------------------------


#### Stream Data Transfer Driver API

--------------------------------------------------------------------------------
Function                                Description
--------------------------------------- ----------------------------------------

`unsafe_transfer!(stream, p, n) -> n`   Transfer at least `n` bytes between
                                        `stream` and `p::Ptr{UInt8}`.
                                        Return the number of bytes transferred.

--------------------------------------------------------------------------------


#### Stream Lifecycle State Functions

A `Stream` begins its life in "connected" and "open" state.
A `Stream` might be spontaneously "disconnected" by an external event
(e.g. when a peer a hangs up a connection).
A `Stream` can only be "closed" by the `close` function.


--------------------------------------------------------------------------------
Function                   Description
-------------------------- -----------------------------------------------------
`isconnected(stream)`      True if the underlying data source/sink is
                           still available through `stream`.

`isopen(stream)`           True unless `close(stream)` is called.

`close(stream)`            Signal that the program is finished with `stream`.
                           If stream is an output, call `flush(stream)`.
                           Disconnect the underlying data source/sink. \
                           After `close` is called, `isopen` and `isconnected`
                           are both False. \
                           Most `Stream` funtions have `isopen(stream)` as
                           a precondition, so calling other stream functions
                           after `close` is likely to cause an exception.
--------------------------------------------------------------------------------


#### Input Stream Query Functions

--------------------------------------------------------------------------------
Function                        Description
------------------------------- ------------------------------------------------
`length_is_known(stream)`       True if the total number of bytes available from
                                the stream is known.
                                See `TotalSize` trait.

`length(stream)`                Total number of bytes available from the stream.
                                `missing` if unknown.

`position_is_known(stream)`     True if `position(stream)` is known.
                                See `CursorSupport` trait.

`position(stream)`              Byte position relative to start of `stream`.
                                The first byte in `position` zero.
                                `missing` if unknown.

`bytesremaining(stream)`        Number of bytes remaining to be transferred from
                                the stream. 
                                `missing` if unknown.
                                If `length_is_known` this is the same as
                                `length(stream) - position(stream)`.

`isfinished(stream)`            True if there are no bytes remaining to be
                                transferred from the stream. \
                                If `length_is_known` them this is the same as
                                `bytesremaining(stream) == 0`, otherwise
                                `isfinished` is only true when `isconnected`
                                is false.

`availability_is_known(stream)` True if the number of bytes immediately
                                available for transfer is known.
                                See `Availability` trait.

`bytesavailable(stream)`        Number of bytes immediately ready for transfer.
                                `missing` if unknown.
                                See `TransferSizeMechanism` trait.
--------------------------------------------------------------------------------

Note that the query functions above are all side-effect free.

Failure to ensure that query methods for all stream types are side-effect free
can lead to subtle bugs.

Consider the following method:

```julia
position(s::BufferedInput) = position(s.stream) - bytesavailable(s.buffer)
```

The current position is the number of bytes that have been taken from the
stream, less the number of bytes buffered but not yet transferred to the user.
Imagine that `bytesavailable(s.buffer)` was designed to refill the buffer 
from the stream on demand before returning the number of buffered bytes.
The `position(s::BufferedInput)` method would return an invalid result because
the value of `position(s.stream)` is altered by the side-effect in
`bytesavailable(s.buffer)`.



### Notes

TODO:
Note about back-pressure, the problem with reading too fast into a big buffer


### Methods of Base Functions for Streams


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

Base.islocked(s::Stream) = is_proxy(s) ? islocked(unwrap(s)) :
    @warn "Base.islocked(::$(typeof(s)) not defined!"

Base.lock(s::Stream) = is_proxy(s) ? lock(unwrap(s)) :
    @warn "Base.lock(::$(typeof(s)) not defined!"

Base.unlock(s::Stream) = is_proxy(s) ? unlock(unwrap(s)) :
    @warn "Base.unlock(::$(typeof(s)) not defined!"

@db function Base.wait(s::Stream; deadline=Inf, timeout=Inf)
    deadline = deadline_or_timeout(deadline, timeout)             ;@db deadline
    is_proxy(s) ? wait(unwrap(s); deadline) :
                 _wait(s, WaitingMechanism(s); deadline)
end

@db function Base.bytesavailable(s::Stream)
    @db_not_tested is_proxy(s)
    @require is_input(s)
    @require isopen(s)
    is_proxy(s) ? bytesavailable(unwrap(s)) :
                  _bytesavailable(s, Availability(s), TransferSize(s))
end

@db function Base.length(s::Stream)
    @require isopen(s)
    @require length_is_known(s)
    s = unwrap(s)
    _length(s, TotalSizeMechanism(s))
end


@db function Base.position(s::Stream)
    @db_not_tested is_proxy(s)
    @require isopen(s)
    @require CursorSupport(s) isa AbstractHasPosition
    s = unwrap(s)
    _position(s, CursorSupport(s))
end

@db function Base.readline(s::Stream; keep=false, timeout=Inf)
    @db_not_tested is_proxy(s)
    @require isopen(s)
    @require is_input(s)
    s = unwrap(s)
    _readline(s, ReadFragmentation(s); keep, timeout)
end

@db function Base.peek(s::Stream, ::Type{T}; timeout=Inf) where T
    @db_not_tested
    @db_not_tested is_proxy(s)
    @require isopen(s)
    @require is_input(s)
    s = unwrap(s)
    _peek(s, PeekSupport(s), T; timeout)
end

pump!(s::Stream; deadline) = is_proxy(s) ? pump!(unwrap(s); deadline) : nothing



### Stream Delegation Wrappers

"""
The StreamDelegation trait allows a Stream subtype to delegate most method
calls to a wrapped substream while redefining other methods as needed.

Wrappers are used to augment low level stream drivers with features like buffering
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
-- Retrieves the underlying stream that is wrapped by a proxy stream.
"""
unwrap(s) = unwrap(s, StreamDelegation(s))
unwrap(s, ::NotDelegated) = s
unwrap(s, ::DelegatedToSubStream) = s.stream
unwrap(T::Type, ::DelegatedToSubStream) = fieldtype(T, :stream)



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

verb(::In) = "from"
verb(::Out) = "to"


"""
The constructor `BaseIOStream(::Base.IO) -> IOTraits.Stream` creates a Stream
compatible wrapper around a Base.IO.
"""
struct BaseIOStream{T<:Base.IO,D<:TransferDirection} <: Stream
    io::T
end

TransferDirection(::Type{BaseIOStream{T, D}}) where {T, D} = D()

Base.isopen(s::BaseIOStream) = isopen(s.io)


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
@selfdoc ioelsize(s) = sizeof(ioeltype(s))



# Data Transfer Function

"""
    transfer!(stream, buffer, [n]; start=1, deadline=Inf) -> n_transfered

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

The direction of transfer depends on
`TransferDirection(stream) ->` (`In`, `Out` or `Exchange`).

The type of items transferred depends on `ioeltype(buffer)`.[^ELTYPE]

[^ELTYPE]: By default `ioeltype(x) = eltype(x)`.

The `buffer` can be an `AbstractArray`, an `AbstractChannel`, a `URI`,
a `Base.IO`, or another `Stream`.
Or, the `buffer` can be any collection that implements
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
@db function transfer!(stream, buf, n::Union{Integer,Missing}=missing;
                       start::Union{Integer, NTuple{2,Integer}}=UInt(1),
                       deadline=Inf, timeout=Inf)

    @require isopen(stream)
    @require ismissing(n) || n > 0
    @require all(start .> 0)          ;@db typeof(stream) start deadline timeout
    n = _transfer!(stream, buf, n, start, deadline_or_timeout(deadline, timeout))
    transfer_complete(stream, buf, n)
    @ensure n isa UInt
    @db return n
end

function deadline_or_timeout(deadline, timeout)
    Float64((timeout == 0)   ? 0 :
            (timeout == Inf) ? deadline :
                               (time() + timeout))
end

transfer!(a...; timeout) = transfer!(a...; deadline=time() + Float64(timeout))


"""
`transfer_complete` is called at the end of the top-level `transfer!` method.
A single call to the top-level `tansfer!` method may result in many calls to
low level driver methods. e.g. to transfer every item in a collection.
The `transfer_complete` hook can be used, for example, to flush an output
buffer at end of a transfer.
"""
transfer_complete(stream, buf, n) = nothing


"""
### `transfer!(a => b)`

    transfer!(stream => buffer, [n]; start=(1 => 1), kw...) -> n_transfered
    transfer!(buffer => stream, [n]; start=(1 => 1), kw...) -> n_transfered

`stream` and `buffer` can be passed to `transfer!` as a pair.
`In` streams must be on the left.
`Out` streams must be on the right.
"""
function transfer!(t::Pair{<:Stream, <:Any}, a...; start=(1 => 1), kw...)
    @require TransferDirection(t[1]) == In()
    if start isa Pair
        start = (start[1], start[2])
    end
    transfer!(t[1], t[2], a...; start, kw...)
end

function transfer!(t::Pair{<:Any,<:Stream}, a...; start=(1 => 1), kw...)
    @require TransferDirection(t[2]) == Out()
    if start isa Pair
        start = (start[2], start[1])
    end
    transfer!(t[2], t[1], a...; start=start, kw...)
end



## Waiting for the Deadline

idoc"""
The specification for `transfer!` says: If no items are immediately available,
wait until `time() > deadline` for at least one item to be transferred.

The method below starts by simply attempting the transfer.
This avoids the overhead of locking and measuring the current time.
If the initial transfer attempt yields no data, the `wait_for_transfer`
method is selected based on Waiting Mechanism trait.

If the buffer elements are larger than one byte and the stream has
Unknown Availability then `attempt_transfer` can end up with a
partial item in the buffer. In this situation a second attempt is needed
to transfer the missing bytes. A TimeoutStream wrapper is used to ensure
that the second transfer adheres to the specified deadline.

"""
@db 2 function _transfer!(stream, buffer, n, start, deadline::Float64)

    if Availability(stream) == UnknownAvailability() &&
    ioelsize(buffer) != 1 &&
    deadline != Inf
        stream = timeout_stream(stream; deadline)
    end

    r = attempt_transfer(stream, buffer, n, start)
    if r > 0 || iszero(deadline)
        @db 2 return r
    end
    if deadline == 0.0
        @db_not_tested
        @db 2 return 0
    end
    wait_for_transfer(stream, WaitingMechanism(stream),
                      buffer, n, start, deadline)
end



# Waiting Mechanism Trait

abstract type WaitingMechanism end
struct WaitBySleeping     <: WaitingMechanism end
struct WaitUsingPosixPoll <: WaitingMechanism end
struct WaitUsingEPoll     <: WaitingMechanism end
struct WaitUsingPidFD     <: WaitingMechanism end
struct WaitUsingKQueue    <: WaitingMechanism end
struct WaitUsingIOURing   <: WaitingMechanism end



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

`WaitUsingPosixPoll`  Wait using the POSIX `poll` mechanism.
                      Wait for activity on a set of file descriptors.
                      Applicable to FIFO pipes, sockets and character devices
                      (but not local files).  See [`poll(2)`][poll]

`WaitUsingEPoll`      Wait using the Linux `epoll` mechanism.
                      Like `poll` but scales better for workloads with a large
                      number of waiting streams.
                      See [`epoll(7)`][epoll]

`WaitUsingIOURing`    Wait using the Linux `io_uring` mechanism.
                      Works with local disk files.
                      See [`io_uring(7)`][io_uring]

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
[io_uring]: https://manpages.debian.org/unstable/liburing-dev/io_uring.7.en.html

[^SLEEP]: Sleeping may be the most efficient mechanism for small systems with
simple IO requirements, for large systems where throughput is more important
than latency, or for systems that simply do not spend a lot of time
waiting for IO. Sleeping allows other Julia tasks to run immediately, whereas
the other polling mechanisms all have some amount of book-keeping and system
call overhead.

FIXME: Conditer WaitWithoutYeilding -- Block calling thread.
 - Might be useful where low latency is important.
"""
WaitingMechanism(x) = WaitingMechanism(typeof(x))
WaitingMechanism(T::Type) = is_proxy(T) ? WaitingMechanism(unwrap(T)) :
                                          WaitBySleeping()

Base.isvalid(::WaitingMechanism) = true
Base.isvalid(::WaitUsingEPoll) = Sys.islinux()
Base.isvalid(::WaitUsingPidFD) = Sys.islinux()
Base.isvalid(::WaitUsingIOURing) = Sys.islinux()
Base.isvalid(::WaitUsingKQueue) = Sys.isbsd() && false # not yet implemented.

firstvalid(x, xs...) = isvalid(x) ? x : firstvalid(xs...)

const default_poll_mechanism = firstvalid(WaitUsingKQueue(),
                                          WaitUsingIOURing(),
                                          WaitUsingEPoll(),
                                          WaitUsingPosixPoll(),
                                          WaitBySleeping())

_wait(x, ::WaitBySleeping; deadline=Inf) = sleep(0.1)


@static if VERSION > v"1.6"
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

poll_mechanism(name) = name == "io_uring" ? WaitUsingIOURing() :
                       name == "kqueue"   ? WaitUsingKQueue() :
                       name == "epoll"    ? WaitUsingEPoll() :
                       name == "poll"     ? WaitUsingPosixPoll() :
                       name == "sleep"    ? WaitBySleeping() :
                                            default_poll_mechanism

const preferred_poll_mechanism = begin
    pm = poll_mechanism(@load_preference("waiting_mechanism"))
    isvalid(pm) ? pm : default_poll_mechanism
end
else
const preferred_poll_mechanism = default_poll_mechanism
end



## Wait By Sleeping Method

idoc"""
The Wait By Sleeping method for `wait_for_transfer` calls `attempt_transfer`
in a loop until data is available or the deadline is reached.

An exponentially increasing sleep delay minimises latency for short waits and
limits CPU use for longer waits.
"""
const delay_sequence =
    ExponentialBackOff(;n = typemax(Int),
                        first_delay = 0.01, factor = 1.2, max_delay = 0.25)

@db function wait_for_transfer(stream, ::WaitBySleeping,
                               buf, n, start, deadline::Float64)
    for delay in delay_sequence
        r = attempt_transfer(stream, buf, n, start);
        if r > 0
            @db return r
        end
        if time() >= deadline
            @db return UInt(0)
        end
        sleep(delay)
    end
end


## Specialised Waiting Methods

idoc"""
In the default waiting method, `wait` is called in a loop until data is
available or the deadline is reached. The appropriate `wait` method will
be selected according to Waiting Mechanism.

`Base.lock` and `Base.unlock` must be implemented for each stream type.[^LOCK]

[^LOCK]: These methods should do whatever is necessary to avoid race conditions
between `Base.wait` and `attempt_transfer`. (FIXME, ... and `bytesavailable`)
In UnixIO.jl `Base.wait` waits for a `ThreadSynchronizer` and the underlying
polling mechanism notifies the `ThreadSynchronizer` to wake up the waiting task.
"""
@db function wait_for_transfer(stream, ::WaitingMechanism,
                               buf, n, start, deadline::Float64)
    @db time() deadline
    @dblock stream begin
        while !isfinished(stream)
            pump!(stream; deadline)
            wait(stream; deadline)
            r = attempt_transfer(stream, buf, n, start);
            if r > 0
                @db return r
            end
            if time() >= deadline
                break
            end
        end
        @db return UInt(0)
    end
end



# Buffer Interface Traits

abstract type BufferInterface end
struct UsingIndex <: BufferInterface end
struct UsingPtr <: BufferInterface end
struct IsItemPtr <: BufferInterface end
struct IsBytePtr <: BufferInterface end
struct FromIO <: BufferInterface end
struct FromStream <: BufferInterface end
struct FromPop <: BufferInterface end
struct FromTake <: BufferInterface end
struct FromIteration <: BufferInterface end
struct ToIO <: BufferInterface end
struct ToStream <: BufferInterface end
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
| `FromStream()`    | Take data from the `IOTraits.Stream` interface.          |
| `FromPop()`       | Use `pop!(buffer)` to read from the buffer.              |
| `FromTake()`      | Use `take!(buffer)`.                                     |
| `FromIteration()` | Use `for x in buffer...`.                                |
| `UsingIndex()`    | Use `buffer[i]` (the default).                           |
| `UsingPtr()`      | Use `unsafe_copyto!(x, pointer(buffer), n)`.             | 
| `IsItemPtr()`     | Use `unsafe_copyto!(x, buffer, n)`.                      | 
| `IsBytePtr()`     | Special case of `IsItemPtr` for `ioelsize(buffer) == 1`. |

Default `FromBufferInterface` methods are built-in for common buffer types:
"""
FromBufferInterface(x) = FromBufferInterface(typeof(x))
FromBufferInterface(::Type) = FromIteration()
FromBufferInterface(::Type{<:IO}) = FromIO()
FromBufferInterface(::Type{<:Stream}) = FromStream()
FromBufferInterface(::Type{<:AbstractChannel}) = FromTake()
FromBufferInterface(::Type{<:Ref}) = UsingPtr()
FromBufferInterface(::Type{<:Ptr{T}}) where T = sizeof(T) == 1 ? IsBytePtr() :
                                                                 IsItemPtr()


"""
Pointers can be used for `AbstractArray` buffers of Bits types.
"""
FromBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)

ArrayIOInterface(::Type) = UsingIndex()

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
| `ToStream`     | Write data using the `IOTraits.Stream` interface.           |
| `ToPush`       | Use `push!(buffer, data)`.                                  |
| `ToPut`        | Use `put!(buffer, data)`.                                   |
| `UsingIndex`   | Use `buffer[i] = data (the default)`.                       |
| `UsingPtr`     | Use `unsafe_copyto!(pointer(buffer), x, n)`.                |
| `IsItemPtr`    | Use `unsafe_copyto!(buffer, x, n)`.                         |
| `IsBytePtr`    | Special case of `IsItemPtr` for `ioelsize(buffer) == 1`.    |

Default `ToBufferInterface` methods are built-in for common buffer types.
"""

ToBufferInterface(x) = ToBufferInterface(typeof(x))
ToBufferInterface(::Type) = ToPush()
ToBufferInterface(::Type{<:IO}) = ToIO()
ToBufferInterface(::Type{<:Stream}) = ToStream()
ToBufferInterface(::Type{<:AbstractChannel}) = ToPut()
ToBufferInterface(::Type{<:Ref}) = UsingPtr()
ToBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)
ToBufferInterface(::Type{<:Ptr{T}}) where T = sizeof(T) == 1 ? IsBytePtr() :
                                                               IsItemPtr()



# Total Data Size Trait

abstract type TotalSize end
struct UnknownTotalSize <: TotalSize end
struct InfiniteTotalSize <: TotalSize end
abstract type KnownTotalSize <: TotalSize end
struct VariableTotalSize <: KnownTotalSize end
struct FixedTotalSize <: KnownTotalSize end
const AnyTotalSize = TotalSize

"""
The `TotalSize` trait describes how much data is available from a stream.

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

`UnknownTotalSize()`    No known data size limit. But end of file may be
                        reached. e.g. if the other end is closed.
--------------------------------------------------------------------------------
"""
TotalSize(x) = TotalSize(typeof(x))
TotalSize(T::Type) = is_proxy(T) ? TotalSize(unwrap(T)) :
                                   UnknownTotalSize()
length_is_known(x) = TotalSize(x) isa KnownTotalSize


abstract type SizeMechanism end
struct NoSizeMechanism <: SizeMechanism end
struct SupportsStatSize <: SizeMechanism end
struct SupportsFIONREAD <: SizeMechanism end
TotalSizeMechanism(x) = TotalSizeMechanism(typeof(x))
TotalSizeMechanism(T::Type) = is_proxy(T) ? TotalSizeMechanism(unwrap(T)) :
                                            NoSizeMechanism()

@db function _length(stream, ::SupportsStatSize)
    stat(stream).size
end



# Transfer Size Trait

abstract type TransferSize end
struct UnlimitedTransferSize <: TransferSize end
struct LimitedTransferSize <: TransferSize end
struct FixedTransferSize <: TransferSize end
const AnyTransferSize = TransferSize

"""
The `TransferSize` trait describes how much data can be moved in a single
transfer.

`TransferSize(stream)` returns one of:

--------------------------------------------------------------------------------
Transfer Size             Description
------------------------- ------------------------------------------------------
`UnlimitedTransferSize()` No known transfer size limit.

`LimitedTransferSize()`   The amount of data that can be moved in a single
                          transfer is limited. e.g. by a device block size or
                          buffer size. The maximum transfer size can queried
                          using the `max_transfer_size` function.

`FixedTransferSize()`     The amount of data moved by a single transfer is
                          fixed. e.g. `/dev/input/event0` device always
                          transfers `sizeof(input_event)` bytes.
--------------------------------------------------------------------------------
"""
TransferSize(s) = TransferSize(typeof(s))
TransferSize(T::Type) = is_proxy(T) ?  TransferSize(unwrap(T)) :
                                       UnlimitedTransferSize()

max_transfer_size(s) = max_transfer_size(s, TransferSize(s), TotalSize(s))
max_transfer_size(s, ::AnyTransferSize, ::AnyTotalSize) = typemax(UInt)
max_transfer_size(s, ::UnlimitedTransferSize, ::KnownTotalSize) = length(s)
max_transfer_size(s, ::LimitedTransferSize, ::AnyTotalSize) = 
    max_transfer_size(s, TransferSizeMechanism(s))



"""
`TransferSizeMechanism(stream)` returns one of:

FIXME look at `F_GETPIPE_SZ` and `SO_SNDBUF`

 * `SupportsFIONREAD()` -- The underlying device supports `ioctl(2), FIONREAD`.
 * `SupportsStatSize()` -- The underlying device supports  `fstat(2), st_size`.
"""
TransferSizeMechanism(s) = TransferSizeMechanism(typeof(s))
TransferSizeMechanism(T::Type) = is_proxy(T) ?
                                 TransferSizeMechanism(unwrap(T)) :
                                 NoSizeMechanism()



# Data Availability Trait

abstract type Availability end
struct AlwaysAvailable <: Availability end
struct PartiallyAvailable <: Availability end
struct UnknownAvailability <: Availability end
const AnyAvailability = Availability


"""
The `Availability` trait describes when data is available from a stream.

`Availability(stream)` returns one of:

--------------------------------------------------------------------------------
Availability            Description
----------------------- --------------------------------------------------------
`AlwaysAvailable()`     Data is always immediately available.
                        i.e. `bytesavailable` === `bytesremaining`.
                        Applicable to some device files (dev/event, /dev/zero).
                        Applicable to local disk files.

`PartiallyAvailable()`  Some data may be immediately available from a buffer,
                        but `bytesavailable` can be less than `bytesremaining`.
                        `bytesavailable` may be 0 (e.g. when a buffer is empty)
                        even if a subsequent transfer would yeild more data.

`UnknownAvailability()` There is no mechanism for determining data availability.
                        The only way to know how much data is available is to
                        attempt a transfer.
                        i.e. `bytesavailable` is always 0.
--------------------------------------------------------------------------------
"""
Availability(x) = Availability(typeof(x))
Availability(T::Type) = is_proxy(T) ? Availability(unwrap(T)) :
                                      UnknownAvailability()

availability_is_unknown(x) = Availability(x) == UnknownAvailability()
availability_is_known(x) = !availability_is_unknown(x)

@db function _bytesavailable(s, ::UnknownAvailability, ::AnyTransferSize)
    @db_not_tested
    missing
end

@db function _bytesavailable(s, ::AlwaysAvailable, ::UnlimitedTransferSize)
    bytesremaining(s)
end

@db function _bytesavailable(s, ::AlwaysAvailable, ::FixedTransferSize)
    @db_not_tested
    max_transfer_size(s)
end


@db function _bytesavailable(s, ::PartiallyAvailable, ::AnyTransferSize)
    _bytesavailable(s, TransferSizeMechanism(s))
end


@db function wait_for_n_bytes(s, n; deadline=Inf)
    @db_not_tested
    @require availability_is_known(s)
    if bytesavailable(s) >= n
        @db return
    end

    while time() < deadline
        pump!(s; deadline)
        @dblock s begin
            if bytesavailable(s) >= n
                @db return
            end
            wait(s; deadline)
        end
    end
    nothing
end


wait_for_n_bytes(a...; timeout) =
    wait_for_n_bytes(a...; deadline = time() + timeout)


# Transfer Function Dispatch

"""
    attempt_transfer(stream, buf, n, start)

Transfer at most `n` items between `stream` and `buffer`.
Return the number of items transferred.
"""
function attempt_transfer end

idoc"""
## `start` Index Normalisation

If `start` is a Tuple of indexes it is normalised by the method below.
The `StreamIndexing` trait is used to check that `stream` supports indexing.
Indexable streams are replaced by a `Tuple` containing `stream` and the
stream index.
"""
@db function attempt_transfer(stream, buf, n, start::Tuple)
    @require StreamIndexing(stream) == IndexableIO() || start[1] == 1
    @require start >= (1,1)
    if start[1] != 1
        @db_not_tested
        stream = (stream, UInt(start[1]))
    end
    attempt_transfer(stream, buf, n, UInt(start[2]))
end

idoc"""
From here on, `start` is always a simple `UInt` index into `buf`.


## Application of the Direction and Buffer Interface Traits

Next, the `IODriection` and `BufferInterface` traits are inserted into the
argument list.[^InOut]

[^InOut]: Note that although the `IODirection` is now part of the argument
list, premature specialisation on direction is avoided. Eventually
most transfers will end up calling an OS `read` or `write` function.
However, much of the transfer logic is the same irrespective of direction.
For example, the methods for `UsingPtr` and `UsingIndex` below work for
both input and output. (Another consideration is supporting interfaces with
`IODirection` `Exchange`).
"""
@db function attempt_transfer(stream, buf, n, start=UInt(1))
    buf_api = is_input(stream)  ? ToBufferInterface(buf) :
              is_output(stream) ? FromBufferInterface(buf) :
                                  ExchangeBufferInterface(buf)
    _attempt_transfer(stream, buf, buf_api, n, start)
end

@db 2 function _attempt_transfer(stream, buf, n, start)
    _attempt_transfer(stream, In(), buf, ToBufferInterface(buf), n, start)
end

@db 2 function _attempt_transfer(stream, ::Out, buf, n, start)
    _attempt_transfer(stream, Out(), buf, FromBufferInterface(buf), n, start)
end



## Low Level Byte-Stream Methods

idoc"""
The specialised methods for various Buffer Interfaces eventually
call this this IsBytePtr method, which in turn calls the low level
`unsafe_transfer!` implementation methods.
"""
@db 2 function _attempt_transfer(stream,
                                 buf::Ptr{UInt8}, ::IsBytePtr,
                                 n::UInt, start::UInt)
    r = unsafe_transfer!(stream, buf + (start-1), n)
    @ensure r isa UInt
    @db 2 return r
end


idoc"""
This method handles items larger than one byte.
It returns zero if there are not enough bytes available for a whole item.
For streams with Unknown Transfer Size the requested transfer is attempted 
but an error is thrown if a partial item is transferred.
"""
@db 2 function _attempt_transfer(stream,
                                 buf, ::IsItemPtr, n::UInt, start::UInt)
    @db_not_tested
    sz = ioelsize(buf)
    @assert sz > 1
    if Availability(stream) != UnknownAvailability()
        n::UInt = min(n, bytesavailable(stream) ÷ sz)
        n > 0 || @db 2 return UInt(0)
    end

    buf = Ptr{UInt8}(buf)
    start = 1 + ((start-1) * sz)

    r = _attempt_transfer(stream, buf, IsBytePtr(), n * sz, start)
    @ensure r isa UInt

    if r % sz != 0
        @assert Availability(stream) == UnknownAvailability()
        r += transferall!(stream, buf + (start-1) + r, r % sz)
    end
    if r % sz != 0
        throw(IOTraitsError(stream,
              "Partial Transfer Error: " *
              "Transfer $(verb(direction)) $stream returned $r bytes " *
              "but $(typeof(buf)) has $sz-byte elements " *
              "($r % $sz = $(r % sz)).\n" *
              "Consider using BufferedInput(stream) to ensure that " *
              "`Availability(stream) != UnknownAvailability`."))
    end
    r ÷= sz
    @ensure r <= n
    @db 2 return r
end


"""
At least one of the following `unsafe_transfer!` methods must be implemented
for each type `T <: IOTraits.Stream`:

    unsafe_transfer!(s::T, ::IOTraits.In,           buffer::Ptr{UInt8}, n::UInt)
    unsafe_transfer!(s::T, ::IOTraits.Out,          buffer::Ptr{UInt8}, n::UInt)
    unsafe_transfer!(s::T, ::IOTraits.Exchange,     buffer::Ptr{UInt8}, n::UInt)
    unsafe_transfer!(s::T, ::IOTraits.AnyDirection, buffer::Ptr{UInt8}, n::UInt)

`unsafe_transfer!` should transfer at most `n` bytes between `stream` and
`buffer` and return the number of items transferred (or zero if no bytes are
immediately available)[^BLOCKING].

[^BLOCKING]: ⚠️ Note that the `BaseIOStream` methods defined here do
not properly implement the specification because `unsafe_read` and
`unsafe_write` may block to wait for data. These methods are intended
for testing purposes only.  The transfer timeout feature will not
work properly for `BaseIOStream`.
"""
function unsafe_transfer! end


@db function unsafe_transfer!(s::BaseIOStream, buf::Ptr{UInt8}, n::UInt)
    @db_not_tested
    is_input(s) ? UInt(unsafe_read(s.io, buf, n)) :
                  UInt(unsafe_write(s.io, buf, n))
end


## Transfer Specialisations for Indexable Buffers

idoc"""
If `n` is missing, use the whole length of the buffer.

After this both `n` and `start` are always `UInt`s.
"""
@db 2 function _attempt_transfer(stream,
                                 buf, interface::Union{UsingPtr, UsingIndex},
                                 n::Missing, start::UInt)
    @require length(buf) > 0
    n = length(buf) - (start - 1)
    _attempt_transfer(stream, buf, interface, UInt(n), start)
end

@db 2 function _attempt_transfer(stream,
                                 buf, interface, n::Missing, start::UInt)
    _attempt_transfer(stream, buf, interface, typemax(UInt), start)
end

@db 2 function _attempt_transfer(stream,
                                 buf, interface, n::Integer, start::Integer)
    _attempt_transfer(stream, buf, interface, UInt(n), UInt(start))
end


idoc"""
If the buffer is pointer-compatible convert it to a pointer.
"""
@db 2 function _attempt_transfer(stream,
                                 buf, ::UsingPtr, n::UInt, start::UInt)
    checkbounds(buf, (start-1) + n)
    GC.@preserve buf attempt_transfer(stream, pointer(buf, start), n, 1)
end

@db 2 function _attempt_transfer(stream,
                                 buf::Ref, ::UsingPtr, n::UInt, start::UInt)
    p = Base.unsafe_convert(Ptr{eltype(buf)}, buf)
    GC.@preserve buf attempt_transfer(stream, p, n, 1)
end


idoc"""
If the buffer is not pointer-compatible, transfer one item at a time.
"""
@db 2 function _attempt_transfer(stream,
                                 buf, ::UsingIndex, n::UInt, start::UInt)
    @db_not_tested
    T = ioeltype(buf)
    x = Vector{T}(undef, 1)
    count::UInt = 0
    for i in eachindex(view(buf, start:(start-1)+n))
        if is_output(stream)
            x[1] = buf[i]
        end
        n = transfer!(stream, x; deadline=0)
        if n == 0
            @db_not_tested
            break
        end
        if is_input(stream)
            buf[i] = x[1]
        end
        count += n
        stream = next_stream_index(stream, T)
    end
    @db 2 return count
end

next_stream_index((stream, i), T) = (stream, i + sizeof(T))
next_stream_index(stream::Stream, T) = stream


## Transfer Specialisations for Iterable Buffers

idoc"""
Iterate over `buf` (skip items until `start` index is reached).
Transfer each item one at a time.
"""
@db 2 function _attempt_transfer(stream,
                                 buf, ::FromIteration, n::UInt, start::UInt)
    @require is_output(stream)
    count::UInt = 0
    for x in buf
        if start > 1
            start -= 1
            @db_not_tested
            continue
        end
        n = transfer!(stream, [x]; deadline=0)
        if n == 0
            @db_not_tested
            break
        end
        count += n
        stream = next_stream_index(stream, ioeltype(buf))
    end
    return count
end



## Transfer Specialisations for Collection Buffers

for (T, f) in [ToPut => put!,
              ToPush => push!,
              FromPop => pop!,
              FromTake => take!]
    eval(:(_attempt_transfer(s, buf, ::$T, n::UInt, start::UInt) =
           _attempt_transfer_f(s, buf, $f, n, start)))
end

@db 2 function _attempt_transfer_f(stream,
                                   buf, f::Function, n::UInt, start::UInt)
    @db_not_tested
    @require start == 1
    T = ioeltype(buf)
    x = Vector{T}(undef, 1)
    count::UInt = 0
    while count < n
        if is_output(stream)
            (x[1] = f(buf))
        end
        r = transfer!(stream, x; deadline=0)
        if r == 0
            @db_not_tested
            break
        end
        if is_input(stream)
            f(buf, x[1])
        end
        count += r
        stream = next_stream_index(stream, T)
    end
    @db 2 return count
end



## Transfer Specialisations for IO Buffers

@db 2 function _attempt_transfer(s1, s2, ::ToStream, n::UInt, start::UInt)
    @require is_input(s1)
    @require is_output(s2)
    @db_not_tested
    buf = Vector{UInt8}(undef, min(n, max(default_buffer_size(s1),
                                          default_buffer_size(s2))))
    count::UInt = 0
    while count < n
        r = transfer!(s1 => buf; deadline=0)
        if r == 0
            @db_not_tested
            break
        end
        r2 = transfer!(buf => s2, r)
        @assert r2 == r
        # FIXME should query available capacity and not read more than that?
        count += r
    end
    return count
end


@db 2 function _attempt_transfer(s1, s2, ::FromStream, n::UInt, start::UInt)
    @require is_output(s1)
    @require is_input(s2)
    @db_not_tested
    _attempt_transfer(s2, In(), s1, ToStream(), n, start)
end


@db 2 function _attempt_transfer(s, io::T, ::ToIO, n::UInt, start::UInt) where T
    @db_not_tested
    @require is_input(s)
    _attempt_transfer(s, BaseIOStream{T, Out}(io), ToStream(), n, start)
end


@db 2 function _attempt_transfer(s, io::T, ::FromIO, n::UInt, start::UInt) where T
    @db_not_tested
    @require is_output(s)
    _attempt_transfer(s, BaseIOStream{T, In}(io), FromStream(), n, start)
end




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
TransferCost(T::Type) = is_proxy(T) ? TransferCost(unwrap(T)) :
                                      HighTransferCost()


const kBytesPerSecond = Int(1e3)
const MBytesPerSecond = Int(1e6)
const GBytesPerSecond = Int(1e9)
DataRate(s) = DataRate(typeof(s))
DataRate(T::Type) = is_proxy(T) ? DataRate(unwrap(T)) :
                                  MBytesPerSecond


# Cursor Traits (Mark & Seek)

abstract type CursorSupport end
abstract type AbstractHasPosition <: CursorSupport end
struct NoCursors <: CursorSupport end
struct HasPosition <: AbstractHasPosition end
struct Seekable  <: AbstractHasPosition end
struct Markable  <: AbstractHasPosition end

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

Base.seek(io::BaseIO, pos) = seek(io.stream, CursorSupport(io.stream), pos)
_seek(s, ::NoCursors, pos) = trait_error(s, Seekable)

Base.skip(io::BaseIO, offset) = _skip(io.stream, CursorSupport(io.stream), offset)
_skip(s, ::NoCursors, offset) = trait_error(s, Seekable)

# FIXME
#Base.position(io::BaseIO) = _position(io.stream, CursorSupport(io.stream))
_position(s, ::NoCursors) = nothing

Base.seekend(io::BaseIO) = _seekend(io.stream, CursorSupport(io.stream))
_seekend(s, ::NoCursors) = nothing

Base.mark(io::BaseIO) = _mark(io.stream, CursorSupport(io.stream))
_mark(s, ::NotMarkable) = trait_error(s, Markable)

Base.unmark(io::BaseIO) = _unmark(io.stream, CursorSupport(io.stream))
_unmark(s, ::NotMarkable) = trait_error(s, Markable)

Base.reset(io::BaseIO) = _reset(io.stream, CursorSupport(io.stream))
_reset(s, ::NotMarkable) = trait_error(s, Markable)

Base.ismarked(io::BaseIO) = _ismarked(io.stream, CursorSupport(io.stream))
_ismarked(s, ::NotMarkable) = trait_error(s, Markable)



# Peekable Trait

abstract type PeekSupport end
struct Peekable <: PeekSupport end
struct NotPeekable <: PeekSupport end
PeekSupport(s) = PeekSupport(typeof(s))
PeekSupport(T::Type) = is_proxy(T) ? PeekSupport(unwrap(T)) :
                                     NotPeekable()

_peek(s, ::NotPeekable, T) = trait_error(s, Peekable)



# Timeout Stream

"""
    TimeoutStream(stream; timeout, deadline) -> TimeoutStream
    timeout_stream(stream; timeout=Inf, deadline=Inf) -> Stream

The temporary `TimeoutStream` wrapper adds an immutable transfer deadline to a
stream. It is used in cases where a stream interface function needs to
make multiple calls to `transfer!` (e.g. `readall!`).

Note that the `timeout_stream` function simply returns `stream` if
`timeout` and `deadline` are both `Inf`.
"""
struct TimeoutStream{T<:Stream} <: Stream
    stream::T
    deadline::Float64
    function TimeoutStream(stream::T; timeout, deadline) where T
        @require (timeout == Inf) ⊻ (deadline == Inf)
        if timeout < Inf
            deadline = time() + timeout
        end
        new{T}(stream, deadline)
    end
end

timeout_stream(s::TimeoutStream; kw...) = timeout_stream(s.stream; kw...)

timeout_stream(s; timeout=Inf, deadline=Inf) =
    timeout == Inf && deadline == Inf ? s : TimeoutStream(s; timeout, deadline)

StreamDelegation(::Type{<:TimeoutStream}) = DelegatedToSubStream()

@db function transfer!(s::TimeoutStream{T}, buffer,
                       n::Union{Missing, Integer}; deadline=Inf, kw...) where T
    @db s.deadline
    transfer!(s.stream, buffer, n; deadline = min(deadline, s.deadline), kw...)
end

@db function pump!(s::TimeoutStream{T}; deadline=Inf, timeout=Inf) where T
    @db_not_tested
    deadline = deadline_or_timeout(deadline, timeout)
    pump!(s.stream; deadline = min(deadline, s.deadline))
end

@db function Base.wait(s::TimeoutStream{T}; deadline=Inf, timeout=Inf) where T
    @db_not_tested
    deadline = deadline_or_timeout(deadline, timeout)
    wait(s.stream; deadline = min(deadline, s.deadline))
end

@db function Base.eof(s::TimeoutStream{T}; deadline=Inf, timeout=Inf) where T
    deadline = deadline_or_timeout(deadline, timeout)
    eof(s.stream; deadline = min(deadline, s.deadline))
end

unsafe_transfer!(s::TimeoutStream, buffer, n) =
    unsafe_transfer!(s.stream, buffer, n)



# Interface Functions

"""
How many bytes remain before the end of `stream`?
"""
@db function bytesremaining(s::Stream)
    @require is_input(s)
    @require isopen(s)
    bytesremaining(s, TotalSize(s), CursorSupport(s))
end

bytesremaining(s, ::UnknownTotalSize, ::Any) = missing
bytesremaining(s, ::InfiniteTotalSize, ::Any) = typemax(UInt)

@db function bytesremaining(s, ::KnownTotalSize, ::AbstractHasPosition)
    length(s) - position(s)
end

#TODO: note about dispatch sequencing:
#   - first isproxy/unwrap
#   - then apply traits

#Classes of method:
#   - Conveniance interfcae method
#       - transforms inputs, implements default values
#       - no side-effects other than calling a core method
#   - Main interfcae method
#       - checks preconditions
#       - does not call other methods of same function
#       - calls Main imeplemetation method
#       - checks postcondition
#   - Main implementation method
#       - different non-exported name to interface method
#       - implements trait-based fan-out to other implenentation methods
#   




#FIXME rename isfinished -> isconnected ???


isconnected(s::Stream) = true

@db function isfinished(s::Stream)
    @require isopen(s)
    is_input(s) || @db return !isconnected(s)
    is_proxy(s) ? isfinished(unwrap(s)) : 
                  isfinished(s, TotalSize(s))
end

isfinished(s, ::UnknownTotalSize) = !isconnected(s)
isfinished(s, ::AnyTotalSize) = bytesremaining(s) == 0


"""
`readbyte` returns one byte
(or `nothing` at end of stream or if `deadline` expires).

Specialized based on Transfer Cost.
"""
function readbyte(s::Stream; deadline=Inf)
    @require is_input(s)
    readbyte(s, TransferCost(s); deadline)
end

readbyte(s, ::HighTransferCost; kw...) =
    error(typeof(s), " does not support byte I/O. ",
          "Consider using the `LazyBufferedInput` wrapper.")


idoc"""
Allow single byte read for interfaces with Low Transfer Cost,
but warn if a special Read Fragmentation trait is available.[^WARNINGS]

[^WARNINGS]: ⚠️ FIXME: Warnings should be configurable via Preferences.jl
"""
function readbyte(stream, ::LowTransferCost; deadline)
    if ReadFragmentation(stream) == ReadsLines()
        @warn "read(::$(typeof(stream)), UInt8): " *
              "$(typeof(stream)) implements `IOTraits.ReadsLines`." *
              "Reading one byte at a time may not be efficient." *
              "Consider using `readline` instead."
        @db_not_tested
    end
    x = Ref(UInt8(0))
    n = transfer!(stream => x, 1; deadline)
    n == 1 || return nothing
    return x[]
end



"""
`readall!` reads until the end of `stream` (or until `timeout` expires)
and returns `Vector{UInt8}`.

Specialise on Total Size and Cursor Support.
"""
@db function readall!(s::Stream; timeout=Inf)
    @require is_input(s)
    @require TotalSize(s) != InfiniteTotalSize() || timeout < Inf
    _readall!(s, TotalSize(s), CursorSupport(s); timeout)
end


@db function _readall!(stream, ::UnknownTotalSize, ::NoCursors; timeout=Inf)
    n = default_buffer_size(stream)
    buf = Vector{UInt8}(undef, n)
    stream = timeout_stream(stream; timeout)
    n = _readbytes!(stream, buf, typemax(UInt))
    resize!(buf, n)
    @db return buf
end


@db function _readall!(stream, ::KnownTotalSize, ::AbstractHasPosition; timeout=Inf)
    n = length(stream) - position(stream)
    buf = Vector{UInt8}(undef, n)
    transferall!(stream, buf, n; timeout)
    @db return buf
end


"""
Transfer `n` items between `stream` and `buf`.

Call `transfer` repeatedly until all `n` items have been Transferred, 
stopping only if end of file is reached.

Return the number of items transferred.
"""
@db function transferall!(stream, buf, n=length(buf); deadline=Inf, timeout=Inf)
    @require deadline == Inf || timeout == Inf
    @require TotalSize(stream) != InfiniteTotalSize() || (deadline + timeout < Inf)

    stream = timeout_stream(stream; timeout, deadline)
    ntransferred::UInt = 0
    while ntransferred < n
        r = transfer!(stream, buf, n - ntransferred; start = ntransferred + 1)
                                            # FIXME ^^^^^ passing start is not allowed for ToPut etc
        if r == 0
            break
        end
        ntransferred += r
    end
    @ensure ntransferred isa UInt
    @db return ntransferred
end

@db function transferall!(t::Pair{<:Stream,<:Any}, a...; kw...)
    @db_not_tested
    @require TransferDirection(t[1]) == In()
    transferall!(t[1], t[2], a...; kw...)
end

@db function transferall!(t::Pair{<:Any,<:Stream}, a...; kw...)
    @db_not_tested
    @require TransferDirection(t[2]) == Out()
    transferall!(t[2], t[1], a...; kw...)
end





# Null Streams

"""
`NullIn()` is an input stream that does nothing.
It is intended to be used for testing Delegate Streams.
"""
struct NullIn <: Stream end

TransferDirection(::Type{NullIn}) = In()

transfer!(io::NullIn, buf::Ptr{UInt8}, n; kw...) = n


#=
FIXME
include("wrap.jl")

"""
`@delegate_io f` creates wrapper methods for function `f`.
A separate method is created with a specific 2nd argument type for
each 2nd argument type used in pre-existing methods of `f`
(to avoid method selection ambiguity). e.g.

    f(io::IODelegate; kw...) = f(unwrap(io); kw...)
    f(io::IODelegate, a2::T, a...; kw...) = f(unwrap(io), a2, a...; kw...)
"""
macro delegate_io(f, #= FIXME ---> =# D=FullInDelegate, u=unwrap)
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
=#



# Buffered Streams

"""
Generic type for Buffered Input Wrappers.

See concrete types `BufferedInput` and `LazyBufferedInput` below.
"""
abstract type GenericBufferedInput{T} <: Stream end

function Base.show(io::IO, s::GenericBufferedInput{T}) where T
    print(io, "GenericBufferedInput{", T, "}(", bytesavailable(s.buffer), ")")
end

StreamDelegation(::Type{<:GenericBufferedInput}) = DelegatedToSubStream()

TransferCost(::Type{<:GenericBufferedInput}) = LowTransferCost()

ReadFragmentation(::Type{<:GenericBufferedInput}) = ReadsBytes()

PeekSupport(::Type{<:GenericBufferedInput}) = Peekable()

Availability(::Type{<:GenericBufferedInput}) = PartiallyAvailable()

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


function Base.close(s::GenericBufferedInput)
    take!(s.buffer)
    Base.close(s.stream)
end


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
@db function refill_internal_buffer(s::GenericBufferedInput,
                                    n=s.buffer_size; deadline=Inf)
    # If needed, expand the buffer.
    sbuf = s.buffer
    @assert sbuf.append
    Base.ensureroom(sbuf, n)
    checkbounds(sbuf.data, sbuf.size+n)

    # Transfer from the stream to the buffer.
    p = pointer(sbuf.data, sbuf.size+1)
    n = GC.@preserve sbuf transfer!(s.stream, p, n; deadline)
    sbuf.size += n
    nothing
end


@db function pump!(s::GenericBufferedInput; deadline=Inf)
    refill_internal_buffer(s; deadline)
end


function readbyte(s::GenericBufferedInput; deadline)
    sbuf = s.buffer
    if bytesavailable(sbuf) == 0
        refill_internal_buffer(s; deadline)
    end
    if bytesavailable(sbuf) != 0
        return read(sbuf, UInt8)
    end
    @invoke readbyte(s::Stream; deadline)
end


@db function Base.peek(s::GenericBufferedInput, ::Type{T}; timeout=Inf) where T
    @db_not_tested
    wait_for_n_bytes(sizeof(T); timeout)
    if bytesavailable(s) < sizeof(T)
        @db return nothing
    end
    peek(s.buffer, T)
end


@db function isfinished(s::GenericBufferedInput)
    isfinished(s.stream) &&
    bytesavailable(s.buffer) == 0
end


@db function Base.position(s::GenericBufferedInput)
    position(s.stream) - bytesavailable(s.buffer)
end

@db function Base.readline(s::GenericBufferedInput; keep=false, timeout=Inf)
    _readline(s, ReadsBytes(); keep, timeout)
end


## Buffered Input

"""
    BufferedInput(stream; [buffer_size]) -> Stream

Create a wrapper around `stream` to buffer input transfers.

The wrapper will try to read `buffer_size` bytes into its buffer
every time it transfers data from `stream`.

The default `buffer_size` depends on `IOTratis.DataRate(stream)`.

`stream` must not be used directly after the wrapper is created.
"""
struct BufferedInput{T<:Stream} <: GenericBufferedInput{T}
    stream::T
    buffer::IOBuffer
    buffer_size::Int
    function BufferedInput(stream::T; buffer_size=default_buffer_size(stream)) where T
        @db_not_tested
        @require TransferDirection(stream) == In()
        buffered_in_warning(stream)
        new{T}(stream, PipeBuffer(), buffer_size)
    end
end

TransferSize(::Type{BufferedInput{T}}) where T = LimitedTransferSize()

max_transfer_size(s::BufferedInput) = s.buffer_size


idoc"""
The non-buffered method returns zero if there are not enough bytes
available to transfer a whole item (`ioelsize`).
This method refills the internal buffer if there are less than `ioelsize`
bytes available. Note that `refill_internal_buffer` may still not yield
enough bytes. However, calling it here ensures that the enclosing retry
loop will eventually get the data it needs.
"""
@db 2 function _attempt_transfer(s::BufferedInput,
                                 buf, interface::IsItemPtr,
                                 n::UInt, start::UInt)
    @assert ioelsize(buf) > 1
    @assert ioelsize(buf) < s.buffer_size
    @db_not_tested

    if bytesavailable(s) < ioelsize(buf)
        @db_not_tested
        refill_internal_buffer(s; deadline=0) # FIXME ?)
    end

    @invoke _attempt_transfer(s::Stream,
                              buf, interface::IsItemPtr,
                              n::UInt, start::UInt)
end



@db function Base.bytesavailable(s::BufferedInput) 
    @db_not_tested
    @require isopen(s)
    @db return bytesavailable(s.buffer) 
end



@db function unsafe_transfer!(s::BufferedInput, buf::Ptr{UInt8}, n::UInt)

    @db_not_tested
    sbuf = s.buffer
    # If there are not enough bytes in `sbuf`, read more from the wrapped stream.
    if bytesavailable(sbuf) < n
        @db_not_tested
        refill_internal_buffer(s)
    end

    # Read available bytes from `sbuf` into the caller's `buffer`.
    n = min(n, bytesavailable(sbuf))
    unsafe_read(sbuf, buf, n)
    @db return n
end



## Lazy Buffered Input

"""
    LazyBufferedInput(stream; [buffer_size]) -> Stream

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
struct LazyBufferedInput{T<:Stream} <: GenericBufferedInput{T}
    stream::T
    buffer::IOBuffer
    buffer_size::Int
    function LazyBufferedInput(s::T; buffer_size=default_buffer_size(s)) where T
        @require TransferDirection(s) == In()
        buffered_in_warning(s)
        new{T}(s, PipeBuffer(), buffer_size)
    end
end



@db function Base.bytesavailable(s::LazyBufferedInput)
    @require isopen(s)
    n = bytesavailable(s.buffer)
    if availability_is_known(s.stream)
        n += bytesavailable(s.stream)
    end
    @db return n
end


@db function unsafe_transfer!(s::LazyBufferedInput, buf::Ptr{UInt8}, n::UInt)

    # First take bytes from the buffer.
    sbuf = s.buffer
    count = bytesavailable(sbuf)
    if count > 0
        count = min(count, n)
        unsafe_read(sbuf, buf, count)
    end

    # Then read from the wrapped IO.
    if n > count
        count += unsafe_transfer!(s.stream, buf + count, n - count)
    end

    @ensure count <= n
    @db return count
end



# Base.IO Interface

Base.isreadable(io::BaseIO) = is_input(io.stream)
Base.iswritable(io::BaseIO) = is_output(io.stream)
Base.isopen(io::BaseIO) = isopen(io.stream)
Base.close(io::BaseIO) = close(io.stream)
Base.bytesavailable(io::BaseIO) = bytesavailable(io.stream)
Base.position(io::BaseIO) = position(io.stream)
Base.eof(io::BaseIO; deadline=Inf, timeout=Inf) =
    eof(io.stream; deadline, timeout)


## Function `eof`

idoc"""
`eof` is specialised on Total Size.
"""
@db function Base.eof(s::Stream; deadline=Inf, timeout=Inf)
    @require is_input(s)
    if !isopen(s)
        @db return true
    end
    deadline = deadline_or_timeout(deadline, timeout)
    _eof(s, Availability(s); deadline)
end


@db function _eof(s, ::UnknownAvailability; deadline::Float64)
    @db_not_tested
    @dblock s wait(s; deadline)
    return false
end


@db function _eof(s, ::AnyAvailability; deadline::Float64)
    if bytesavailable(s) > 0
        @db return false
    end
    @db deadline
    # VV handled by isfinished ?
#    if length_is_known(s) && bytesremaining(s) == 0
#        @db return true
#    end
    while isopen(s) && !isfinished(s) && time() < deadline
        pump!(s; deadline)
        @dblock s begin
            if bytesavailable(s) > 0
                @db return false
            end
            wait(s; deadline)
        end
    end
    @db return true
end

## Function `read(io, T)`

function Base.read(io::BaseIO, ::Type{UInt8}; deadline=Inf)
    x = readbyte(io.stream; deadline)
    x != nothing || throw(EOFError())
    return x
end

#Base.read(io::BaseIO, ::Type{T}; timeout) where T =
#    read(io, a...; deadline = time() + timeout)


idoc"""
Read as String. \
Wrap with `TimeoutStream` if timeout is requested.
"""
function Base.read(io::BaseIO, ::Type{String}; deadline=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; deadline)
    String(readall!(stream))
end



## Function `readbytes!`

Base.readbytes!(io::BaseIO, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(io, buf, UInt(nbytes); kw...)

@db function Base.readbytes!(io::BaseIO, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, timeout=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    _readbytes!(stream, buf, nbytes; all)
end

@db function _readbytes!(stream, buf, nbytes; all=true)
    lb::Int = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
            resize!(buf, lb)
        end
        @assert lb > nread
        n = transfer!(stream => buf, lb - nread; start = nread + 1)
        if n == 0 || !all
            break
        end
        nread += n
    end
    @ensure nread <= nbytes
    @db return nread
end



## Function `read(stream)`

Base.read(io::BaseIO; timeout=Inf) = readall!(io.stream; timeout)




## Function `read(stream, n)`

function Base.read(io::BaseIO, n::Integer; timeout=Inf)
    @db_not_tested
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    buf = Vector{UInt8}(undef, n)
    transfer_n(stream, buf, n)
    return buf
end


## Function `unsafe_read`

idoc"""
`unsafe_read` must keep trying until `nbytes` nave been transferred.
"""
function Base.unsafe_read(io::BaseIO, buf::Ptr{UInt8}, nbytes::UInt;
                          timeout=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    nread = 0
    @debug "Base.unsafe_read(io::BaseIO, buf::Ptr{UInt8}, nbytes::UInt)"
    while nread < nbytes
        n = transfer!(stream => (buf + nread), nbytes - nread)
        if n == 0
            @db_not_tested
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

If `Availability(stream)` is `UnknownAvailability()` the only way to know how
much data is available is to attempt a transfer.

Otherwise, the amount of data immediately available can be queried using the
`bytesavailable` function.
"""
@db function Base.readavailable(io::BaseIO; timeout=0)
    @require isopen(io.stream)
    @require is_input(io.stream)
    if Availability(io.stream) == UnknownAvailability()
        @db_not_tested
        n = default_buffer_size(io.stream)
    else
        n = bytesavailable(io.stream)
    end
    buf = Vector{UInt8}(undef, n)
    n = transfer!(io.stream, buf, n; timeout)
    resize!(buf, n)
end



## Function `readline`

idoc"""
`readline` is specialised based on the Read Fragmentation trait.
"""
@db function Base.readline(io::BaseIO; keep=false, timeout=Inf)
    readline(io.stream; keep, timeout)
end

idoc"""
If there is no special Read Fragmentation method,
invoke the default `Base.IO` method.
"""
@db function _readline(stream, ::AnyReadFragmentation; keep=false, timeout=Inf)
    stream = timeout_stream(stream; timeout)                ;@db timeout stream
    @invoke Base.readline(BaseIO(stream)::IO; keep)
end



"""
If Reads Lines is supported then simply calling `transfer` once will
read one line.

Character or Terminal devices (`S_IFCHR`) are often used in
"canonical mode" (`ICANON`).

> "In canonical mode: Input is made available line by line."
[termios(3)](https://man7.org/linux/man-pages/man3/termios.3.html).

For these devices calling `read(2)` will usually return exactly one line.
It will only ever return an incomplete line if length exceeded `MAX_CANON`.
Note that in canonical mode a line can be terminated by `CEOF` rather than
"\n", but `read(2)` does not return the `CEOF` character (e.g. when the
shell sends a "bash\$ " prompt without a newline).
"""
@db function _readline(stream, ::ReadsLines; keep::Bool=false, timeout=Inf)

    v = Base.StringVector(max_line)
    n = transfer!(stream => v; timeout)
    if n == 0
        @db_not_tested
        @db return ""
    end

    # Trim end of line characters.
    while !keep && n > 0 && (v[n] == UInt8('\r') ||
                             v[n] == UInt8('\n'))
        n -= 1
        @db_not_tested
    end

    @db return String(resize!(v, n))
end

const max_line = 1024 # UnixIO.C.MAX_CANON


## Function `readuntil`

function Base.readuntil(io::BaseIO, d::AbstractChar; timeout=Inf, kw...)
    @db_not_tested
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    @invoke Base.readuntil(BaseIO(stream)::IO, d; kw...)
end


## Function `write(stream, x)`

@db function Base.unsafe_write(io::BaseIO, buf::Ptr{UInt8}, nbytes::UInt)
    @require is_output(io.stream)
    @require isopen(io.stream)
    transferall!(io.stream, buf, nbytes)
end


@db function Base.write(io::BaseIO, x::UInt8)
    @require is_output(io.stream)
    @require isopen(io.stream)
    transfer!(x => io.stream)
end



# Exports

export TraitsIO, TransferDirection, transfer!, transferall!, readall!

export BufferedInput, LazyBufferedInput

export TotalSize,
       UnknownTotalSize, InfiniteTotalSize, KnownTotalSize, VariableTotalSize,
       FixedTotalSize

export Availability,
       AlwaysAvailable, PartiallyAvailable, UnknownAvailability

export TransferSize,
       UnlimitedTransferSize, LimitedTransferSize,
       FixedTransferSize

export TransferSizeMechanism,
       NoSizeMechanism, SupportsFIONREAD, SupportsStatSize

export ReadFragmentation,
       ReadsBytes, ReadsLines, ReadsPackets, ReadsRequestedSize

export WaitingMechanism,
       WaitBySleeping, WaitUsingPosixPoll, WaitUsingEPoll, WaitUsingPidFD,
       WaitUsingKQueue, WaitUsingIOURing

export CursorSupport, AbstractHasPosition,
       NoCursors,
       HasPosition,
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


## Errors

struct IOTraitsError <: Exception
    stream::Stream
    message::String
end

function Base.show(io::IO, e::IOTraitsError)
    print(io, "IOTraitsError: ", e.message)
end



using ReadmeDocs

include("ioinfo.jl") # Generate Method Resolution Info

end # module IOTraits
