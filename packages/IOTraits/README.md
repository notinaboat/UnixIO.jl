
# IOTraits.jl

[Trait types][White] for describing the capabilities and behaviour of
IO interfaces.


```{.julia .numberLines .lineAnchors startFrom="7"}
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
```


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

The IOTraits interface is built around the function `transfer(stream, buffer)`.
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
                             `WaitUsingEPoll`, `WaitUsingPidFD` or
                             `WaitUsingKQueue`)

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



The `Stream` type models byte-streams.
Many common operations involve transferring data to and from byte streams.
e.g. writing data to a local file; receiving data from a network server;
or typing commands into a terminal.

Note that `IOTraits.Stream` is not a subtype of `Base.IO`.[^BaseIO]


```{.julia .numberLines .lineAnchors startFrom="175"}
abstract type Stream end
```


The constructor `BaseIO(::Stream) -> Base.IO` creates a Base.IO compatible
wrapper around a stream.


```{.julia .numberLines .lineAnchors startFrom="181"}
struct BaseIO{T<:Stream} <: Base.IO
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
`deadline=` argument. The `transfer` function stops waiting when `deadline > time()`.
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



### Methods of Base Functions for Streams

The IOTraits interface avoids defining methods of Base functions that have
incomplete or ambiguous specifications. It also avoids local function names
names that shadow Base functions. In some cases a similar function name with
an underscore prefix is used to differentiate local functions.

The IOTraits interface defines methods for the following well defined
Base functions (the default methods for the generic `Stream` type dispatch
to a wrapped delegate stream if the `StreamDelegation` trait is in effect).



```{.julia .numberLines .lineAnchors startFrom="320"}
Base.isopen(s::Stream) = is_proxy(s) ? isopen(unwrap(s)) : false

Base.close(s::Stream) = is_proxy(s) ? close(unwrap(s)) : nothing

Base.wait(s::Stream; deadline=Inf) = is_proxy(s) ?
                                     wait(unwrap(s); deadline) :
                                     _wait(s, WaitingMechanism(s); deadline)

@db function Base.bytesavailable(s::Stream)
    @require is_input(s)
    s = unwrap(s)
    _bytesavailable(s, Availability(s), TransferSize(s))
end

function Base.length(s::Stream)
    @require TotalSize(s) isa KnownTotalSize
    s = unwrap(s)
    _length(s, TotalSizeMechanism(s))
end

function Base.readline(s::Stream; timeout=Inf, keep=false)
    @require is_input(s)
    s = unwrap(s)
    _readline(s, ReadFragmentation(s); timeout, keep)
end

function Base.peek(s::Stream, ::Type{T}; timeout=Inf) where T
    @require is_input(s)
    s = unwrap(s)
    _peek(s, PeekSupport(s), T; timeout)
end
```


### Stream Delegation Wrappers


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


```{.julia .numberLines .lineAnchors startFrom="371"}
abstract type StreamDelegation end
struct NotDelegated <: StreamDelegation end
struct DelegatedToSubStream <: StreamDelegation end
StreamDelegation(s) = StreamDelegation(typeof(s))
StreamDelegation(::Type) = NotDelegated()

is_proxy(s) = StreamDelegation(s) != NotDelegated()
```


`unwrap(stream)`
-- Retrieves the underlying stream that is wrapped by a proxy stream.


```{.julia .numberLines .lineAnchors startFrom="384"}
unwrap(s) = unwrap(s, StreamDelegation(s))
unwrap(s, ::NotDelegated) = s
unwrap(s, ::DelegatedToSubStream) = s.stream
unwrap(T::Type, ::DelegatedToSubStream) = fieldtype(T, :stream)
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


```{.julia .numberLines .lineAnchors startFrom="444"}
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
```


The constructor `BaseIOStream(::Base.IO) -> IOTraits.Stream` creates a Stream
compatible wrapper around a Base.IO.


```{.julia .numberLines .lineAnchors startFrom="464"}
struct BaseIOStream{T<:Base.IO,D<:TransferDirection} <: Stream
    io::T
end

TransferDirection(::Type{BaseIOStream{T, D}}) where {T, D} = D()

Base.isopen(s::BaseIOStream) = isopen(s.io)
```


# IO Indexing Trait


Is indexing (e.g. `pread(2)`) supported?


```{.julia .numberLines .lineAnchors startFrom="478"}
abstract type StreamIndexing end
struct NotIndexable <: StreamIndexing end
struct IndexableIO <: StreamIndexing end
StreamIndexing(s) = StreamIndexing(typeof(s))
StreamIndexing(T::Type) = is_proxy(T) ? StreamIndexing(unwrap(T)) :
                                        NotIndexable

stream_is_indexable(s) = StreamIndexing(s) == IndexableIO()


ioeltype(s) = isabstracttype(eltype(s)) ? UInt8 : eltype(s)
@selfdoc ioelsize(s) = sizeof(ioeltype(s))
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


```{.julia .numberLines .lineAnchors startFrom="540"}
@db function transfer(stream, buf, n::Union{Integer,Missing}=missing;
                  start::Union{Integer, NTuple{2,Integer}}=UInt(1),
                  timeout=Inf,
                  deadline=Inf)

    @require isopen(stream)
    @require ismissing(n) || n > 0
    @require all(start .> 0)
    if timeout != Inf
        deadline = time() + timeout
    end
    n = transfer(stream, buf, n, start, Float64(deadline))
    transfer_complete(stream, buf, n)
    @ensure n isa UInt
    @db return n
