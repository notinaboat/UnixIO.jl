
# IOTraits.jl

[Trait types][White] for describing the capabilities and behaviour of
IO interfaces.


```{.julia .numberLines .lineAnchors startFrom="7"}
module IOTraits

include("idoc.jl")
```


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



The `Stream` type models byte-streams.
Many common operations involve transferring data to and from byte streams.
e.g. writing data to a local file; receiving data from a network server;
or typing commands into a terminal.


```{.julia .numberLines .lineAnchors startFrom="147"}
abstract type Stream end
```


`TraitsIO(::Stream) -> IO` creates a `Base.IO` compatible wrapper around a
stream.
Similarities and differences between the `Base.IO` model and the
`IOTraits.Stream` model can be seen by reading the `TraitsIO`
implementations of the `Base.IO` functions below.


```{.julia .numberLines .lineAnchors startFrom="156"}
struct TraitsIO{T<:Stream} <: Base.IO
    stream::T
end
```



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



```{.julia .numberLines .lineAnchors startFrom="272"}
Base.isopen(s::Stream) = is_proxy(s) ? isopen(unwrap(s)) : false

Base.close(s::Stream) = is_proxy(s) ? close(unwrap(s)) : nothing

Base.wait(s::Stream) = is_proxy(s) ? wait(unwrap(s)) :
                                     wait(s, WaitingMechanism(s))
```


FIXME[^FIXME279]

[^FIXME279]: ⚠️  wait timeout ? deadline ? args for wait ?



### Stream Delegation Wrappers


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


```{.julia .numberLines .lineAnchors startFrom="299"}
abstract type StreamDelegation end
struct NotDelegated <: StreamDelegation end
struct DelegatedToSubStream <: StreamDelegation end
StreamDelegation(s) = StreamDelegation(typeof(s))
StreamDelegation(::Type) = NotDelegated()

is_proxy(s) = StreamDelegation(s) != NotDelegated()
```


`unwrap(stream)`
Retrieves the underlying stream that is wrapped by a proxy stream.


```{.julia .numberLines .lineAnchors startFrom="312"}
unwrap(s) = unwrap(s, StreamDelegation(s))
unwrap(s, ::NotDelegated) = s
unwrap(s, ::DelegatedToSubStream) = s.stream
```


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



```{.julia .numberLines .lineAnchors startFrom="350"}
using Preconditions
using Markdown
using Preferences
using Mmap
include("../../../src/macroutils.jl")
```


# Transfer Direction Trait


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


```{.julia .numberLines .lineAnchors startFrom="376"}
abstract type TransferDirection end
struct In <: TransferDirection end
struct Out <: TransferDirection end
struct Exchange <: TransferDirection end
const AnyDirection = TransferDirection
TransferDirection(s) = TransferDirection(typeof(s))
TransferDirection(T::Type) = is_proxy(T) ? TransferDirection(unwrap(T)) :
                                           nothing

_isreadable(s) = TransferDirection(s) != Out()
_iswritable(s) = TransferDirection(s) != In()
```


# IO Indexing Trait


Is indexing (e.g. `pread(2)`) supported?


```{.julia .numberLines .lineAnchors startFrom="396"}
abstract type StreamIndexing end
struct NotIndexable <: StreamIndexing end
struct IndexableIO <: StreamIndexing end
StreamIndexing(s) = StreamIndexing(typeof(s))
StreamIndexing(T::Type) = is_proxy(T) ? StreamIndexing(unwrap(T)) :
                                        NotIndexable

stream_is_indexable(s) = StreamIndexing(s) == IndexableIO()


ioeltype(s) = isabstracttype(eltype(s)) ? UInt8 : eltype(s)
```


# Data Transfer Function


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


```{.julia .numberLines .lineAnchors startFrom="456"}
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
```


`transfer_complete` is called at the end of the top-level `transfer` method.
A single call to the top-level `tansfer` method may result in many calls to
low level driver methods. e.g. to transfer every item in a collection.
The `transfer_complete` hook can be used, for example, to flush an output
buffer at end of a transfer.


```{.julia .numberLines .lineAnchors startFrom="478"}
transfer_complete(stream, buf, n) = nothing
```


### `transfer(a => b)`

    transfer(stream => buffer, [n]; start=(1 => 1), kw...) -> n_transfered
    transfer(buffer => stream, [n]; start=(1 => 1), kw...) -> n_transfered

`stream` and `buffer` can be passed to `transfer` as a pair.
`In` streams must be on the left.
`Out` streams must be on the right.


```{.julia .numberLines .lineAnchors startFrom="491"}
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
```


# Buffer Interface Traits


```{.julia .numberLines .lineAnchors startFrom="511"}
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
```


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


```{.julia .numberLines .lineAnchors startFrom="543"}
FromBufferInterface(x) = FromBufferInterface(typeof(x))
FromBufferInterface(::Type) = FromIteration()
FromBufferInterface(::Type{<:IO}) = FromIO()
FromBufferInterface(::Type{<:AbstractChannel}) = FromTake()
FromBufferInterface(::Type{<:Ptr}) = RawPtr()
FromBufferInterface(::Type{<:Ref}) = UsingPtr()
```


Pointers can be used for `AbstractArray` buffers of Bits types.


```{.julia .numberLines .lineAnchors startFrom="554"}
FromBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)

ArrayIOInterface(::Type{<:Array{T}}) where T =
    isbitstype(T) ? UsingPtr() : UsingIndex()

ArrayIOInterface(::Type{<:Base.FastContiguousSubArray{T,<:Any,<:Array{T}}}) where T =
    isbitstype(T) ? UsingPtr() : UsingIndex()
```


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



```{.julia .numberLines .lineAnchors startFrom="583"}
ToBufferInterface(x) = ToBufferInterface(typeof(x))
ToBufferInterface(::Type) = ToPush()
ToBufferInterface(::Type{<:IO}) = ToIO()
ToBufferInterface(::Type{<:AbstractChannel}) = ToPut()
ToBufferInterface(::Type{<:Ref}) = UsingPtr()
ToBufferInterface(::Type{<:Ptr}) = RawPtr()
ToBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)
```


# Transfer Function Dispatch


The top level `transfer` method promotes the keyword arguments
(`start` and `deadline`) to positional arguments so we can dispatch
on their types.

## `start` Index Normalisation

If `start` is a Tuple of indexes it is normalised by the method below.
The `StreamIndexing` trait is used to check that `stream` supports indexing.
Indexable streams are replaced by a `Tuple` containing `stream` and the
stream index.


```{.julia .numberLines .lineAnchors startFrom="607"}
function transfer(stream, buf, n, start::Tuple, deadline)
    @require StreamIndexing(stream) == IndexableIO() || start[1] == 1
    if start[1] != 1
        stream = (stream, start[1])
    end
    transfer(stream, buf, n, start[2], deadline)
end
```


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


```{.julia .numberLines .lineAnchors startFrom="632"}
transfer(stream, buf, n, start::Integer, deadline) = 
    transfer(stream, TransferDirection(stream), buf, n, start, deadline)

transfer(stream, ::In, buf, n, start, deadline) =
    transfer(stream, In(), buf, ToBufferInterface(buf), n, start, deadline)

transfer(stream, ::Out, buf, n, start, deadline) =
    transfer(stream, Out(), buf, FromBufferInterface(buf), n, start, deadline)
```


## Transfer Specialisations for Indexable Buffers


Try to use the whole length of the buffer if `n` is missing.


```{.julia .numberLines .lineAnchors startFrom="648"}
function transfer(stream, ::AnyDirection,
                  buf, ::Union{RawPtr, UsingPtr, UsingIndex},
                  n::Missing, start, deadline)
    n = length(buffer) - (start - 1)
    transfer(stream, buffer, n, start, deadline)
end
```


Convert pointer-compatible buffers to pointers.


```{.julia .numberLines .lineAnchors startFrom="659"}
function transfer(stream, ::AnyDirection, buf, ::UsingPtr, n, start, deadline)
    checkbounds(buf, (start-1) + n)
    GC.@preserve buf transfer(stream, pointer(buf), n, start, deadline)
end
```


Transfer one item at a time for indexable buffers that are not
accessible through pointers.


```{.julia .numberLines .lineAnchors startFrom="669"}
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
```


## Transfer Specialisations for Iterable Buffers


Iterate over `buf` (skip items until `start` index is reached).
Transfer each item one at a time.


```{.julia .numberLines .lineAnchors startFrom="696"}
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
```


