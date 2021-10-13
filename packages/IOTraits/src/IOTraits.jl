"""
# IOTraits.jl

[Trait types][White] for describing the capabilities and behaviour of
IO interfaces.


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

This collection expands on the traits from UnixIO.jl in the hope of making
them more broadly useful.
According to the [law of the hammer][Hammer] some of this is probably 
overkill. The intention is to consider the application of Trait types
to various aspects of IO and to see where it leads.

[White]: https://www.juliabloggers.com/the-emergent-features-of-julialang-part-ii-traits/

[Hammer]: https://en.wikipedia.org/wiki/Law_of_the_hammer

[Duck]: https://en.wikipedia.org/wiki/Duck_typing


## Overview

The IOTraits interface is built around the `transfer(io, buffer)` function.
This function transfers data between an IO interface and a buffer.

Traits are used to specify the behaviour of the IO and the buffer.

#### `IODirection`
Which way is the transfer?
(`In`, `Out` or `Exchange`).

#### `FromBufferInterface`
How to get data from the buffer?
(`FromIO`, `FromPop`, `FromTake`, `FromIndex`, `FromIteration` or `FromPtr`)

#### `ToBufferInterface` 
How to put data into the buffer?
(`ToIO`, `ToPush`, `ToPut`, `ToIndex` or `ToPtr`)

#### `TotalSize`
How much data is available?
(`UnknownTotalSize`, `VariableTotalSize`, `FixedTotalSize`, or
 `InfiniteTotalSize`)

#### `TransferSize`
How much data can be moved in a single transfer?
(`UnknownTransferSize`, `KnownTransferSize`, `LimitedTransferSize` or
 `FixedTransferSize`)

#### `ReadFragmentation`
What guarantees are made about fragmentation?
(`ReadsBytes`, `ReadsLines`, `ReadsPackets` or `ReadsRequestedSize`)

#### `WaitingMechanism`
How to wait for activity?
(`WaitBySleeping`, `WaitUsingPosixPoll`, `WaitUsingEPoll`, `WaitUsingPidFD` or
 `WaitUsingKQueue`)
 


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
"""
module IOTraits

using Preconditions
@static if VERSION > v"1.6"
using Preferences
end


# Transfer Direction Trait.


abstract type IODirection end
struct In <: IODirection end
struct Out <: IODirection end
struct Exchange <: IODirection end

"""
### `IODirection` -- Transfer Direction Trait.

The `IODirection` trait describes the direction of data transfer
for an IO interface. `IODirection(typeof(io))` returns one of:

 * `In()` -- data is "read" from the `IO`.
 * `Out()` -- data is "written" to the `IO`.
 * `Exchange()` -- data is simultaneously exchanged
                   between the `io` and a buffer (e.g. like [SPI][SPI]).

[SPI]: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
"""
IODirection(x) = IODirection(typeof(x))



# Transfer Function.


"""
## `transfer()` - The Data Transfer Function

```julia
transfer(io, buffer [, n=1] [;start=(1 => 1)]) -> n_transfered
```

Transfer at most `n` items between `io` and `buffer`.

Return the number of items transferred.

The type of transfer depends on the `IODirection(io)`
 (`In`, `Out` or `Exchange`).

`start` specifies the starting indexes for the transfer
(if `hasioindex(io)` and/or `hasioindex(buffer)` are true).

The type of items transferred depends on `ioeltype(io)` and `ioeltype(buffer)`.
By default `ioeltype(x) = eltype(x)`.

The `buffer` can be an `AbstractArray`, an `AbstractChannel`, a `URI` or an `IO`.

Or, the `buffer` can be any collection that implements
the Iteration Interface, the Indexing Interface,
the AbstractChannel interface, or the `push!`/`pop!` interface.
In some cases it is necessary to define a method of `ToBufferInterface()`
or `FromBufferInterface()` to specify the interface to use for a particular
buffer type (e.g. if a buffer implements more than one of the supported
interfaces).
Defining these trait methods can also help to ensure that the most efficient
interface is used for a particular buffer type.

If either the `io` or the `buffer` is a `URI` then items are transferred
to (or from) the identified resource.
A transfer to a `URI` creates a new resource or replaces the resource
(i.e. HTTP PUT semantics).

```julia
transfer(io => buffer [, n=1] [;start=(1 => 1)]) -> n_transfered
transfer(buffer => io [, n=1] [;start=(1 => 1)]) -> n_transfered
```

`io` and `buffer` can be passed as a pair.
An `In()` io must be on the left.
An `Out()` io must be on the right.
"""
function transfer end



