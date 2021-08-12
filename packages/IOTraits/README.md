# IOTraits.jl

Trait types for describing the capabilities and behaviour of IO interfaces.

pread ? readv writev ? sendfile ?

### `IODirection` -- Transfer Direction Trait.

The `IODirection` trait describes the direction of data transfer
for an IO interface. `IODirection(typeof(io))` returns one of:

 * `In()` -- data is "read" from the `IO`.

 * `Out()` -- data is "written" to the `IO`.

 * `Exchange()` -- data is simultaneously exchanged
   between the `io` and a buffer.

## `transfer()` - The Data Transfer Function

    transfer(io => buffer [, n==1] [;start=(1 => 1)]) -> n_transfered
    transfer(buffer => io [, n==1] [;start=(1 => 1)]) -> n_transfered
    transfer(io,   buffer [, n==1] [;start=(1 => 1)]) -> n_transfered

Transfer at most `n` items between `io` and `buffer`.

Return the number of items transferred.

If `hasioindex(io)` and/or `hasioindex(buffer)` are true then
`start` specifies the starting indexes for the transfer.

The type of items transferred depends on `ioeltype(io)` and `ioeltype(buffer)`.
By default `ioeltype(x) = eltype(x)`.
FIXME: Mismatch details.

The `buffer` can be an `AbstractArray`, an `AbstractChannel`, a `URI` or an `IO`.

The `buffer` can also be any collection that implements
the Iteration Interface, the Indexing Interface,
the AbstractChannel interface, or the `push!`/`pop!` interface.

In some cases it is necessary to define a methods of the `ToBufferInterface()`
or `FromBufferInterface()` trait functions to specify what interface a particular
buffer type uses.
Defining these trait methods can also help to ensure that the most efficient
interface is used for a particular buffer type.

The type of transfer depends on the `IODirection(io)`:

 * `In()` -- items are "read" from the `io` into the `buffer`.

 * `Out()` -- items are "written" from the `buffer` to the `io`.

 * `Exchange()` -- items are "written" from the `buffer` into `io`,
   and are replaced by items "read" from the `io`.

If `io` and `buffer` are passed as a pair then the `io` must be;
on the left if it's direction is `In()`; or on the right if its
direction is `Out()`.

If either the `io` or the `buffer` is a `URI` then items are transferred
to (or from) the identified resource.
A transfer to a `URI` creates a new resource or replaces the resource
(i.e. HTTP PUT semantics).

### `FromBufferInterface` -- Data Transfer Source Interface Trait.

The `FromBufferInterface` trait defines what interface is used to take
data from a particular buffer type
(or what interface is preferred for best performance).

`FromBufferInterface(typeof(buffer))` returns one of:

 * `FromIO()` -- Take data from the buffer using the `IO` interface.
 * `FromPop()` -- Use `pop!(buffer)` to read from the buffer.
 * `FromTake()` -- Use `take!(buffer)`.
 * `FromIndex()` -- Use `buffer[i]` (the default).
 * `FromIteration()` -- Use `for x in buffer...`.
 * `FromPtr()` -- Use `unsafe_copyto!(buffer, x, n)`.

Default `FromBufferInterface` methods are built in for common buffer types.

### `ToBufferInterface` -- Data Transfer Destination Interface Trait.

The `ToBufferInterface` trait defines what interface is used to store data
in a particular type of buffer
(or what interface is preferred for best performance).

`ToBufferInterface(typeof(buffer))` one of:

 * `ToIO` -- Write data to the buffer using the `IO` interface.
 * `ToPush` -- Use `push!(buffer, data)`
 * `ToPut` -- Use `put!(buffer, data)`
 * `ToIndex` -- Use `buffer[i] = data (the default)`
 * `ToPtr` -- Use `unsafe_copyto!(x, buffer, n)`.

Default `ToBufferInterface` methods are built in for common buffer types.

### `TotalSize` -- Data Size Trait.

The `TotalSize` trait describes how much data is available from an
IO interface.

`TotalSize(typeof(io))` returns one of:

 * `KnownTotalSize()` -- The total amount of data available can be queried
   using the `length` function. Note: the total size can change. e.g. new
   lines might be appended to a log file.

 * `FixedTotalSize()` -- The amount of data is known and will not change.
   Applicable to block devices. Applicable to some network streams. e.g.
   a HTTP Message where Content-Length is known.

 * `UnknownTotalSize()` -- No known data size limit.

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

### `WaitingMechanism` -- Event Notificaiton Mechanism Trait.

The `WaitingMechanism` trait describes ways of waiting for OS resources
that are not immediately available. e.g. when `read(2)` returns
`EAGAIN` (`EWOULDBLOCK`), or when `waitpid(2)` returns `0`.

Resource types, `R`, that have an applicable `WaitingMechanism`, `T`,
define `Base.wait(::T, r::R)`.

If a `WaitingMechanism`, `T`, is not available on a particular OS
then `Base.isvalid(::T)` should be defined to return `false`.
TODO: Configure via https://github.com/JuliaPackaging/Preferences.jl

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