end
```


`transfer_complete` is called at the end of the top-level `transfer` method.
A single call to the top-level `tansfer` method may result in many calls to
low level driver methods. e.g. to transfer every item in a collection.
The `transfer_complete` hook can be used, for example, to flush an output
buffer at end of a transfer.


```{.julia .numberLines .lineAnchors startFrom="565"}
transfer_complete(stream, buf, n) = nothing
```


### `transfer(a => b)`

    transfer(stream => buffer, [n]; start=(1 => 1), kw...) -> n_transfered
    transfer(buffer => stream, [n]; start=(1 => 1), kw...) -> n_transfered

`stream` and `buffer` can be passed to `transfer` as a pair.
`In` streams must be on the left.
`Out` streams must be on the right.


```{.julia .numberLines .lineAnchors startFrom="578"}
function transfer(t::Pair{<:Stream, <:Any}, a...; start=(1 => 1), kw...)
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


## Waiting for the Deadline


The specification for `transfer` says: If no items are immediately available,
wait until `time() > deadline` for at least one item to be transferred.

The method below starts by simply attempting the transfer.
This avoids the overhead of locking and measuring the current time.
If the initial transfer attempt yields no data, the `wait_for_transfer`
method is selected based on Waiting Mechanism trait.

If the buffer elements are larger than one byte and the stream has
Unknown Availability then `transfer_available` can end up with a
partial item in the buffer. In this situation a second attempt is needed
to transfer the missing bytes. A TimeoutStream wrapper is used to ensure
that the second transfer adheres to the specified deadline.



```{.julia .numberLines .lineAnchors startFrom="614"}
function transfer(stream, buffer, n, start, deadline::Float64)

    if Availability(stream) == UnknownAvailability() &&
    ioelsize(buffer) != 1 &&
    deadline != Inf
        stream = timeout_stream(stream; deadline)
    end

    r = transfer_available(stream, buffer, n, start)
    if r > 0 || iszero(deadline)
        return r
    end
    wait_for_transfer(stream, WaitingMechanism(stream),
                      buffer, n, start, deadline)
end
```


# Waiting Mechanism Trait


```{.julia .numberLines .lineAnchors startFrom="634"}
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

`WaitUsingPosixPoll`  Wait using the POSIX `poll` mechanism.
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

[^SLEEP]: Sleeping may be the most efficient mechanism for small systems with
simple IO requirements, for large systems where throughput is more important
than latency, or for systems that simply do not spend a lot of time
waiting for IO. Sleeping allows other Julia tasks to run immediately, whereas
the other polling mechanisms all have some amount of book-keeping and system
call overhead.


```{.julia .numberLines .lineAnchors startFrom="695"}
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

_wait(x, ::WaitBySleeping; deadline=Inf) = sleep(0.1)
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


```{.julia .numberLines .lineAnchors startFrom="735"}
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


## Wait By Sleeping Method


The Wait By Sleeping method for `wait_for_transfer` calls `transfer_available`
in a loop until data is available or the deadline is reached.

An exponentially increasing sleep delay minimises latency for short waits and
limits CPU use for longer waits.


```{.julia .numberLines .lineAnchors startFrom="763"}
const delay_sequence =
    ExponentialBackOff(;n = typemax(Int),
                        first_delay = 0.01, factor = 1.2, max_delay = 0.25)

@db function wait_for_transfer(stream, ::WaitBySleeping,
                               buf, n, start, deadline::Float64)
    for delay in delay_sequence
        r = transfer_available(stream, buf, n, start);
        if r >= 0
            @db return r
        end
        if time() >= deadline
            @db return 0
        end
        sleep(delay)
    end
end
```


## Specialised Waiting Methods


In the default waiting method, `wait` is called in a loop until data is
available or the deadline is reached. The appropriate `wait` method will
be selected according to Waiting Mechanism.

`Base.lock` and `Base.unlock` must be implemented for each stream type.[^LOCK]

[^LOCK]: These methods should do whatever is necessary to avoid race conditions
between `Base.wait` and `transfer_available`.
In UnixIO.jl `Base.wait` waits for a `ThreadSynchronizer` and the underlying
polling mechanism notifies the `ThreadSynchronizer` to wake up the waiting task.


```{.julia .numberLines .lineAnchors startFrom="797"}
@db function wait_for_transfer(stream, buf, n, start, deadline::Float64,
                               ::WaitingMechanism)
    try 
        lock(stream)
        while time() < deadline
            wait(stream; deadline)
            r = transfer_available(stream, buf, n, start);
            if r > 0
                @db return r
            end
        end
        @db return 0
    finally
        unlock(stream)
    end
end
```


# Buffer Interface Traits


```{.julia .numberLines .lineAnchors startFrom="818"}
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
```


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


```{.julia .numberLines .lineAnchors startFrom="855"}
FromBufferInterface(x) = FromBufferInterface(typeof(x))
FromBufferInterface(::Type) = FromIteration()
FromBufferInterface(::Type{<:IO}) = FromIO()
FromBufferInterface(::Type{<:Stream}) = FromStream()
FromBufferInterface(::Type{<:AbstractChannel}) = FromTake()
FromBufferInterface(::Type{<:Ref}) = UsingPtr()
FromBufferInterface(::Type{<:Ptr{T}}) where T = sizeof(T) == 1 ? IsBytePtr() :
                                                                 IsItemPtr()
```


Pointers can be used for `AbstractArray` buffers of Bits types.


```{.julia .numberLines .lineAnchors startFrom="868"}
FromBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)