# From Buffer Interface Trait.


abstract type FromBufferInterface end
struct FromIO <: FromBufferInterface end
struct FromPop <: FromBufferInterface end
struct FromTake <: FromBufferInterface end
struct FromIndex <: FromBufferInterface end
struct FromIteration <: FromBufferInterface end
struct FromPtr <: FromBufferInterface end

"""
### `FromBufferInterface` -- Data Transfer Source Interface Trait.

The `FromBufferInterface` trait defines what interface is used to take
data from a particular buffer type
(or what interface is preferred for best performance).

`FromBufferInterface(typeof(buffer))` returns one of:

 * `FromIO()` -- Take data from the buffer using the `Base.IO` interface.
 * `FromPop()` -- Use `pop!(buffer)` to read from the buffer.
 * `FromTake()` -- Use `take!(buffer)`.
 * `FromIndex()` -- Use `buffer[i]` (the default).
 * `FromIteration()` -- Use `for x in buffer...`.
 * `FromPtr()` -- Use `unsafe_copyto!(buffer, x, n)`.

Default `FromBufferInterface` methods are built in for common buffer types:
"""
FromBufferInterface(x) = FromBufferInterface(typeof(x))
FromBufferInterface(::Type) = FromIteration()
FromBufferInterface(::Type{<:IO}) = FromIO()
FromBufferInterface(::Type{<:AbstractArray}) = FromIndex()
FromBufferInterface(::Type{<:AbstractChannel}) = FromTake()
FromBufferInterface(::Type{<:Ptr}) = FromPtr()



# To Buffer Interface Trait.

abstract type ToBufferInterface end
struct ToIO <: ToBufferInterface end
struct ToPush <: ToBufferInterface end
struct ToPut <: ToBufferInterface end
struct ToIndex <: ToBufferInterface end
struct ToPtr <: ToBufferInterface end


"""
### `ToBufferInterface` -- Data Transfer Destination Interface Trait.

The `ToBufferInterface` trait defines what interface is used to store data
in a particular type of buffer
(or what interface is preferred for best performance).

`ToBufferInterface(typeof(buffer))` one of:

 * `ToIO` -- Write data to the buffer using the `Base.IO` interface.
 * `ToPush` -- Use `push!(buffer, data)`
 * `ToPut` -- Use `put!(buffer, data)`
 * `ToIndex` -- Use `buffer[i] = data (the default)`
 * `ToPtr` -- Use `unsafe_copyto!(x, buffer, n)`.

Default `ToBufferInterface` methods are built in for common buffer types.
"""
ToBufferInterface(x) = ToBufferInterface(typeof(x))
ToBufferInterface(::Type) = ToPush()
ToBufferInterface(::Type{<:IO}) = ToIO()
ToBufferInterface(::Type{<:AbstractArray}) = ToIndex()
ToBufferInterface(::Type{<:AbstractChannel}) = ToPut()
ToBufferInterface(::Type{<:Ptr}) = ToPtr()



# Total Size Trait.

abstract type TotalSize end
struct UnknownTotalSize <: TotalSize end
struct InfiniteTotalSize <: TotalSize end
abstract type KnownTotalSize end
struct VariableTotalSize <: KnownTotalSize end
struct FixedTotalSize <: KnownTotalSize end