## Transfer Specialisations for Collection Buffers


```{.julia .numberLines .lineAnchors startFrom="716"}
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
```


## Transfer Specialisations for IO Buffers


```{.julia .numberLines .lineAnchors startFrom="742"}
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
```


# Total Data Size Trait


```{.julia .numberLines .lineAnchors startFrom="762"}
abstract type TotalSize end
struct UnknownTotalSize <: TotalSize end
struct InfiniteTotalSize <: TotalSize end
abstract type KnownTotalSize end
struct VariableTotalSize <: KnownTotalSize end
struct FixedTotalSize <: KnownTotalSize end
```


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


```{.julia .numberLines .lineAnchors startFrom="793"}
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
```


# Transfer Size Trait


```{.julia .numberLines .lineAnchors startFrom="815"}
abstract type TransferSize end
struct UnknownTransferSize <: TransferSize end
struct KnownTransferSize <: TransferSize end
struct LimitedTransferSize <: TransferSize end
struct FixedTransferSize <: TransferSize end
const AnyTransferSize = TransferSize
```


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


```{.julia .numberLines .lineAnchors startFrom="850"}
TransferSize(s) = TransferSize(typeof(s))
TransferSize(T::Type) = is_proxy(T) ?
                        TransferSize(unwrap(T)) :
                            TransferSizeMechanism(T) == NoSizeMechanism() ?
                            UnknownTransferSize() :
                            KnownTransferSize()

max_transfer_size(stream) = max_transfer_size(stream, TransferSize(stream))
max_transfer_size(stream, ::Union{UnknownTransferSize,
                                  KnownTransferSize}) = typemax(Int)
```


`TransferSizeMechanism(stream)` returns one of:

 * `SupportsFIONREAD()` -- The underlying device supports `ioctl(2), FIONREAD`.
 * `SupportsStatSize()` -- The underlying device supports  `fstat(2), st_size`.


```{.julia .numberLines .lineAnchors startFrom="868"}
TransferSizeMechanism(s) = TransferSizeMechanism(typeof(s))
TransferSizeMechanism(T::Type) = is_proxy(T) ?
                                 TransferSizeMechanism(unwrap(T)) :
                                 NoSizeMechanism()
```


# Data Fragmentation Trait


```{.julia .numberLines .lineAnchors startFrom="877"}
abstract type ReadFragmentation end
struct ReadsBytes         <: ReadFragmentation end
struct ReadsLines         <: ReadFragmentation end
struct ReadsPackets       <: ReadFragmentation end
struct ReadsRequestedSize <: ReadFragmentation end
const AnyReadFragmentation = ReadFragmentation 
```


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


```{.julia .numberLines .lineAnchors startFrom="914"}
ReadFragmentation(s) = ReadFragmentation(typeof(s))
ReadFragmentation(T::Type) = is_proxy(T) ? ReadFragmentation(unwrap(T)) :
                                           ReadsBytes()
```


# Performance Traits


```{.julia .numberLines .lineAnchors startFrom="921"}
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
```


# Cursor Traits (Mark & Seek)


```{.julia .numberLines .lineAnchors startFrom="938"}
abstract type CursorSupport end
abstract type AbstractSeekable <: CursorSupport end
struct NoCursors <: CursorSupport end
struct Seekable  <: AbstractSeekable end
struct Markable  <: AbstractSeekable end
```


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


```{.julia .numberLines .lineAnchors startFrom="960"}
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
```


# Event Notification Mechanism Trait


```{.julia .numberLines .lineAnchors startFrom="996"}
abstract type WaitingMechanism end
struct WaitBySleeping     <: WaitingMechanism end
struct WaitUsingPosixPoll <: WaitingMechanism end
struct WaitUsingEPoll     <: WaitingMechanism end
struct WaitUsingPidFD     <: WaitingMechanism end
struct WaitUsingKQueue    <: WaitingMechanism end
```


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


```{.julia .numberLines .lineAnchors startFrom="1057"}
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
```


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


```{.julia .numberLines .lineAnchors startFrom="1097"}
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
```


# Null Streams


`NullIn()` is an input stream that does nothing.
It is intended to be used for testing Delegate Streams.


```{.julia .numberLines .lineAnchors startFrom="1121"}
struct NullIn <: Stream end

TransferDirection(::Type{NullIn}) = In()

transfer(io::NullIn, buf::Ptr{UInt8}, n; kw...) = n
```


`StreamProxy` wraps a stream and forwards all of the default stream methods.


```{.julia .numberLines .lineAnchors startFrom="1133"}
abstract type StreamProxy{T<:Stream} <: Stream where S end
abstract type InDelegate{T} <: StreamProxy{T} end
abstract type FullInDelegate{T} <: StreamProxy{T} end

StreamDelegation(::Type{StreamProxy}) = DelegatedToSubstream()


include("wrap.jl")
```


`@delegate_io f` creates wrapper methods for function `f`.
A separate method is created with a specific 2nd argument type for
each 2nd argument type used in pre-existing methods of `f`
(to avoid method selection ambiguity). e.g.

    f(io::IODelegate; kw...) = f(unwrap(io); kw...)
    f(io::IODelegate, a2::T, a...; kw...) = f(unwrap(io), a2, a...; kw...)


```{.julia .numberLines .lineAnchors startFrom="1151"}
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
```


# BufferedIO


Generic type for Buffered Input Wrappers.

See `BufferedIn` and `LazyBufferedIn` below.


```{.julia .numberLines .lineAnchors startFrom="1189"}
abstract type GenericBufferedIn{T} <: InDelegate{T} end

TransferCost(::Type{GenericBufferedIn{T}}) where T = LowTransferCost()

ReadFragmentation(::Type{GenericBufferedIn{T}}) where T = ReadsBytes()

function buffered_in_warning(io)
    if ReadFragmentation(io) != ReadsBytes()
        @warn "Wrapping $(typeof(io)) with `BufferedIn` causes " *
              "the $(ReadFragmentation(io)) trait to be ignored!"
    end
    if TransferCost(io) == LowTransferCost()
        @warn "$(typeof(io)) already has LowTransfterCost. " *
              "Wrapping with `BufferedIn` may degrade performance."
    end
end


Base.eof(ib::GenericBufferedIn) = ( bytesavailable(ib.buffer) == 0
                                 && eof(ib.io) )

Base.close(ib::GenericBufferedIn) = ( take!(ib.buffer);
                                      Base.close(ib.io) )
```


Size of the internal buffer.


```{.julia .numberLines .lineAnchors startFrom="1217"}
buffer_size(io::GenericBufferedIn) = io.buffer_size
```


Buffer ~1 second of data by default.


```{.julia .numberLines .lineAnchors startFrom="1223"}
default_buffer_size(io) = DataRate(io)
```


Transfer bytes from the wrapped IO to the internal buffer.


```{.julia .numberLines .lineAnchors startFrom="1229"}
function refill_internal_buffer(io::GenericBufferedIn, n=io.buffer_size; kw...)

    # If needed, expand the buffer.
    iob = io.buffer
    @assert iob.append
    Base.ensureroom(iob, n)
    checkbounds(iob.data, iob.size+n)

    # Transfer from the IO to the buffer.
    p = pointer(iob.data, iob.size+1)
    n = GC.@preserve iob transfer(io.io, p, n; kw...)
    iob.size += n
end
```


Shortcut to read one byte directly from buffer.
Or, if the buffer is empty refill it.


```{.julia .numberLines .lineAnchors startFrom="1248"}
function Base.read(io::GenericBufferedIn, ::Type{UInt8}; kw...)
    if bytesavailable(io.buffer) != 0
        return Base.read(io.buffer, UInt8)
    end
    eof(io.io; kw...) && throw(EOFError())
    refill_internal_buffer(io; kw...)
    return Base.read(io.buffer, UInt8)
end
```


Shortcut to peek into the buffer.
Or, if the buffer is empty refill it.


```{.julia .numberLines .lineAnchors startFrom="1262"}
function Base.peek(io::GenericBufferedIn, ::Type{T}; kw...) where T
    if bytesavailable(io.buffer) >= sizeof(T)
        return Base.peek(io.buffer, T)
    end
    eof(io.io; kw...) && throw(EOFError())
    refill_internal_buffer(io; kw...)
    return Base.peek(io.buffer, T)
end


function transfer(io::GenericBufferedIn, ::In, ::Ptr{UInt8}, ::RawPtr,
                  n, start, deadline)
    transfer(io, buf, n; start, deadline)
end
```