ArrayIOInterface(::Type) where T = UsingIndex()

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
| `ToStream`     | Write data using the `IOTraits.Stream` interface.           |
| `ToPush`       | Use `push!(buffer, data)`.                                  |
| `ToPut`        | Use `put!(buffer, data)`.                                   |
| `UsingIndex`   | Use `buffer[i] = data (the default)`.                       |
| `UsingPtr`     | Use `unsafe_copyto!(pointer(buffer), x, n)`.                |
| `IsItemPtr`    | Use `unsafe_copyto!(buffer, x, n)`.                         |
| `IsBytePtr`    | Special case of `IsItemPtr` for `ioelsize(buffer) == 1`.    |

Default `ToBufferInterface` methods are built-in for common buffer types.



```{.julia .numberLines .lineAnchors startFrom="901"}
ToBufferInterface(x) = ToBufferInterface(typeof(x))
ToBufferInterface(::Type) = ToPush()
ToBufferInterface(::Type{<:IO}) = ToIO()
ToBufferInterface(::Type{<:Stream}) = ToStream()
ToBufferInterface(::Type{<:AbstractChannel}) = ToPut()
ToBufferInterface(::Type{<:Ref}) = UsingPtr()
ToBufferInterface(T::Type{<:AbstractArray}) = ArrayIOInterface(T)
ToBufferInterface(::Type{<:Ptr{T}}) where T = sizeof(T) == 1 ? IsBytePtr() :
                                                               IsItemPtr()
```


# Total Data Size Trait


```{.julia .numberLines .lineAnchors startFrom="915"}
abstract type TotalSize end
struct UnknownTotalSize <: TotalSize end
struct InfiniteTotalSize <: TotalSize end
abstract type KnownTotalSize end
struct VariableTotalSize <: KnownTotalSize end
struct FixedTotalSize <: KnownTotalSize end
const AnyTotalSize = TotalSize
```


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


```{.julia .numberLines .lineAnchors startFrom="947"}
TotalSize(x) = TotalSize(typeof(x))
TotalSize(T::Type) = is_proxy(T) ? TotalSize(unwrap(T)) :
                                   UnknownTotalSize()

abstract type SizeMechanism end
struct NoSizeMechanism <: SizeMechanism end
struct SupportsStatSize <: SizeMechanism end
struct SupportsFIONREAD <: SizeMechanism end
TotalSizeMechanism(x) = TotalSizeMechanism(typeof(x))
TotalSizeMechanism(T::Type) = is_proxy(T) ? TotalSizeMechanism(unwrap(T)) :
                                            NoSizeMechanism()

_length(stream, ::SupportsStatSize) = stat(stream).size
```


# Transfer Size Trait


```{.julia .numberLines .lineAnchors startFrom="965"}
abstract type TransferSize end
struct UnlimitedTransferSize <: TransferSize end
struct LimitedTransferSize <: TransferSize end
struct FixedTransferSize <: TransferSize end
const AnyTransferSize = TransferSize
```


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


```{.julia .numberLines .lineAnchors startFrom="992"}
TransferSize(s) = TransferSize(typeof(s))
TransferSize(T::Type) = is_proxy(T) ?  TransferSize(unwrap(T)) :
                                       UnlimitedTransferSize()

max_transfer_size(s) = max_transfer_size(s, TransferSize(s), TotalSize(s))
max_transfer_size(s, ::AnyTransferSize, ::AnyTotalSize) = typemax(UInt)
max_transfer_size(s, ::UnlimitedTransferSize, ::KnownTotalSize) = length(s)
max_transfer_size(s, ::LimitedTransferSize, ::AnyTotalSize) = 
    max_transfer_size(s, TransferSizeMechanism(s))
```


`TransferSizeMechanism(stream)` returns one of:

FIXME look at `F_GETPIPE_SZ` and `SO_SNDBUF`

 * `SupportsFIONREAD()` -- The underlying device supports `ioctl(2), FIONREAD`.
 * `SupportsStatSize()` -- The underlying device supports  `fstat(2), st_size`.


```{.julia .numberLines .lineAnchors startFrom="1012"}
TransferSizeMechanism(s) = TransferSizeMechanism(typeof(s))
TransferSizeMechanism(T::Type) = is_proxy(T) ?
                                 TransferSizeMechanism(unwrap(T)) :
                                 NoSizeMechanism()
```


# Data Availability Trait


```{.julia .numberLines .lineAnchors startFrom="1021"}
abstract type Availability end
struct AlwaysAvailable <: Availability end
struct PartiallyAvailable <: Availability end
struct UnknownAvailability <: Availability end
```


The `Availability` trait describes when data is available from a stream.

`Availability(stream)` returns one of:

--------------------------------------------------------------------------------
Availability            Description
----------------------- --------------------------------------------------------
`AlwaysAvailable()`     Data is always immediately available.
                        i.e. `bytesavailable` === `bytes_remaining`.
                        Applicable to some device files (dev/event, /dev/zero).
                        Applicable to local disk files.

`PartiallyAvailable()`  Some data may be immediately available from a buffer,
                        but `bytesavailable` can be less than `bytes_remaining`.

`UnknownAvailability()` There is no mechanism for determining data availability.
                        The only way to know how much data is available is to
                        attempt a transfer.
                        i.e. `bytesavailable` is always 0.
--------------------------------------------------------------------------------


```{.julia .numberLines .lineAnchors startFrom="1049"}
Availability(x) = Availability(typeof(x))
Availability(T::Type) = is_proxy(T) ? Availability(unwrap(T)) :
                                      UnknownAvailability()

_bytesavailable(s, ::UnknownAvailability,
                   ::AnyTransferSize) = 0

_bytesavailable(s, ::AlwaysAvailable,
                   ::UnlimitedTransferSize) = bytes_remaining(s)

_bytesavailable(s, ::AlwaysAvailable,
                   ::FixedTransferSize) = max_transfer_size(s)


_bytesavailable(s, ::PartiallyAvailable,
                   ::AnyTransferSize) =
    _bytesavailable(s, TransferSizeMechanism(s))
```