"""
### `TotalSize` -- Data Size Trait.

The `TotalSize` trait describes how much data is available from an
IO interface.

`TotalSize(typeof(io))` returns one of:

 * `VariableTotalSize()` -- The total amount of data available can be queried
   using the `length` function. Note: the total size can change. e.g. new
   lines might be appended to a log file.
 * `FixedTotalSize()` -- The amount of data is known and will not change.
   Applicable to block devices. Applicable to some network streams. e.g.
   a HTTP Message where Content-Length is known.
 * `InfiniteTotalSize()` -- End of file will never be reached. Applicable
   to some device files.
 * `UnknownTotalSize()` -- No known data size limit.
"""
TotalSize(x) = TotalSize(typeof(x))
TotalSize(::Type) = UnknownTotalSize()



# Transfer Size Trait.


abstract type TransferSize end
struct UnknownTransferSize <: TransferSize end
struct KnownTransferSize <: TransferSize end
struct LimitedTransferSize <: TransferSize end
struct FixedTransferSize <: TransferSize end

"""
### `TransferSize` -- Transfer Size Trait.

The `TransferSize` trait describes how much data can be moved in a single
transfer.

`TransferSize(typeof(io))` returns one of:

 * `UnknownTransferSize()` -- Transfer size is not known in advance.
   The only way to know how much data is available is to attempt a transfer.
 * `KnownTransferSize()` -- The amount of data immediately available for
   transfer can be queried using the `bytesavailable` function.
 * `LimitedTransferSize()` -- The amount of data that can be moved in a single
   transfer is limited. e.g. by a device block size or buffer size. The maximum
   transfer size can queried using the `max_transfer_size` function.
   The amount of data immediately available for transfer can be queried using
   the `bytesavailable` function.
 * `FixedTransferSize()` -- The amount of data that moved by a single trasfer
   is fixed. e.g. `/dev/input/event0` device always transfers
   `sizeof(input_event)` bytes.

"""
TransferSize(x) = TransferSize(typeof(x))
TransferSize(t::Type) = TransferSizeMechanism(t) == NoSizeMechanism() ?
                        UnknownTransferSize() :
                        KnownTransferSize()


abstract type TransferSizeMechanism end
struct NoSizeMechanism <: TransferSizeMechanism end
struct SupportsFIONREAD <: TransferSizeMechanism end
struct SuppoutsStatSize <: TransferSizeMechanism end

"""
`TransferSizeMechanism(typeof(io))` returns one of:

 * `SupportsFIONREAD()` -- The underlying device supports `ioctl(2), FIONREAD`.
 * `SuppoutsStatSize()` -- The underlying device supports  `fstat(2), st_size`.
"""
TransferSizeMechanism(x) = TransferSizeMechanism(typeof(x))
TransferSizeMechanism(::Type) = NoSizeMechanism()



# Data Fragmentation Trait.


abstract type ReadFragmentation end
struct ReadsBytes         <: ReadFragmentation end
struct ReadsLines         <: ReadFragmentation end
struct ReadsPackets       <: ReadFragmentation end
struct ReadsRequestedSize <: ReadFragmentation end


"""
### `ReadFragmentation` -- Data Fragmentation Trait.

The `ReadFragmentation` trait describes what guarantees an IO interface makes
about fragmentation of data returned by the underlying `read(2)` system call.

`ReadFragmentation(typeof(io))` returns one of:

 * `ReadsBytes` -- No special guarantees about what is returned by `read(2)`.
   This is the default.

 * `ReadsLines` -- `read(2)` returns exactly one line at a time.
   Does not return partially buffered lines unless an explicit `EOL` or `EOF`
   control character is received.
   Applicable to Character devices in canonical mode.
   See [termios(3)](https://man7.org/linux/man-pages/man3/termios.3.html).

 * `ReadsPackets` -- `read(2)` returns exactly one packet at a time.
   Does not return partially buffered packets.
   Applicable to some sockets and pipes depending on configuration.
   e.g. See the `O_DIRECT` flag in
   [pipe(2)](https://man7.org/linux/man-pages/man2/pipe.2.html).

 * `ReadsRequestedSize` -- `read(2)` returns exactly the number of elements
   requested (or throws an exception).
   Applicable to local files and some virtual files (e.g. `/dev/random`,
   `/dev/null`).
"""
ReadFragmentation(x) = ReadFragmentation(typeof(x))
ReadFragmentation(::Type) = ReadsBytes()