## BufferedIn


    BufferedIn(io; [buffer_size]) -> IO

Create a wrapper around `io` to buffer input transfers.

The wrapper will try to read `buffer_size` bytes into its buffer
every time it transfers data from `io`.

The default `buffer_size` depends on `IOTratis.DataRate(io)`.

`io` must not be used directly after the wrapper is created.


```{.julia .numberLines .lineAnchors startFrom="1292"}
struct BufferedIn{T} <: GenericBufferedIn{T}
    io::T
    buffer::IOBuffer
    buffer_size::Int
    function BufferedIn(io::T; buffer_size=default_buffer_size(io)) where T
        @require TransferDirection(io) == In()
        buffered_in_warning(io)
        new{T}(io, PipeBuffer(), buffer_size)
    end
end

TransferSize(::Type{BufferedIn{T}}) where T = LimitedTransferSize()

max_transfer_size(io::BufferedIn) = io.buffer_size

Base.bytesavailable(io::BufferedIn) = bytesavailable(io.buffer) 


function transfer(io::BufferedIn, buf::Ptr{UInt8}, n, start::Integer, deadline)
    @info "transfer(t::BufferedIn, ...)"

    iob = io.buffer
    # If there are not enough bytes in `iob`, read more from the wrapped IO.
    if bytesavailable(iob) < n
        refill_internal_buffer(io)
    end

    # Read available bytes from `iob` into the caller's `buffer`.
    n = min(n, bytesavailable(iob))
    unsafe_read(iob, buf + (start-1), n)
    return n
end
```


Shortcut to delegate `readavailable` to the internal buffer.


```{.julia .numberLines .lineAnchors startFrom="1329"}
function Base.readavailable(io::BufferedIn; kw...)
    if bytesavailable(io.buffer) == 0
        refill_internal_buffer(io; kw...)
    end
    return readavailable(io.buffer)
end
```


## LazyBufferedIn


    LazyBufferedIn(io; [buffer_size]) -> IO

Create a wrapper around `io` to buffer input transfers.

The internal buffer is only used when a small transfer is attempted
or if `peek` is called.
Most reads are fulfilled directly from the underling `io`.
This avoids the overhead of double buffering in situations where there is
an occasional need to read one byte at a time (e.g. `readuntil()`) but most
reads are already of a reasonable size.

The default `buffer_size` depends on `IOTratis.DataRate(io)`.

`io` must not be used directly after the wrapper is created.


```{.julia .numberLines .lineAnchors startFrom="1356"}
struct LazyBufferedIn{T} <: GenericBufferedIn{T}
    io::T
    buffer::IOBuffer
    buffer_size::Int
    function LazyBufferedIn(io::T; buffer_size=default_buffer_size(io)) where T
        @require TransferDirection(io) == In()
        buffered_in_warning(io)
        new{T}(io, PipeBuffer(), buffer_size)
    end
end


Base.bytesavailable(io::LazyBufferedIn) = bytesavailable(io.buffer) + 
                                          bytesavailable(io.io);


function transfer(io::LazyBufferedIn, buf::Ptr{UInt8}, n, start::Integer, deadline)
    @info "transfer(t::LazyBufferedIn, ...)"

    buf += (start-1)

    # First take bytes from the buffer.
    iob = io.buffer
    count = bytesavailable(iob)
    if count > 0
        count = min(count, n)
        unsafe_read(iob, buf, count)
    end

    # Then read from the wrapped IO.
    if n > count
        count += transfer(io.io, buf + count, n - count; deadline)
    end

    @ensure count <= n
    return count
end
```


# Timeout IO


    TimeoutIO(io; timeout) -> IO

The `TimeoutIO` wrapper adds a timeout deadline to an `io`.
It is used to add timeout capability to Base.IO functions.


```{.julia .numberLines .lineAnchors startFrom="1404"}
struct TimeoutIO{T} <: FullInDelegate{T}
    io::T
    deadline::Float64
    function TimeoutIO(io::T, timeout) where T
        @require timeout < Inf
        new{T}(io, time() + timeout)
    end
end

timeout_io(io, t) = t == Inf ? io : TimeoutIO(io, t)

function transfer(t::TimeoutIO{T}, buffer, n; start, kw...) where T
    @info "transfer(t::ITimeoutIO, ...)"
    transfer(t.io, buffer, n; start, deadline = t.deadline)
end
```


# Base.IO Interface


```{.julia .numberLines .lineAnchors startFrom="1424"}
Base.isreadable(io::TraitsIO) = is_input(io.stream)
Base.iswritable(io::TraitsIO) = is_output(io.stream)
```


## Function `bytesavailable`


`bytesavailable` is specialised on Transfer Size and Transfer Size Mechanism.


```{.julia .numberLines .lineAnchors startFrom="1433"}
function Base.bytesavailable(io::TraitsIO)
    @require isreadable(io)
    _bytesavailable(io, TransferSize(io))
end

_bytesavailable(io, ::UnknownTransferSize) = 0
_bytesavailable(io, ::KnownTransferSize) =
    _bytesavailable(io, TransferSizeMechanism(io))
```


## Function `eof`


`eof` is specialised on Total Size.


```{.julia .numberLines .lineAnchors startFrom="1448"}
function Base.eof(io::TraitsIO; timeout=Inf)
    @require isreadable(io)
    eof(io, TotalSize(io); timeout)
end
```


If Total Size is known then `eof` is reached when there are
zero `bytesavailable`.


```{.julia .numberLines .lineAnchors startFrom="1457"}
Base.eof(io, ::KnownTotalSize; kw...) = bytesavailable(io) == 0
```


If Total Size is not known then `eof` must "block to wait for more data".


```{.julia .numberLines .lineAnchors startFrom="1463"}
function Base.eof(io, ::UnknownTotalSize; kw...)
    n = bytesavailable(io)
    if n == 0
        wait(io; kw...)
        n = bytesavailable(io)
    end
    return n == 0
end

Base.eof(io, ::InfiniteTotalSize; kw...) = (wait(io; kw...); false)
```


## Function `read(io, T)`


Single byte read is specialized based on the Transfer Cost.
(Single byte read for High Transfer Cost falls through to the 
"does not support byte I/O" error from Base).


```{.julia .numberLines .lineAnchors startFrom="1483"}
function Base.read(io::TraitsIO, ::Type{UInt8}; timeout=Inf)
    @require isreadable(io)
    read(io, TransferCost(io), UInt8; timeout)
end
```


Allow single byte read for interfaces with Low Transfter Cost,
but warn if a special Read Fragmentation trait is available.


```{.julia .numberLines .lineAnchors startFrom="1493"}
function read(io, ::LowTransferCost, ::Type{UInt8}; kw...)
    if ReadFragmentation(io) == ReadsLines()
        @warn "read(::$(typeof(io)), UInt8): " *
              "$(typeof(io)) implements `IOTraits.ReadsLines`." *
              "Reading one byte at a time may not be efficient." *
              "Consider using `readline` instead."
    end
    x = Ref{UInt8}()
    n = GC.@preserve x transfer(io => pointer(x), 1; kw...)
    n == 1 || throw(EOFError())
    return x[]
end
```


Read as String. \
Wrap with `TimeoutIO` if timeout is requested.


```{.julia .numberLines .lineAnchors startFrom="1511"}
function Base.read(io::TraitsIO, ::Type{String}; timeout=Inf)
    @require isreadable(io)
    @invoke String(Base.read(timeout_io(io, timeout)::IO))
end
```


## Function `length(io)`


```{.julia .numberLines .lineAnchors startFrom="1519"}
function Base.length(io::TraitsIO)
    @require TotalSize(io) isa KnownTotalSize

    _length(io, TotalSizeMechanism(io))
end

_length(io, ::SupportsStatSize) = stat(io).size
```


## Function `readbytes!`


```{.julia .numberLines .lineAnchors startFrom="1530"}
Base.readbytes!(io::TraitsIO, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(io, buf, UInt(nbytes); kw...)

function Base.readbytes!(io::TraitsIO, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, timeout=Inf)
    @require isreadable(io)
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
        n = transfer(io, buf, lb - nread, nread + 1, deadline)
        if n == 0 || !all
            break
        end
        nread += n
    end
    @ensure nread <= nbytes
    return nread
end

timeout_deadline(timeout) = timeout == Inf ? Inf : time() + timeout
```


## Function `read(io)`


Read until end of file.
Specialise on Total Size, Cursor Support and Mmap Support.