# Transfer Function Dispatch


    transfer_available(stream, buf, n, start)

Transfer at most `n` items between `stream` and `buffer`.
Return the number of items transferred.


```{.julia .numberLines .lineAnchors startFrom="1077"}
function transfer_available end
```


## `start` Index Normalisation

If `start` is a Tuple of indexes it is normalised by the method below.
The `StreamIndexing` trait is used to check that `stream` supports indexing.
Indexable streams are replaced by a `Tuple` containing `stream` and the
stream index.


```{.julia .numberLines .lineAnchors startFrom="1087"}
@db function transfer_available(stream, buf, n, start::Tuple)
    @require StreamIndexing(stream) == IndexableIO() || start[1] == 1
    @require start >= (1,1)
    if start[1] != 1
        stream = (stream, UInt(start[1]))
    end
    transfer_available(stream, buf, n, UInt(start[2]))
end
```


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


```{.julia .numberLines .lineAnchors startFrom="1113"}
transfer_available(stream, buf, n, start) = 
    transfer_available(stream, TransferDirection(stream), buf, n, start)

transfer_available(stream, ::In, buf, n, start) =
    transfer_available(stream, In(), buf, ToBufferInterface(buf), n, start)

transfer_available(stream, ::Out, buf, n, start) =
    transfer_available(stream, Out(), buf, FromBufferInterface(buf), n, start)
```


## Low Level Byte-Stream Methods


The specialised methods for various Buffer Interfaces eventually
call this this IsBytePtr method, which in turn calls the low level
`unsafe_transfer` implementation methods.


```{.julia .numberLines .lineAnchors startFrom="1131"}
@db function transfer_available(stream, direction, buf::Ptr{UInt8}, ::IsBytePtr,
                                n::UInt, start::UInt)
    r = unsafe_transfer(stream, direction, buf + (start-1), n)
    @ensure r isa UInt
    @db return r
end
```


This method handles items larger than one byte.
It returns zero if there are not enough bytes available for a whole item.
For streams with Unknown Transfer Size the requested transfer is attempted 
but an error is thrown if a partial item is transferred.


```{.julia .numberLines .lineAnchors startFrom="1145"}
@db function transfer_available(stream, direction, buf, ::IsItemPtr,
                                n::UInt, start::UInt)
    sz = ioelsize(buf)
    @assert sz > 1
    if Availability(stream) != UnknownAvailability()
        n::UInt = min(n, bytesavailable(stream) ÷ sz)
        n > 0 || @db return UInt(0)
    end

    buf = Ptr{UInt8}(buf)
    start = 1 + ((start-1) * sz)

    r = transfer_available(stream, direction, buf, IsBytePtr(), n * sz, start)
    @ensure r isa UInt

    if r % sz != 0
        @assert Availability(stream) == UnknownAvailability()
        r += transferall(stream, buf + (start-1) + r, r % sz)
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
    @db return r
end
```


At least one of the following `unsafe_transfer` methods must be implemented
for each type `T <: IOTraits.Stream`:

    unsafe_transfer(s::T, ::IOTraits.In,           buffer::Ptr{UInt8}, n::UInt)
    unsafe_transfer(s::T, ::IOTraits.Out,          buffer::Ptr{UInt8}, n::UInt)
    unsafe_transfer(s::T, ::IOTraits.Exchange,     buffer::Ptr{UInt8}, n::UInt)
    unsafe_transfer(s::T, ::IOTraits.AnyDirection, buffer::Ptr{UInt8}, n::UInt)

`unsafe_transfer` should transfer at most `n` items between `stream` and
`buffer` and return the number of items transferred (or zero if no items are
immediately available)[^BLOCKING].

[^BLOCKING]: ⚠️ Note that the `BaseIOStream` methods defined here do
not properly implement the specification because `unsafe_read` and
`unsafe_write` may block to wait for data. These methods are intended
for testing purposes only.  The transfer timeout feature will not
work properly for `BaseIOStream`.


```{.julia .numberLines .lineAnchors startFrom="1198"}
function unsafe_transfer end


unsafe_transfer(T::Type) = is_proxy(T) ? ReadFragmentation(unwrap(T)) :
                                           ReadsBytes()

unsafe_transfer(s::BaseIOStream, ::In, buf::Ptr{UInt8}, n::UInt) =
    UInt(unsafe_read(s.io, buf, n))

unsafe_transfer(s::BaseIOStream, ::Out, buf::Ptr{UInt8}, n::UInt) =
    UInt(unsafe_write(s.io, buf, n))
```


## Transfer Specialisations for Indexable Buffers


If `n` is missing, use the whole length of the buffer.

After this both `n` and `start` are always `UInt`s.


```{.julia .numberLines .lineAnchors startFrom="1220"}
@db function transfer_available(stream, direction::AnyDirection,
                                buf, interface::Union{UsingPtr, UsingIndex},
                                n::Missing, start::UInt)
    @require length(buf) > 0
    n = length(buf) - (start - 1)
    transfer_available(stream, direction, buf, interface, UInt(n), start)
end

transfer_available(stream, direction, buf, interface, n::Missing, start::UInt) =
    transfer_available(stream, direction, buf, interface, typemax(UInt), start)

transfer_available(stream, direction, buf, interface, n::Integer, start::Integer) = 
    transfer_available(stream, direction, buf, interface, UInt(n), UInt(start))
```