# Event Notification Mechanism Trait.


abstract type WaitingMechanism end
struct WaitBySleeping     <: WaitingMechanism end
struct WaitUsingPosixPoll <: WaitingMechanism end
struct WaitUsingEPoll     <: WaitingMechanism end
struct WaitUsingPidFD     <: WaitingMechanism end
struct WaitUsingKQueue    <: WaitingMechanism end


"""
### `WaitingMechanism` -- Event Notificaiton Mechanism Trait.

The `WaitingMechanism` trait describes ways of waiting for OS resources
that are not immediately available. e.g. when `read(2)` returns
`EAGAIN` (`EWOULDBLOCK`), or when `waitpid(2)` returns `0`.

Resource types, `R`, that have an applicable `WaitingMechanism`, `T`,
define a method of `Base.wait(::T, r::R)`.

If a `WaitingMechanism`, `T`, is not available on a particular OS
then `Base.isvalid(::T)` should be defined to return `false`.

`WaitingMechanism(typeof(io))` returns one of:

 * `WaitBySleeping` -- Wait using a dumb retry/sleep loop (the default).
   This may be more efficient for small systems with simple IO requirements,
   or for systems that simply do not spend a lot of time waiting for IO.

 * `WaitUsingPosixPoll` -- Wait using the POXSX `poll` mechanism.
   Wait for activity on a set of file descriptors.
   Applicable to FIFO pipes, sockets and character devices
   (but not local files).
   See [`poll(2)`](https://man7.org/linux/man-pages/man2/poll.2.html)

 * `WaitUsingEPoll` -- Wait using the Linux `epoll` mechanism.
   Like `poll` but scales better for workloads with a large number of
   waiting streams.
   See [`epoll(7)`](https://man7.org/linux/man-pages/man7/epoll.7.html)

 * `WaitUsingKQueue` -- Wait using the BSB `kqueue` mechanism.
   Like `epoll` but can also wait for files, processes, signals etc.
   See [`kqueue(2)`](https://www.freebsd.org/cgi/man.cgi?kqueue)

 * `WaitUsingPidFD()` -- Wait for process termination using
   the Linux `pidfd` mechanism. A `pidfd` is a special process monitoring
   file descriptor that can in turn be monitored by `poll` or `epoll`. See
   [`pidfd_open(2)`](http://man7.org/linux/man-pages/man2/pidfd_open.2.html).

TODO: Consider Linux AIO `io_getevents` for disk io?


"""
WaitingMechanism(x) = WaitingMechanism(typeof(x))
WaitingMechanism(::Type) = WaitBySleeping()

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


@static if VERSION > v"1.6"
"""
## Preferred Polling Mechanism

    set_poll_mechanism(name)

Configure the preferred event polling mechanism:
"kqueue", "epoll", "poll", or "sleep".

Note: this setting applies only to `poll(2)`-compatible file descriptors
(i.e. it does not apply to local disk files).

By default, IOTraits will try to choose the best available mechanism
(see `default_poll_mechanism`).

This setting is persistently stored through [Preferences.jl][Prefs].

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
else
const preferred_poll_mechanism = nothing
end


# Exports.

export transfer

export TotalSize,
       UnknownTotalSize, InfiniteTotalSize, KnownTotalSize, VariableTotalSize,
       FixedTotalSize

export TransferSize,
       UnknownTransferSize, KnownTransferSize, LimitedTransferSize,
       FixedTransferSize

export TransferSizeMechanism,
       NoSizeMechanism, SupportsFIONREAD, SuppoutsStatSize

export ReadFragmentation,
       ReadsBytes, ReadsLines, ReadsPackets, ReadsRequestedSize

export WaitingMechanism,
       WaitBySleeping, WaitUsingPosixPoll, WaitUsingEPoll, WaitUsingPidFD,
       WaitUsingKQueue

using ReadmeDocs



end # module IOTraits