```{.julia .numberLines .lineAnchors startFrom="1566"}
function Base.read(io; timeout=Inf)
    @require isreadable(io)
    read(io, TotalSize(io), CursorSupport(io); timeout)
end


function read(io, ::UnknownTotalSize, ::NoCursors; timeout=Inf)
    n = default_buffer_size(io)
    buf = Vector{UInt8}(undef, n)
    readbytes!(io, buf, n; timeout)
    return buf
end
```





```{.julia .numberLines .lineAnchors startFrom="1583"}
function read(io, ::KnownTotalSize, ::AbstractSeekable; kw...)
    n = length(io) - position(io)
    buf = Vector{UInt8}(undef, n)
    transfer_n(io => buffer, n; kw...)
    return buf
end
```


Transfer `n` items between `io` and `buf`.

Call `transfer` repeatedly until all `n` items have been Transferred, 
stopping only if end of file is reached.

Return the number of items transferred.


```{.julia .numberLines .lineAnchors startFrom="1599"}
function transfer_n(io, buf::Vector{UInt8}, n, start, deadline)
    @require length(buf) == (start-1) + n
    nread = 0
    while nread < n
        n = transfer(io, buf, n - nread, start + nread, deadline)
        if n == 0
            break
        end
        nread += n
    end
    return n
end
```


## Function `read(io, n)`


```{.julia .numberLines .lineAnchors startFrom="1615"}
function Base.read(io::TraitsIO, n::Integer; timeout=Inf)
    @require isreadable(io)
    @invoke Base.read(timeout_io(io, timeout)::IO, n::Integer)
end
```


## Function `unsafe_read`


`unsafe_read` must keep trying until `nbytes` nave been transferred.


```{.julia .numberLines .lineAnchors startFrom="1626"}
function Base.unsafe_read(io::TraitsIO, buf::Ptr{UInt8}, nbytes::UInt;
                          deadline=Inf)
    @require isreadable(io)
    nread = 0
    @debug "Base.unsafe_read(io::TraitsIO, buf::Ptr{UInt8}, nbytes::UInt)"
    while nread < nbytes
        n = transfer(io => buf + nread, nbytes - nread; deadline)
        if n == 0
            throw(EOFError())
        end
        nread += n
    end
    @ensure nread == nbytes
    nothing
end
```


## Function `readavailable`


    readavailable(io::TraitsIO; [timeout=0]) -> Vector{UInt8}

Read immediately available data from a stream.

If `TransferSize(io)` is `UnknownTransferSize()` the only way to know how much
data is available is to attempt a transfer.

Otherwise, the amount of data immediately available can be queried using the
`bytesavailable` function.


```{.julia .numberLines .lineAnchors startFrom="1657"}
function Base.readavailable(io::TraitsIO; timeout=0)
    @require isreadable(io)
    n = bytesavailable(io)
    if n == 0 
        n = default_buffer_size(io)
    end
    buf = Vector{UInt8}(undef, n)
    n = transfer(io, buf; timeout)
    resize!(buf, n)
end
```


## Function `readline`


`readline` is specialised based on the Read Fragmentation trait.


```{.julia .numberLines .lineAnchors startFrom="1675"}
function Base.readline(io::TraitsIO; timeout=Inf, kw...)
    @require isreadable(io)
    readline(io, ReadFragmentation(io); timeout, kw...)
end
```


If there is no special Read Fragmentation method,
use `TimeoutIO` to support the timeout option.


```{.julia .numberLines .lineAnchors startFrom="1684"}
readline(io::TraitsIO, ::AnyReadFragmentation; timeout, kw...) =
    @invoke Base.readline(timeout_io(io, timeout)::IO; kw...)
```


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

If `io` has the `ReadsLines` trait calling `transfer` once will read one line.


```{.julia .numberLines .lineAnchors startFrom="1705"}
function readline(io, ::ReadsLines; keep::Bool=false, kw...)

    v = Base.StringVector(max_line)
    n = transfer(io => v; kw...)
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
```


## Function `readuntil`


```{.julia .numberLines .lineAnchors startFrom="1727"}
Base.readuntil(io::TraitsIO, d::AbstractChar; timeout=Inf, kw...) =
    @invoke Base.readuntil(timeout_io(io, timeout)::IO, d; kw...)
```


# Exports


```{.julia .numberLines .lineAnchors startFrom="1734"}
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
```


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




```{.julia .numberLines .lineAnchors startFrom="1827"}
using ReadmeDocs

include("ioinfo.jl") # Generate Method Resolution Info

end # module IOTraits
```
# Method Resolution Info

## BufferedIn

## IO Traits

| Trait             | Value                 |
|:----------------- |:--------------------- |
| TransferDirection | nothing               |
| TotalSize         | UnknownTotalSize()    |
| TransferSize      | LimitedTransferSize() |
| ReadFragmentation | ReadsBytes()          |
| WaitingMechanism  | WaitBySleeping()      |

## Core Read Methods