If the buffer is pointer-compatible convert it to a pointer.
`unsafe_transfer` function.


```{.julia .numberLines .lineAnchors startFrom="1239"}
@db function transfer_available(stream, ::AnyDirection, buf, ::UsingPtr,
                                n::UInt, start::UInt)
    checkbounds(buf, (start-1) + n)
    GC.@preserve buf transfer_available(stream, pointer(buf, start), n, 1)
end

@db function transfer_available(stream, ::AnyDirection, buf::Ref, ::UsingPtr,
                                n::UInt, start::UInt)
    p = Base.unsafe_convert(Ptr{eltype(buf)}, buf)
    GC.@preserve buf transfer_available(stream, p, n, 1)
end
```


If the buffer is not pointer-compatible, transfer one item at a time.


```{.julia .numberLines .lineAnchors startFrom="1255"}
@db function transfer_available(stream, d::AnyDirection, buf, ::UsingIndex,
                                n::UInt, start::UInt)
    T = ioeltype(buf)
    x = Vector{T}(undef, 1)
    count::UInt = 0
    for i in eachindex(view(buf, start:(start-1)+n))
        d == In() || (x[1] = buf[i])
        n = transfer(stream, x; deadline=0)
        if n == 0
            break
        end
        d == Out() || (buf[i] = x[1])
        count += n
        stream = next_stream_index(stream, T)
    end
    @db return count
end

next_stream_index((stream, i), T) = (stream, i + sizeof(T))
next_stream_index(stream::Stream, T) = stream
```


## Transfer Specialisations for Iterable Buffers


Iterate over `buf` (skip items until `start` index is reached).
Transfer each item one at a time.


```{.julia .numberLines .lineAnchors startFrom="1283"}
@db function transfer_available(stream, ::In, buf, ::FromIteration,
                                n::UInt, start::UInt)
    count::UInt = 0
    for x in buf
        if start > 1
            start -= 1
            continue
        end
        n = transfer(stream, [x]; deadline=0)
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


```{.julia .numberLines .lineAnchors startFrom="1305"}
for (T, f) in [ToPut => put!,
              ToPush => push!,
              FromPop => pop!,
              FromTake => take!]
    eval(:(transfer_available(s, dir, buf, ::$T, n::UInt, start::UInt) =
           transfer_available(s, dir, buf,   $f, n, start)))
end

@db function transfer_available(stream, d::TransferDirection, buf, f::Function,
                                n::UInt, start::UInt)
    @require start == 1
    T = ioeltype(buf)
    x = Vector{T}(undef, 1)
    count::UInt = 0
    while count < n
        d == In() || (x[1] = f(buf))
        r = transfer(stream, x; deadline=0)
        if r == 0
            break
        end
        d == Out() || f(buf, x[1])
        count += r
        stream = next_stream_index(stream, T)
    end
    @db return count
end
```


## Transfer Specialisations for IO Buffers


```{.julia .numberLines .lineAnchors startFrom="1336"}
@db function transfer_available(s1, ::In, s2, ::ToStream,
                                n::UInt, start::UInt)
    buf = Vector{UInt8}(undef, min(n, max(default_buffer_size(s1),
                                          default_buffer_size(s2))))
    count::UInt = 0
    while count < n
        r = transfer(s1 => buf; deadline=0)
        if r == 0
            break
        end
        r2 = transfer(buf => s2, r)
        @assert r2 == r
        # FIXME should query available capacity and not read more than that?
        count += r
    end
    return count
end

transfer_available(s1, ::Out, s2, ::FromStream, n::UInt, start::UInt) =
    transfer_available(s2, In(), s1, ToStream(), n, start)

function transfer_available(s, direction, io, ::Union{ToIO,FromIO},
                            n::UInt, start::UInt)
    s2 = BaseIOStream{typeof(io), direction == In() ? Out : In}(io)
    transfer_available(s, direction, s2, n, start)
end
```


# Data Fragmentation Trait


```{.julia .numberLines .lineAnchors startFrom="1368"}
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


```{.julia .numberLines .lineAnchors startFrom="1405"}
ReadFragmentation(s) = ReadFragmentation(typeof(s))
ReadFragmentation(T::Type) = is_proxy(T) ? ReadFragmentation(unwrap(T)) :
                                           ReadsBytes()
```


# Performance Traits


```{.julia .numberLines .lineAnchors startFrom="1412"}
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


```{.julia .numberLines .lineAnchors startFrom="1430"}
abstract type CursorSupport end
abstract type AbstractHasPosition <: CursorSupport end
struct NoCursors <: CursorSupport end
struct HasPosition <: AbstractHasPosition end
struct Seekable  <: AbstractHasPosition end
struct Markable  <: AbstractHasPosition end
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


```{.julia .numberLines .lineAnchors startFrom="1453"}
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

Base.position(io::BaseIO) = _position(io.stream, CursorSupport(io.stream))
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
```


# Peekable Trait


```{.julia .numberLines .lineAnchors startFrom="1489"}
abstract type PeekSupport end
struct Peekable <: PeekSupport end
struct NotPeekable <: PeekSupport end
PeekSupport(s) = PeekSupport(typeof(s))
PeekSupport(T::Type) = is_proxy(T) ? PeekSupport(unwrap(T)) :
                                     NotPeekable()

_peek(s, ::NotPeekable, T) = trait_error(s, Peekable)
```


# Timeout Stream


    TimeoutStream(stream; timeout, deadline) -> TimeoutStream
    timeout_stream(stream; timeout=Inf, deadline=Inf) -> Stream