|    Function | Args               | File             | Method                                                                                                                                                     |
| -----------:|:------------------ |:---------------- |:---------------------------------------------------------------------------------------------------------------------------------------------------------- |
|  isreadable |                    | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                         |
|             |                    |                  | MethodError: no method matching isreadable(::IOTraits.BufferedIn{IOTraits.NullIn})                                                                         |
|             |                    |                  | Closest candidates are:                                                                                                                                    |
|             |                    |                  |   isreadable(!Matched::Base.DevNull) at coreio.jl:12                                                                                                       |
|             |                    |                  |   isreadable(!Matched::Base.AbstractPipe) at io.jl:380                                                                                                     |
|             |                    |                  |   isreadable(!Matched::Base.GenericIOBuffer) at iobuffer.jl:234                                                                                            |
|             |                    |                  |   ...                                                                                                                                                      |
|        read | Type{UInt8}        | IOTraits.jl:1248 | read(io::IOTraits.GenericBufferedIn, ::Type{UInt8}; kw...)                                                                                                 |
| unsafe_read | Ptr{UInt8}, UInt64 | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                         |
|             |                    |                  | MethodError: no method matching unsafe_read(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Ptr{UInt8}, ::Int64)                                                 |
|             |                    |                  | Closest candidates are:                                                                                                                                    |
|             |                    |                  |   unsafe_read(!Matched::IOTraits.FullInDelegate, ::Ptr{UInt8}, ::Any...; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1154 |
|             |                    |                  |   unsafe_read(!Matched::IOTraits.FullInDelegate, ::Ptr, ::Any...; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1154        |
|             |                    |                  |   unsafe_read(!Matched::IO, ::Ptr, ::Integer) at io.jl:722                                                                                                 |
|             |                    |                  |   ...                                                                                                                                                      |
|         eof |                    | IOTraits.jl:1207 | eof(ib::IOTraits.GenericBufferedIn)                                                                                                                        |
|    reseteof |                    | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                         |
|             |                    |                  | MethodError: no method matching reseteof(::IOTraits.BufferedIn{IOTraits.NullIn})                                                                           |
|             |                    |                  | Closest candidates are:                                                                                                                                    |
|             |                    |                  |   reseteof(!Matched::Base.AbstractPipe) at io.jl:415                                                                                                       |
|             |                    |                  |   reseteof(!Matched::Base.TTY) at stream.jl:656                                                                                                            |
|             |                    |                  |   reseteof(!Matched::IO) at io.jl:28                                                                                                                       |
|        peek |                    | io.jl:267        | peek(s)                                                                                                                                                    |
|        peek | Type{UInt8}        | IOTraits.jl:1262 | peek(io::IOTraits.GenericBufferedIn, ::Type{T}; kw...) where T                                                                                             |
|        peek | Type{Int64}        | IOTraits.jl:1262 | peek(io::IOTraits.GenericBufferedIn, ::Type{T}; kw...) where T                                                                                             |

## Core Write Methods

|     Function | Args               | File | Method                                                                                                                               |
| ------------:|:------------------ |:---- |:------------------------------------------------------------------------------------------------------------------------------------ |
|   iswritable |                    | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching iswritable(::IOTraits.BufferedIn{IOTraits.NullIn})                                                   |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   iswritable(!Matched::Base.DevNull) at coreio.jl:13                                                                                 |
|              |                    |      |   iswritable(!Matched::Base.AbstractPipe) at io.jl:384                                                                               |
|              |                    |      |   iswritable(!Matched::Base.GenericIOBuffer) at iobuffer.jl:235                                                                      |
|              |                    |      |   ...                                                                                                                                |
|        write | UInt8              | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching write(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Int64)                                               |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   write(!Matched::AbstractString, ::Any, !Matched::Any...) at io.jl:420                                                              |
|              |                    |      |   write(!Matched::IO, ::Union{Float16, Float32, Float64, Int128, Int16, Int32, Int64, UInt128, UInt16, UInt32, UInt64}) at io.jl:649 |
|              |                    |      |   write(!Matched::IO, ::Any) at io.jl:635                                                                                            |
|              |                    |      |   ...                                                                                                                                |
| unsafe_write | Ptr{UInt8}, UInt64 | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching unsafe_write(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Ptr{UInt8}, ::Int64)                          |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   unsafe_write(!Matched::IO, ::Ptr, ::Integer) at io.jl:646                                                                          |
|              |                    |      |   unsafe_write(!Matched::IO, ::Ref{T}, ::Integer) where T at io.jl:644                                                               |
|              |                    |      |   unsafe_write(!Matched::Base.DevNull, ::Ptr{UInt8}, !Matched::UInt64) at coreio.jl:17                                               |
|              |                    |      |   ...                                                                                                                                |
|        flush |                    | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching flush(::IOTraits.BufferedIn{IOTraits.NullIn})                                                        |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   flush(!Matched::Base.DevNull) at coreio.jl:19                                                                                      |
|              |                    |      |   flush(!Matched::TextDisplay) at multimedia.jl:253                                                                                  |
|              |                    |      |   flush(!Matched::IOStream) at iostream.jl:66                                                                                        |
|              |                    |      |   ...                                                                                                                                |

## State Methods

| Function | Args | File             | Method                                                                             |
| --------:|:---- |:---------------- |:---------------------------------------------------------------------------------- |
|    close |      | IOTraits.jl:1210 | close(ib::IOTraits.GenericBufferedIn)                                              |
|   isopen |      | IOTraits.jl:272  | isopen(s::IOTraits.Stream)                                                         |
|     lock |      | ⚠️               | ErrorException("no unique matching method found for the specified argument types") |
|          |      |                  | MethodError: no method matching lock(::IOTraits.BufferedIn{IOTraits.NullIn})       |
|          |      |                  | Closest candidates are:                                                            |
|          |      |                  |   lock(::Any, !Matched::Base.GenericCondition) at condition.jl:78                  |
|          |      |                  |   lock(::Any, !Matched::Base.AbstractLock) at lock.jl:184                          |
|          |      |                  |   lock(::Any, !Matched::WeakKeyDict) at weakkeydict.jl:87                          |
|          |      |                  |   ...                                                                              |
|   unlock |      | ⚠️               | ErrorException("no unique matching method found for the specified argument types") |
|          |      |                  | MethodError: no method matching unlock(::IOTraits.BufferedIn{IOTraits.NullIn})     |
|          |      |                  | Closest candidates are:                                                            |
|          |      |                  |   unlock(::Any, !Matched::Base.GenericCondition) at condition.jl:79                |
|          |      |                  |   unlock(!Matched::IOContext) at show.jl:334                                       |
|          |      |                  |   unlock(!Matched::Base.AlwaysLockedST) at condition.jl:50                         |
|          |      |                  |   ...                                                                              |

## Cursor Methods

|  Function | Args    | File | Method                                                                                                                           |
| ---------:|:------- |:---- |:-------------------------------------------------------------------------------------------------------------------------------- |
|      skip | Integer | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching skip(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Int64)                                            |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   skip(!Matched::Base.GenericIOBuffer, ::Integer) at iobuffer.jl:243                                                             |
|           |         |      |   skip(!Matched::IOStream, ::Integer) at iostream.jl:184                                                                         |
|           |         |      |   skip(!Matched::Base.Filesystem.File, ::Integer) at filesystem.jl:232                                                           |
|           |         |      |   ...                                                                                                                            |
|      seek | Integer | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching seek(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Int64)                                            |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   seek(!Matched::Base.GenericIOBuffer, ::Integer) at iobuffer.jl:250                                                             |
|           |         |      |   seek(!Matched::Base.Libc.FILE, ::Integer) at libc.jl:97                                                                        |
|           |         |      |   seek(!Matched::IOStream, ::Integer) at iostream.jl:127                                                                         |
|           |         |      |   ...                                                                                                                            |
|  position |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching position(::IOTraits.BufferedIn{IOTraits.NullIn})                                                 |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   position(!Matched::Base.GenericIOBuffer) at iobuffer.jl:241                                                                    |
|           |         |      |   position(!Matched::Base.Libc.FILE) at libc.jl:103                                                                              |
|           |         |      |   position(!Matched::IOStream) at iostream.jl:216                                                                                |
|           |         |      |   ...                                                                                                                            |
| seekstart |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching seekstart(::IOTraits.BufferedIn{IOTraits.NullIn})                                                |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   seekstart(!Matched::IO) at iostream.jl:154                                                                                     |
|           |         |      |   seekstart(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153 |
|   seekend |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching seekend(::IOTraits.BufferedIn{IOTraits.NullIn})                                                  |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   seekend(!Matched::Base.GenericIOBuffer) at iobuffer.jl:263                                                                     |
|           |         |      |   seekend(!Matched::IOStream) at iostream.jl:161                                                                                 |
|           |         |      |   seekend(!Matched::Base.Filesystem.File) at filesystem.jl:226                                                                   |
|           |         |      |   ...                                                                                                                            |
|      mark |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching mark(::IOTraits.BufferedIn{IOTraits.NullIn})                                                     |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   mark(!Matched::Base.AbstractPipe) at io.jl:380                                                                                 |
|           |         |      |   mark(!Matched::Base.LibuvStream) at stream.jl:1265                                                                             |
|           |         |      |   mark(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153      |
|           |         |      |   ...                                                                                                                            |
|    unmark |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching unmark(::IOTraits.BufferedIn{IOTraits.NullIn})                                                   |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   unmark(!Matched::Base.AbstractPipe) at io.jl:380                                                                               |
|           |         |      |   unmark(!Matched::Base.LibuvStream) at stream.jl:1266                                                                           |
|           |         |      |   unmark(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153    |
|           |         |      |   ...                                                                                                                            |
|     reset |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching reset(::IOTraits.BufferedIn{IOTraits.NullIn})                                                    |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   reset(!Matched::Base.AbstractPipe) at io.jl:380                                                                                |
|           |         |      |   reset(!Matched::Base.LibuvStream) at stream.jl:1267                                                                            |
|           |         |      |   reset(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153     |
|           |         |      |   ...                                                                                                                            |
|  ismarked |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching ismarked(::IOTraits.BufferedIn{IOTraits.NullIn})                                                 |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   ismarked(!Matched::Base.AbstractPipe) at io.jl:380                                                                             |
|           |         |      |   ismarked(!Matched::Base.LibuvStream) at stream.jl:1268                                                                         |
|           |         |      |   ismarked(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153  |
|           |         |      |   ...                                                                                                                            |

## Extra Read Methods

|          Function | Args                          | File             | Method                                                                                                                                                                                                                        |
| -----------------:|:----------------------------- |:---------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|    bytesavailable |                               | IOTraits.jl:1307 | bytesavailable(io::IOTraits.BufferedIn)                                                                                                                                                                                       |
| max_transfer_size |                               | IOTraits.jl:1305 | max_transfer_size(io::IOTraits.BufferedIn)                                                                                                                                                                                    |
|     readavailable |                               | IOTraits.jl:1329 | readavailable(io::IOTraits.BufferedIn; kw...)                                                                                                                                                                                 |
|          readline |                               | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching readline(::IOTraits.BufferedIn{IOTraits.NullIn})                                                                                                                                              |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   readline() at io.jl:506                                                                                                                                                                                                     |
|                   |                               |                  |   readline(!Matched::AbstractString; keep) at io.jl:500                                                                                                                                                                       |
|                   |                               |                  |   readline(!Matched::IOStream; keep) at iostream.jl:444                                                                                                                                                                       |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|              read | Type{Int64}                   | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching read(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Type{Int64})                                                                                                                                   |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   read(!Matched::Base.GenericIOBuffer, ::Union{Type{Float16}, Type{Float32}, Type{Float64}, Type{Int128}, Type{Int16}, Type{Int32}, Type{Int64}, Type{UInt128}, Type{UInt16}, Type{UInt32}, Type{UInt64}}) at iobuffer.jl:189 |
|                   |                               |                  |   read(::IOTraits.GenericBufferedIn, !Matched::Type{UInt8}; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1248                                                                                |
|                   |                               |                  |   read(!Matched::AbstractString, ::Type{T}) where T at io.jl:434                                                                                                                                                              |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|              read | Type{String}                  | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching read(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Type{String})                                                                                                                                  |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   read(!Matched::Base.AbstractCmd, ::Type{String}) at process.jl:421                                                                                                                                                          |
|                   |                               |                  |   read(!Matched::TraitsIO, ::Type{String}; timeout) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1511                                                                                               |
|                   |                               |                  |   read(::IOTraits.GenericBufferedIn, !Matched::Type{UInt8}; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1248                                                                                |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|              read | Integer                       | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching read(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Int64)                                                                                                                                         |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   read(!Matched::Base.GenericIOBuffer, ::Integer) at iobuffer.jl:471                                                                                                                                                          |
|                   |                               |                  |   read(!Matched::TraitsIO, ::Integer; timeout) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1615                                                                                                    |
|                   |                               |                  |   read(::IOTraits.GenericBufferedIn, !Matched::Type{UInt8}; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1248                                                                                |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|        readbytes! | Vector{UInt8}                 | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching readbytes!(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Vector{UInt8})                                                                                                                           |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   readbytes!(!Matched::Base.GenericIOBuffer, ::Array{UInt8, N} where N) at iobuffer.jl:460                                                                                                                                    |
|                   |                               |                  |   readbytes!(!Matched::Base.GenericIOBuffer, ::Array{UInt8, N} where N, !Matched::Int64) at iobuffer.jl:461                                                                                                                   |
|                   |                               |                  |   readbytes!(!Matched::Base.GenericIOBuffer, ::Array{UInt8, N} where N, !Matched::Any) at iobuffer.jl:460                                                                                                                     |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|        readbytes! | AbstractVector{UInt8}, Number | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching AbstractVector{UInt8}()                                                                                                                                                                       |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   AbstractArray{T, N}(!Matched::AbstractArray{S, N}) where {T, N, S} at array.jl:541                                                                                                                                          |
|             read! | AbstractArray                 | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching AbstractArray()                                                                                                                                                                               |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   AbstractArray(!Matched::Union{LinearAlgebra.QR, LinearAlgebra.QRCompactWY}) at /Users/julia/buildbot/worker/package_macos64/build/usr/share/julia/stdlib/v1.6/LinearAlgebra/src/qr.jl:433                                   |
|                   |                               |                  |   AbstractArray(!Matched::LinearAlgebra.CholeskyPivoted) at /Users/julia/buildbot/worker/package_macos64/build/usr/share/julia/stdlib/v1.6/LinearAlgebra/src/cholesky.jl:435                                                  |
|                   |                               |                  |   AbstractArray(!Matched::LinearAlgebra.LQ) at /Users/julia/buildbot/worker/package_macos64/build/usr/share/julia/stdlib/v1.6/LinearAlgebra/src/lq.jl:119                                                                     |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|         readuntil | Any                           | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no constructors have been defined for Any                                                                                                                                                                        |
|        countlines |                               | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching countlines(::IOTraits.BufferedIn{IOTraits.NullIn})                                                                                                                                            |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   countlines(!Matched::IO; eol) at io.jl:1175                                                                                                                                                                                 |
|                   |                               |                  |   countlines(!Matched::AbstractString; eol) at io.jl:1192                                                                                                                                                                     |
|                   |                               |                  |   countlines(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153                                                                                             |
|          eachline |                               | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching eachline(::IOTraits.BufferedIn{IOTraits.NullIn})                                                                                                                                              |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   eachline() at io.jl:1004                                                                                                                                                                                                    |
|                   |                               |                  |   eachline(!Matched::IO; keep) at io.jl:1004                                                                                                                                                                                  |
|                   |                               |                  |   eachline(!Matched::AbstractString; keep) at io.jl:1008                                                                                                                                                                      |
|                   |                               |                  |   ...                                                                                                                                                                                                                         |
|          readeach | Type{Char}                    | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching readeach(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Type{Char})                                                                                                                                |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   readeach(!Matched::IOT, ::Type) where IOT<:IO at io.jl:1047                                                                                                                                                                 |
|          readeach | Type{Int64}                   | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching readeach(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Type{Int64})                                                                                                                               |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   readeach(!Matched::IOT, ::Type) where IOT<:IO at io.jl:1047                                                                                                                                                                 |
|          readeach | Type{UInt8}                   | ⚠️               | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                  | MethodError: no method matching readeach(::IOTraits.BufferedIn{IOTraits.NullIn}, ::Type{UInt8})                                                                                                                               |
|                   |                               |                  | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                  |   readeach(!Matched::IOT, ::Type) where IOT<:IO at io.jl:1047                                                                                                                                                                 |

## NullIn

## IO Traits

| Trait             | Value                 |
|:----------------- |:--------------------- |
| TransferDirection | IOTraits.In()         |
| TotalSize         | UnknownTotalSize()    |
| TransferSize      | UnknownTransferSize() |
| ReadFragmentation | ReadsBytes()          |
| WaitingMechanism  | WaitBySleeping()      |

## Core Read Methods

|    Function | Args               | File      | Method                                                                                                                                                                                                                                                                                                            |
| -----------:|:------------------ |:--------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|  isreadable |                    | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching isreadable(::IOTraits.NullIn)                                                                                                                                                                                                                                                     |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   isreadable(!Matched::Base.DevNull) at coreio.jl:12                                                                                                                                                                                                                                                              |
|             |                    |           |   isreadable(!Matched::Base.AbstractPipe) at io.jl:380                                                                                                                                                                                                                                                            |
|             |                    |           |   isreadable(!Matched::Base.GenericIOBuffer) at iobuffer.jl:234                                                                                                                                                                                                                                                   |
|             |                    |           |   ...                                                                                                                                                                                                                                                                                                             |
|        read | Type{UInt8}        | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching read(::IOTraits.NullIn, ::Type{UInt8})                                                                                                                                                                                                                                            |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   read(!Matched::Base.GenericIOBuffer, ::Type{UInt8}) at iobuffer.jl:212                                                                                                                                                                                                                                          |
|             |                    |           |   read(!Matched::TraitsIO, ::Type{UInt8}; timeout) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1483                                                                                                                                                                                    |
|             |                    |           |   read(!Matched::IOTraits.GenericBufferedIn, ::Type{UInt8}; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1248                                                                                                                                                                    |
|             |                    |           |   ...                                                                                                                                                                                                                                                                                                             |
| unsafe_read | Ptr{UInt8}, UInt64 | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching unsafe_read(::IOTraits.NullIn, ::Ptr{UInt8}, ::Int64)                                                                                                                                                                                                                             |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   unsafe_read(!Matched::IOTraits.FullInDelegate, ::Ptr{UInt8}, ::Any...; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1154                                                                                                                                                        |
|             |                    |           |   unsafe_read(!Matched::IOTraits.FullInDelegate, ::Ptr, ::Any...; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1154                                                                                                                                                               |
|             |                    |           |   unsafe_read(!Matched::IO, ::Ptr, ::Integer) at io.jl:722                                                                                                                                                                                                                                                        |
|             |                    |           |   ...                                                                                                                                                                                                                                                                                                             |
|         eof |                    | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching eof(::IOTraits.NullIn)                                                                                                                                                                                                                                                            |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   eof(::Any, !Matched::InfiniteTotalSize; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1472                                                                                                                                                                                      |
|             |                    |           |   eof(::Any, !Matched::UnknownTotalSize; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1463                                                                                                                                                                                       |
|             |                    |           |   eof(::Any, !Matched::KnownTotalSize; kw...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1457                                                                                                                                                                                         |
|             |                    |           |   ...                                                                                                                                                                                                                                                                                                             |
|    reseteof |                    | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching reseteof(::IOTraits.NullIn)                                                                                                                                                                                                                                                       |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   reseteof(!Matched::Base.AbstractPipe) at io.jl:415                                                                                                                                                                                                                                                              |
|             |                    |           |   reseteof(!Matched::Base.TTY) at stream.jl:656                                                                                                                                                                                                                                                                   |
|             |                    |           |   reseteof(!Matched::IO) at io.jl:28                                                                                                                                                                                                                                                                              |
|        peek |                    | io.jl:267 | peek(s)                                                                                                                                                                                                                                                                                                           |
|        peek | Type{UInt8}        | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching peek(::IOTraits.NullIn, ::Type{UInt8})                                                                                                                                                                                                                                            |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   peek(!Matched::Base.Iterators.Stateful, ::Any) at iterators.jl:1299                                                                                                                                                                                                                                             |
|             |                    |           |   peek(!Matched::IOTraits.GenericBufferedIn, ::Type{T}; kw...) where T at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1262                                                                                                                                                                |
|             |                    |           |   peek(!Matched::IOTraits.FullInDelegate, ::Type{UInt8}, !Matched::Any...; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1154                                                                                                                                                      |
|             |                    |           |   ...                                                                                                                                                                                                                                                                                                             |
|        peek | Type{Int64}        | ⚠️        | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                                                                                                                |
|             |                    |           | MethodError: no method matching peek(::IOTraits.NullIn, ::Type{Int64})                                                                                                                                                                                                                                            |
|             |                    |           | Closest candidates are:                                                                                                                                                                                                                                                                                           |
|             |                    |           |   peek(!Matched::Base.Iterators.Stateful, ::Any) at iterators.jl:1299                                                                                                                                                                                                                                             |
|             |                    |           |   peek(!Matched::IOTraits.GenericBufferedIn, ::Type{T}; kw...) where T at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1262                                                                                                                                                                |
|             |                    |           |   peek(!Matched::IOTraits.FullInDelegate, ::Union{Type{Float16}, Type{Float32}, Type{Float64}, Type{Int128}, Type{Int16}, Type{Int32}, Type{Int64}, Type{UInt128}, Type{UInt16}, Type{UInt32}, Type{UInt64}}, !Matched::Any...; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1154 |
|             |                    |           |   ...                                                                                                                                                                                                                                                                                                             |

## Core Write Methods

|     Function | Args               | File | Method                                                                                                                               |
| ------------:|:------------------ |:---- |:------------------------------------------------------------------------------------------------------------------------------------ |
|   iswritable |                    | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching iswritable(::IOTraits.NullIn)                                                                        |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   iswritable(!Matched::Base.DevNull) at coreio.jl:13                                                                                 |
|              |                    |      |   iswritable(!Matched::Base.AbstractPipe) at io.jl:384                                                                               |
|              |                    |      |   iswritable(!Matched::Base.GenericIOBuffer) at iobuffer.jl:235                                                                      |
|              |                    |      |   ...                                                                                                                                |
|        write | UInt8              | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching write(::IOTraits.NullIn, ::Int64)                                                                    |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   write(!Matched::AbstractString, ::Any, !Matched::Any...) at io.jl:420                                                              |
|              |                    |      |   write(!Matched::IO, ::Union{Float16, Float32, Float64, Int128, Int16, Int32, Int64, UInt128, UInt16, UInt32, UInt64}) at io.jl:649 |
|              |                    |      |   write(!Matched::IO, ::Any) at io.jl:635                                                                                            |
|              |                    |      |   ...                                                                                                                                |
| unsafe_write | Ptr{UInt8}, UInt64 | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching unsafe_write(::IOTraits.NullIn, ::Ptr{UInt8}, ::Int64)                                               |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   unsafe_write(!Matched::IO, ::Ptr, ::Integer) at io.jl:646                                                                          |
|              |                    |      |   unsafe_write(!Matched::IO, ::Ref{T}, ::Integer) where T at io.jl:644                                                               |
|              |                    |      |   unsafe_write(!Matched::Base.DevNull, ::Ptr{UInt8}, !Matched::UInt64) at coreio.jl:17                                               |
|              |                    |      |   ...                                                                                                                                |
|        flush |                    | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                                   |
|              |                    |      | MethodError: no method matching flush(::IOTraits.NullIn)                                                                             |
|              |                    |      | Closest candidates are:                                                                                                              |
|              |                    |      |   flush(!Matched::Base.DevNull) at coreio.jl:19                                                                                      |
|              |                    |      |   flush(!Matched::TextDisplay) at multimedia.jl:253                                                                                  |
|              |                    |      |   flush(!Matched::IOStream) at iostream.jl:66                                                                                        |
|              |                    |      |   ...                                                                                                                                |

## State Methods

| Function | Args | File            | Method                                                                             |
| --------:|:---- |:--------------- |:---------------------------------------------------------------------------------- |
|    close |      | IOTraits.jl:274 | close(s::IOTraits.Stream)                                                          |
|   isopen |      | IOTraits.jl:272 | isopen(s::IOTraits.Stream)                                                         |
|     lock |      | ⚠️              | ErrorException("no unique matching method found for the specified argument types") |
|          |      |                 | MethodError: no method matching lock(::IOTraits.NullIn)                            |
|          |      |                 | Closest candidates are:                                                            |
|          |      |                 |   lock(::Any, !Matched::Base.GenericCondition) at condition.jl:78                  |
|          |      |                 |   lock(::Any, !Matched::Base.AbstractLock) at lock.jl:184                          |
|          |      |                 |   lock(::Any, !Matched::WeakKeyDict) at weakkeydict.jl:87                          |
|          |      |                 |   ...                                                                              |
|   unlock |      | ⚠️              | ErrorException("no unique matching method found for the specified argument types") |
|          |      |                 | MethodError: no method matching unlock(::IOTraits.NullIn)                          |
|          |      |                 | Closest candidates are:                                                            |
|          |      |                 |   unlock(::Any, !Matched::Base.GenericCondition) at condition.jl:79                |
|          |      |                 |   unlock(!Matched::IOContext) at show.jl:334                                       |
|          |      |                 |   unlock(!Matched::Base.AlwaysLockedST) at condition.jl:50                         |
|          |      |                 |   ...                                                                              |

## Cursor Methods

|  Function | Args    | File | Method                                                                                                                           |
| ---------:|:------- |:---- |:-------------------------------------------------------------------------------------------------------------------------------- |
|      skip | Integer | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching skip(::IOTraits.NullIn, ::Int64)                                                                 |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   skip(!Matched::Base.GenericIOBuffer, ::Integer) at iobuffer.jl:243                                                             |
|           |         |      |   skip(!Matched::IOStream, ::Integer) at iostream.jl:184                                                                         |
|           |         |      |   skip(!Matched::Base.Filesystem.File, ::Integer) at filesystem.jl:232                                                           |
|           |         |      |   ...                                                                                                                            |
|      seek | Integer | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching seek(::IOTraits.NullIn, ::Int64)                                                                 |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   seek(!Matched::Base.GenericIOBuffer, ::Integer) at iobuffer.jl:250                                                             |
|           |         |      |   seek(!Matched::Base.Libc.FILE, ::Integer) at libc.jl:97                                                                        |
|           |         |      |   seek(!Matched::IOStream, ::Integer) at iostream.jl:127                                                                         |
|           |         |      |   ...                                                                                                                            |
|  position |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching position(::IOTraits.NullIn)                                                                      |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   position(!Matched::Base.GenericIOBuffer) at iobuffer.jl:241                                                                    |
|           |         |      |   position(!Matched::Base.Libc.FILE) at libc.jl:103                                                                              |
|           |         |      |   position(!Matched::IOStream) at iostream.jl:216                                                                                |
|           |         |      |   ...                                                                                                                            |
| seekstart |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching seekstart(::IOTraits.NullIn)                                                                     |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   seekstart(!Matched::IO) at iostream.jl:154                                                                                     |
|           |         |      |   seekstart(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153 |
|   seekend |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching seekend(::IOTraits.NullIn)                                                                       |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   seekend(!Matched::Base.GenericIOBuffer) at iobuffer.jl:263                                                                     |
|           |         |      |   seekend(!Matched::IOStream) at iostream.jl:161                                                                                 |
|           |         |      |   seekend(!Matched::Base.Filesystem.File) at filesystem.jl:226                                                                   |
|           |         |      |   ...                                                                                                                            |
|      mark |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching mark(::IOTraits.NullIn)                                                                          |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   mark(!Matched::Base.AbstractPipe) at io.jl:380                                                                                 |
|           |         |      |   mark(!Matched::Base.LibuvStream) at stream.jl:1265                                                                             |
|           |         |      |   mark(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153      |
|           |         |      |   ...                                                                                                                            |
|    unmark |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching unmark(::IOTraits.NullIn)                                                                        |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   unmark(!Matched::Base.AbstractPipe) at io.jl:380                                                                               |
|           |         |      |   unmark(!Matched::Base.LibuvStream) at stream.jl:1266                                                                           |
|           |         |      |   unmark(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153    |
|           |         |      |   ...                                                                                                                            |
|     reset |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching reset(::IOTraits.NullIn)                                                                         |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   reset(!Matched::Base.AbstractPipe) at io.jl:380                                                                                |
|           |         |      |   reset(!Matched::Base.LibuvStream) at stream.jl:1267                                                                            |
|           |         |      |   reset(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153     |
|           |         |      |   ...                                                                                                                            |
|  ismarked |         | ⚠️   | ErrorException("no unique matching method found for the specified argument types")                                               |
|           |         |      | MethodError: no method matching ismarked(::IOTraits.NullIn)                                                                      |
|           |         |      | Closest candidates are:                                                                                                          |
|           |         |      |   ismarked(!Matched::Base.AbstractPipe) at io.jl:380                                                                             |
|           |         |      |   ismarked(!Matched::Base.LibuvStream) at stream.jl:1268                                                                         |
|           |         |      |   ismarked(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153  |
|           |         |      |   ...                                                                                                                            |

## Extra Read Methods

|          Function | Args                          | File            | Method                                                                                                                                                                                                                        |
| -----------------:|:----------------------------- |:--------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|    bytesavailable |                               | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching bytesavailable(::IOTraits.NullIn)                                                                                                                                                             |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   bytesavailable(!Matched::Base.AbstractPipe) at io.jl:403                                                                                                                                                                    |
|                   |                               |                 |   bytesavailable(!Matched::Base.GenericIOBuffer) at iobuffer.jl:240                                                                                                                                                           |
|                   |                               |                 |   bytesavailable(!Matched::IOStream) at iostream.jl:377                                                                                                                                                                       |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
| max_transfer_size |                               | IOTraits.jl:857 | max_transfer_size(stream)                                                                                                                                                                                                     |
|     readavailable |                               | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching readavailable(::IOTraits.NullIn)                                                                                                                                                              |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   readavailable(!Matched::Base.AbstractPipe) at io.jl:380                                                                                                                                                                     |
|                   |                               |                 |   readavailable(!Matched::Base.GenericIOBuffer) at iobuffer.jl:470                                                                                                                                                            |
|                   |                               |                 |   readavailable(!Matched::IOStream) at iostream.jl:379                                                                                                                                                                        |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|          readline |                               | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching readline(::IOTraits.NullIn)                                                                                                                                                                   |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   readline() at io.jl:506                                                                                                                                                                                                     |
|                   |                               |                 |   readline(!Matched::AbstractString; keep) at io.jl:500                                                                                                                                                                       |
|                   |                               |                 |   readline(!Matched::IOStream; keep) at iostream.jl:444                                                                                                                                                                       |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|              read | Type{Int64}                   | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching read(::IOTraits.NullIn, ::Type{Int64})                                                                                                                                                        |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   read(!Matched::Base.GenericIOBuffer, ::Union{Type{Float16}, Type{Float32}, Type{Float64}, Type{Int128}, Type{Int16}, Type{Int32}, Type{Int64}, Type{UInt128}, Type{UInt16}, Type{UInt32}, Type{UInt64}}) at iobuffer.jl:189 |
|                   |                               |                 |   read(!Matched::AbstractString, ::Type{T}) where T at io.jl:434                                                                                                                                                              |
|                   |                               |                 |   read(!Matched::AbstractString, ::Any...) at io.jl:432                                                                                                                                                                       |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|              read | Type{String}                  | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching read(::IOTraits.NullIn, ::Type{String})                                                                                                                                                       |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   read(!Matched::Base.AbstractCmd, ::Type{String}) at process.jl:421                                                                                                                                                          |
|                   |                               |                 |   read(!Matched::TraitsIO, ::Type{String}; timeout) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1511                                                                                               |
|                   |                               |                 |   read(!Matched::AbstractString, ::Type{T}) where T at io.jl:434                                                                                                                                                              |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|              read | Integer                       | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching read(::IOTraits.NullIn, ::Int64)                                                                                                                                                              |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   read(!Matched::Base.GenericIOBuffer, ::Integer) at iobuffer.jl:471                                                                                                                                                          |
|                   |                               |                 |   read(!Matched::TraitsIO, ::Integer; timeout) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1615                                                                                                    |
|                   |                               |                 |   read(!Matched::AbstractString, ::Any...) at io.jl:432                                                                                                                                                                       |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|        readbytes! | Vector{UInt8}                 | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching readbytes!(::IOTraits.NullIn, ::Vector{UInt8})                                                                                                                                                |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   readbytes!(!Matched::Base.GenericIOBuffer, ::Array{UInt8, N} where N) at iobuffer.jl:460                                                                                                                                    |
|                   |                               |                 |   readbytes!(!Matched::Base.GenericIOBuffer, ::Array{UInt8, N} where N, !Matched::Int64) at iobuffer.jl:461                                                                                                                   |
|                   |                               |                 |   readbytes!(!Matched::Base.GenericIOBuffer, ::Array{UInt8, N} where N, !Matched::Any) at iobuffer.jl:460                                                                                                                     |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|        readbytes! | AbstractVector{UInt8}, Number | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching AbstractVector{UInt8}()                                                                                                                                                                       |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   AbstractArray{T, N}(!Matched::AbstractArray{S, N}) where {T, N, S} at array.jl:541                                                                                                                                          |
|             read! | AbstractArray                 | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching AbstractArray()                                                                                                                                                                               |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   AbstractArray(!Matched::Union{LinearAlgebra.QR, LinearAlgebra.QRCompactWY}) at /Users/julia/buildbot/worker/package_macos64/build/usr/share/julia/stdlib/v1.6/LinearAlgebra/src/qr.jl:433                                   |
|                   |                               |                 |   AbstractArray(!Matched::LinearAlgebra.CholeskyPivoted) at /Users/julia/buildbot/worker/package_macos64/build/usr/share/julia/stdlib/v1.6/LinearAlgebra/src/cholesky.jl:435                                                  |
|                   |                               |                 |   AbstractArray(!Matched::LinearAlgebra.LQ) at /Users/julia/buildbot/worker/package_macos64/build/usr/share/julia/stdlib/v1.6/LinearAlgebra/src/lq.jl:119                                                                     |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|         readuntil | Any                           | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no constructors have been defined for Any                                                                                                                                                                        |
|        countlines |                               | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching countlines(::IOTraits.NullIn)                                                                                                                                                                 |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   countlines(!Matched::IO; eol) at io.jl:1175                                                                                                                                                                                 |
|                   |                               |                 |   countlines(!Matched::AbstractString; eol) at io.jl:1192                                                                                                                                                                     |
|                   |                               |                 |   countlines(!Matched::IOTraits.FullInDelegate; k...) at /Users/samoconnor/git/jlpi/UnixIO/packages/IOTraits/src/IOTraits.jl:1153                                                                                             |
|          eachline |                               | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching eachline(::IOTraits.NullIn)                                                                                                                                                                   |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   eachline() at io.jl:1004                                                                                                                                                                                                    |
|                   |                               |                 |   eachline(!Matched::IO; keep) at io.jl:1004                                                                                                                                                                                  |
|                   |                               |                 |   eachline(!Matched::AbstractString; keep) at io.jl:1008                                                                                                                                                                      |
|                   |                               |                 |   ...                                                                                                                                                                                                                         |
|          readeach | Type{Char}                    | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching readeach(::IOTraits.NullIn, ::Type{Char})                                                                                                                                                     |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   readeach(!Matched::IOT, ::Type) where IOT<:IO at io.jl:1047                                                                                                                                                                 |
|          readeach | Type{Int64}                   | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching readeach(::IOTraits.NullIn, ::Type{Int64})                                                                                                                                                    |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   readeach(!Matched::IOT, ::Type) where IOT<:IO at io.jl:1047                                                                                                                                                                 |
|          readeach | Type{UInt8}                   | ⚠️              | ErrorException("no unique matching method found for the specified argument types")                                                                                                                                            |
|                   |                               |                 | MethodError: no method matching readeach(::IOTraits.NullIn, ::Type{UInt8})                                                                                                                                                    |
|                   |                               |                 | Closest candidates are:                                                                                                                                                                                                       |
|                   |                               |                 |   readeach(!Matched::IOT, ::Type) where IOT<:IO at io.jl:1047                                                                                                                                                                 |