The temporary `TimeoutStream` wrapper adds an immutable transfer deadline to a
stream. It is used in cases where a stream interface function needs to
make multiple calls to `transfer` (e.g. `readall`).

Note that the `timeout_stream` function simply returns `stream` if
`timeout` and `deadline` are both `Inf`.


```{.julia .numberLines .lineAnchors startFrom="1513"}
struct TimeoutStream{T<:Stream} <: Stream
    stream::T
    deadline::Float64
    function TimeoutStream(stream::T; timeout, deadline) where T
        @require timeout < Inf || deadline < Inf
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

@db function transfer(s::TimeoutStream{T}, buffer,
                      n::Union{Missing, Integer}; kw...) where T
    @info "transfer(t::TimeoutStream, ...)"
    transfer(s.stream, buffer, n; deadline = s.deadline, kw...)
end

unsafe_transfer(s::TimeoutStream, direction, buffer, n) =
    unsafe_transfer(s.stream, direction, buffer, n)
```


# Interface Functions


How many bytes remain before the end of `stream`?


```{.julia .numberLines .lineAnchors startFrom="1548"}
function bytes_remaning(stream::Stream)
    @require is_input(s)
    bytes_remaining(s, TotalSize(io), CursorSupport(io))
end

bytes_remaining(s, ::UnknownTotalSize, ::Any) = nothing
bytes_reamaining(s, ::InfiniteTotalSize, ::Any) = typemax(UInt)
bytes_remaining(s, ::KnownTotalSize, ::AbstractHasPosition) =
    length(s) - position(s)
```


`readbyte` returns one byte
(or `nothing` at end of stream or if `timeout` expires).

Specialized based on Transfer Cost.


```{.julia .numberLines .lineAnchors startFrom="1566"}
function readbyte(s::Stream; timeout=Inf)
    @require is_input(s)
    readbyte(s, TransferCost(s); timeout)
end

readbyte(s, ::HighTransferCost; kw...) =
    error(typeof(s), " does not support byte I/O. ",
          "Consider using the `LazyBufferedInput` wrapper.")
```


Allow single byte read for interfaces with Low Transfer Cost,
but warn if a special Read Fragmentation trait is available.[^WARNINGS]

[^WARNINGS]: ⚠️ FIXME: Warnings should be configurable via Preferences.jl


```{.julia .numberLines .lineAnchors startFrom="1582"}
function readbyte(stream, ::LowTransferCost; timeout)
    if ReadFragmentation(stream) == ReadsLines()
        @warn "read(::$(typeof(stream)), UInt8): " *
              "$(typeof(stream)) implements `IOTraits.ReadsLines`." *
              "Reading one byte at a time may not be efficient." *
              "Consider using `readline` instead."
    end
    x = Ref{UInt8}()
    n = GC.@preserve x transfer(stream => pointer(x), 1)
    n == 1 || return nothing
    return x[]
end
```


`readall` reads until the end of `stream` (or until `timeout` expires)
and returns `Vector{UInt8}`.

Specialise on Total Size and Cursor Support.


```{.julia .numberLines .lineAnchors startFrom="1603"}
function readall(s::Stream; timeout=Inf)
    @require is_input(s)
    readall(s, TotalSize(s), CursorSupport(s); timeout)
end


function readall(stream, ::UnknownTotalSize, ::NoCursors)
    n = default_buffer_size(stream)
    buf = Vector{UInt8}(undef, n)
    _readbytes!(stream, buf, typemax(UInt))
    return buf
end


function readall(stream, ::KnownTotalSize, ::AbstractHasPosition)
    n = length(stream) - position(stream)
    buf = Vector{UInt8}(undef, n)
    transferall(stream, buf, n)
    return buf
end
```


Transfer `n` items between `stream` and `buf`.

Call `transfer` repeatedly until all `n` items have been Transferred, 
stopping only if end of file is reached.

Return the number of items transferred.


```{.julia .numberLines .lineAnchors startFrom="1633"}
@db function transferall(stream, buf, n=length(buf); deadline=Inf, timeout=Inf)
    stream = timeout_stream(stream; timeout, deadline)
    ntransferred::UInt = 0
    while ntransferred < n
        r = transfer(stream, buf, n - ntransferred; start = ntransferred + 1)
                                            # FIXME ^^^^^ passing start is not allowed for ToPut etc
        if r == 0
            break
        end
        ntransferred += r
    end
    @ensure ntransferred isa UInt
    @db return ntransferred
end

@db function transferall(t::Pair{<:Stream,<:Any}, a...; kw...)
    @require TransferDirection(t[1]) == In()
    transferall(t[1], t[2], a...; kw...)
end

@db function transferall(t::Pair{<:Any,<:Stream}, a...; kw...)
    @require TransferDirection(t[1]) == Out()
    transferall(t[2], t[1], a...; kw...)
end
```


# Null Streams


`NullIn()` is an input stream that does nothing.
It is intended to be used for testing Delegate Streams.


```{.julia .numberLines .lineAnchors startFrom="1668"}
struct NullIn <: Stream end

TransferDirection(::Type{NullIn}) = In()

transfer(io::NullIn, buf::Ptr{UInt8}, n; kw...) = n


#=
FIXME
include("wrap.jl")
```


`@delegate_io f` creates wrapper methods for function `f`.
A separate method is created with a specific 2nd argument type for
each 2nd argument type used in pre-existing methods of `f`
(to avoid method selection ambiguity). e.g.

    f(io::IODelegate; kw...) = f(unwrap(io); kw...)
    f(io::IODelegate, a2::T, a...; kw...) = f(unwrap(io), a2, a...; kw...)


```{.julia .numberLines .lineAnchors startFrom="1688"}
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
```


# Buffered Streams


Generic type for Buffered Input Wrappers.

See concrete types `BufferedInput` and `LazyBufferedInput` below.


```{.julia .numberLines .lineAnchors startFrom="1727"}
abstract type GenericBufferedInput{T} <: Stream end

function Base.show(io::IO, s::GenericBufferedInput{T}) where T
    print(io, "GenericBufferedInput{", T, "}(", bytesavailable(s.buffer), ")")
end

StreamDelegation(::Type{<:GenericBufferedInput}) = DelegatedToSubStream()

TransferCost(::Type{<:GenericBufferedInput}) = LowTransferCost()

ReadFragmentation(::Type{<:GenericBufferedInput}) = ReadsBytes()

PeekSupport(::Type{<:GenericBufferedInput}) = Peekable()

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

Base.close(s::GenericBufferedInput) = ( take!(s.buffer);
                                        Base.close(s.io) )
```


Size of the internal buffer.


```{.julia .numberLines .lineAnchors startFrom="1759"}
buffer_size(s::GenericBufferedInput) = s.buffer_size
```


Buffer ~1 second of data by default.


```{.julia .numberLines .lineAnchors startFrom="1765"}
default_buffer_size(stream) = DataRate(stream)
```


Transfer bytes from the wrapped IO to the internal buffer.


```{.julia .numberLines .lineAnchors startFrom="1771"}
@db function refill_internal_buffer(s::GenericBufferedInput,
                                    n=s.buffer_size; kw...)
    # If needed, expand the buffer.
    sbuf = s.buffer
    @assert sbuf.append
    Base.ensureroom(sbuf, n)
    checkbounds(sbuf.data, sbuf.size+n)

    # Transfer from the stream to the buffer.
    p = pointer(sbuf.data, sbuf.size+1)
    n = GC.@preserve sbuf transfer(s.stream, p, n; kw...)
    sbuf.size += n
    nothing
end

function readbyte(s::GenericBufferedInput; timeout)
    sbuf = s.buffer
    if bytesavailable(sbuf) == 0
        refill_internal_buffer(s; timeout)
    end
    if bytesavailable(sbuf) != 0
        return read(sbuf, UInt8)
    end
    @invoke readbyte(s::Stream; timeout)
end

function _peek(s::GenericBufferedInput, ::Type{T}; kw...) where T
    while bytesavailable(s.buffer) < sizeof(T)
        refill_internal_buffer(s; kw...)
    end
    peek(s.buffer, T)
end
```


## Buffered Input


    BufferedInput(stream; [buffer_size]) -> Stream

Create a wrapper around `stream` to buffer input transfers.

The wrapper will try to read `buffer_size` bytes into its buffer
every time it transfers data from `stream`.

The default `buffer_size` depends on `IOTratis.DataRate(stream)`.

`stream` must not be used directly after the wrapper is created.


```{.julia .numberLines .lineAnchors startFrom="1820"}
struct BufferedInput{T<:Stream} <: GenericBufferedInput{T}
    stream::T
    buffer::IOBuffer
    buffer_size::Int
    function BufferedInput(stream::T; buffer_size=default_buffer_size(stream)) where T
        @require TransferDirection(stream) == In()
        buffered_in_warning(stream)
        new{T}(stream, PipeBuffer(), buffer_size)
    end
end

TransferSize(::Type{BufferedInput{T}}) where T = LimitedTransferSize()

max_transfer_size(s::BufferedInput) = s.buffer_size
```


The non-buffered method returns zero if there are not enough bytes
available to transfer a whole item (`ioelsize`).
This method refills the internal buffer if there are less than `ioelsize`
bytes available. Note that `refill_internal_buffer` may still not yield
enough bytes. However, calling it here ensures that the enclosing retry
loop will eventually get the data it needs.


```{.julia .numberLines .lineAnchors startFrom="1844"}
@db function transfer_available(s::BufferedInput, direction,
                                buf, interface::IsItemPtr,
                                n::UInt, start::UInt)
    @assert ioelsize(buf) > 1
    @assert ioelsize(buf) < s.buffer_size

    if bytesavailable(s) < ioelsize(buf)
        refill_internal_buffer(s)
    end

    @invoke transfer_available(s::Stream, direction,
                               buf, interface::IsItemPtr,
                               n::UInt, start::UInt)
end



@db function Base.bytesavailable(s::BufferedInput) 
    n = bytesavailable(s.buffer) 
    if n == 0
        n = bytesavailable(s.stream) 
    end
    @db return n
end



@db function unsafe_transfer(s::BufferedInput, ::In, buf::Ptr{UInt8}, n::UInt)

    sbuf = s.buffer
    # If there are not enough bytes in `sbuf`, read more from the wrapped stream.
    if bytesavailable(sbuf) < n
        refill_internal_buffer(s)
    end

    # Read available bytes from `sbuf` into the caller's `buffer`.
    n = min(n, bytesavailable(sbuf))
    unsafe_read(sbuf, buf, n)
    @db return n
end
```


## Lazy Buffered Input


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


```{.julia .numberLines .lineAnchors startFrom="1905"}
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


Base.bytesavailable(s::LazyBufferedInput) = bytesavailable(s.buffer) + 
                                            bytesavailable(s.stream);

@db function unsafe_transfer(s::LazyBufferedInput, ::In, buf::Ptr{UInt8}, n::UInt)

    # First take bytes from the buffer.
    sbuf = s.buffer
    count = bytesavailable(sbuf)
    if count > 0
        count = min(count, n)
        unsafe_read(sbuf, buf, count)
    end

    # Then read from the wrapped IO.
    if n > count
        count += unsafe_transfer(s.stream, In(), buf + count, n - count)
    end

    @ensure count <= n
    @db return count
end
```


# Base.IO Interface


```{.julia .numberLines .lineAnchors startFrom="1943"}
Base.isreadable(io::BaseIO) = is_input(io.stream)
Base.iswritable(io::BaseIO) = is_output(io.stream)
```


## Function `eof`


`eof` is specialised on Total Size.


```{.julia .numberLines .lineAnchors startFrom="1952"}
function Base.eof(io::BaseIO; timeout=Inf)
    @require is_input(io.stream)
    if bytesavailable(io) > 0
        return false
    end
    if bytes_remaining(io) == 0
        return true
    end
    wait(io.stream; kw...)
    return bytesavailable(io) == 0
end
```


## Function `read(io, T)`


```{.julia .numberLines .lineAnchors startFrom="1967"}
function Base.read(io::BaseIO, ::Type{UInt8}; timeout=Inf)
    x = readbyte(io.stream, timeout)
    x != nothing || throw(EOFError())
    return x
end
```


Read as String. \
Wrap with `TimeoutStream` if timeout is requested.


```{.julia .numberLines .lineAnchors startFrom="1978"}
function Base.read(io::BaseIO, ::Type{String}; timeout=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    String(_read(stream, TotalSize(stream), CursorSupport(stream)))
end
```


## Function `readbytes!`


```{.julia .numberLines .lineAnchors startFrom="1988"}
Base.readbytes!(io::BaseIO, buf::Vector{UInt8}, nbytes=length(buf); kw...) =
    readbytes!(io, buf, UInt(nbytes); kw...)

function Base.readbytes!(io::BaseIO, buf::Vector{UInt8}, nbytes::UInt;
                         all::Bool=true, timeout=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    _readbytes!(stream, buf, nbytes; all)
end

function _readbytes!(stream, buf, nbytes; all=true)
    lb::Int = length(buf)
    nread = 0
    while nread < nbytes
        @assert nread <= lb
        if (lb - nread) == 0
            lb = lb == 0 ? nbytes : min(lb * 10, nbytes)
            resize!(buf, lb)
        end
        @assert lb > nread
        n = transfer(stream => buf, lb - nread; start = nread + 1)
        if n == 0 || !all
            break
        end
        nread += n
    end
    @ensure nread <= nbytes
    return nread
end
```


## Function `read(stream)`


```{.julia .numberLines .lineAnchors startFrom="2022"}
Base.read(io; timeout=Inf) = readall(io.stream; timeout)
```


## Function `read(stream, n)`


```{.julia .numberLines .lineAnchors startFrom="2029"}
function Base.read(stream::BaseIO, n::Integer; timeout=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    buf = Vector{UInt8}(undef, n)
    transfer_n(stream, buf, n)
    return buf
end
```


## Function `unsafe_read`


`unsafe_read` must keep trying until `nbytes` nave been transferred.


```{.julia .numberLines .lineAnchors startFrom="2043"}
function Base.unsafe_read(io::BaseIO, buf::Ptr{UInt8}, nbytes::UInt;
                          timeout=Inf)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    nread = 0
    @debug "Base.unsafe_read(io::BaseIO, buf::Ptr{UInt8}, nbytes::UInt)"
    while nread < nbytes
        n = transfer(stream => (buf + nread), nbytes - nread)
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


    readavailable(stream::BaseIO; [timeout=0]) -> Vector{UInt8}

Read immediately available data from a stream.

If `Availability(stream)` is `UnknownAvailability()` the only way to know how
much data is available is to attempt a transfer.

Otherwise, the amount of data immediately available can be queried using the
`bytesavailable` function.


```{.julia .numberLines .lineAnchors startFrom="2075"}
@db function Base.readavailable(io::BaseIO; timeout=0)
    @require is_input(io.stream)
    if Availability(io.stream) == UnknownAvailability()
        n = default_buffer_size(io.stream)
    else
        n = bytesavailable(io.stream)
    end
    buf = Vector{UInt8}(undef, n)
    n = transfer(stream, buf, n; timeout)
    resize!(buf, n)
end
```


## Function `readline`


`readline` is specialised based on the Read Fragmentation trait.


```{.julia .numberLines .lineAnchors startFrom="2094"}
function Base.readline(io::BaseIO; timeout=Inf, kw...)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    _readline(stream, ReadFragmentation(stream); kw...)
end
```


If there is no special Read Fragmentation method,
invoke the default `Base.IO` method.


```{.julia .numberLines .lineAnchors startFrom="2104"}
_readline(stream, ::AnyReadFragmentation; kw...) =
    @invoke Base.readline(BaseIO(stream)::IO; kw...)
```


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


```{.julia .numberLines .lineAnchors startFrom="2125"}
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
```


## Function `readuntil`


```{.julia .numberLines .lineAnchors startFrom="2147"}
function Base.readuntil(io::BaseIO, d::AbstractChar; timeout=Inf, kw...)
    @require is_input(io.stream)
    stream = timeout_stream(io.stream; timeout)
    @invoke Base.readuntil(BaseIO(stream)::IO, d; kw...)
end
```


# Exports


```{.julia .numberLines .lineAnchors startFrom="2157"}
export TraitsIO, TransferDirection, transfer, transferall, readall

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
       WaitUsingKQueue

export CursorSupport, AbstractHasPosition,
       NoCursors,
       HasPosition,
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




## Errors


```{.julia .numberLines .lineAnchors startFrom="2258"}
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
```
