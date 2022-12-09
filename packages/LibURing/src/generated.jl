using CEnum

const __mode_t = Cuint

const __off_t = Clong

const __socklen_t = Cuint

const mode_t = __mode_t

const off_t = __off_t

mutable struct __sigset_t
    __val::NTuple{16, Culong}
    __sigset_t() = new()
end

const sigset_t = __sigset_t

const socklen_t = __socklen_t

const __cpu_mask = Culong

mutable struct cpu_set_t
    __bits::NTuple{16, __cpu_mask}
    cpu_set_t() = new()
end

const __u8 = Cuchar

const __u16 = Cushort

const __s32 = Cint

const __u32 = Cuint

const __u64 = Culonglong

const __kernel_rwf_t = Cint

struct __kernel_timespec
    tv_sec::Int64
    tv_nsec::Clonglong
end

struct open_how
    flags::UInt64
    mode::UInt64
    resolve::UInt64
end

struct io_uring_sqe
    data::NTuple{64, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_sqe}, f::Symbol)
    f === :opcode && return Ptr{__u8}(x + 0)
    f === :flags && return Ptr{__u8}(x + 1)
    f === :ioprio && return Ptr{__u16}(x + 2)
    f === :fd && return Ptr{__s32}(x + 4)
    f === :off && return Ptr{__u64}(x + 8)
    f === :addr2 && return Ptr{__u64}(x + 8)
    f === :cmd_op && return Ptr{__u32}(x + 8)
    f === :__pad1 && return Ptr{__u32}(x + 12)
    f === :addr && return Ptr{__u64}(x + 16)
    f === :splice_off_in && return Ptr{__u64}(x + 16)
    f === :len && return Ptr{__u32}(x + 24)
    f === :rw_flags && return Ptr{__kernel_rwf_t}(x + 28)
    f === :fsync_flags && return Ptr{__u32}(x + 28)
    f === :poll_events && return Ptr{__u16}(x + 28)
    f === :poll32_events && return Ptr{__u32}(x + 28)
    f === :sync_range_flags && return Ptr{__u32}(x + 28)
    f === :msg_flags && return Ptr{__u32}(x + 28)
    f === :timeout_flags && return Ptr{__u32}(x + 28)
    f === :accept_flags && return Ptr{__u32}(x + 28)
    f === :cancel_flags && return Ptr{__u32}(x + 28)
    f === :open_flags && return Ptr{__u32}(x + 28)
    f === :statx_flags && return Ptr{__u32}(x + 28)
    f === :fadvise_advice && return Ptr{__u32}(x + 28)
    f === :splice_flags && return Ptr{__u32}(x + 28)
    f === :rename_flags && return Ptr{__u32}(x + 28)
    f === :unlink_flags && return Ptr{__u32}(x + 28)
    f === :hardlink_flags && return Ptr{__u32}(x + 28)
    f === :xattr_flags && return Ptr{__u32}(x + 28)
    f === :msg_ring_flags && return Ptr{__u32}(x + 28)
    f === :uring_cmd_flags && return Ptr{__u32}(x + 28)
    f === :user_data && return Ptr{__u64}(x + 32)
    f === :buf_index && return Ptr{__u16}(x + 40)
    f === :buf_group && return Ptr{__u16}(x + 40)
    f === :personality && return Ptr{__u16}(x + 42)
    f === :splice_fd_in && return Ptr{__s32}(x + 44)
    f === :file_index && return Ptr{__u32}(x + 44)
    f === :addr_len && return Ptr{__u16}(x + 44)
    f === :__pad3 && return Ptr{NTuple{1, __u16}}(x + 46)
    f === :addr3 && return Ptr{__u64}(x + 48)
    f === :__pad2 && return Ptr{NTuple{1, __u64}}(x + 56)
    f === :cmd && return Ptr{NTuple{0, __u8}}(x + 48)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_sqe, f::Symbol)
    r = Ref{io_uring_sqe}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_sqe}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_sqe}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

@cenum var"##Ctag#345"::UInt32 begin
    IOSQE_FIXED_FILE_BIT = 0
    IOSQE_IO_DRAIN_BIT = 1
    IOSQE_IO_LINK_BIT = 2
    IOSQE_IO_HARDLINK_BIT = 3
    IOSQE_ASYNC_BIT = 4
    IOSQE_BUFFER_SELECT_BIT = 5
    IOSQE_CQE_SKIP_SUCCESS_BIT = 6
end

@cenum io_uring_op::UInt32 begin
    IORING_OP_NOP = 0
    IORING_OP_READV = 1
    IORING_OP_WRITEV = 2
    IORING_OP_FSYNC = 3
    IORING_OP_READ_FIXED = 4
    IORING_OP_WRITE_FIXED = 5
    IORING_OP_POLL_ADD = 6
    IORING_OP_POLL_REMOVE = 7
    IORING_OP_SYNC_FILE_RANGE = 8
    IORING_OP_SENDMSG = 9
    IORING_OP_RECVMSG = 10
    IORING_OP_TIMEOUT = 11
    IORING_OP_TIMEOUT_REMOVE = 12
    IORING_OP_ACCEPT = 13
    IORING_OP_ASYNC_CANCEL = 14
    IORING_OP_LINK_TIMEOUT = 15
    IORING_OP_CONNECT = 16
    IORING_OP_FALLOCATE = 17
    IORING_OP_OPENAT = 18
    IORING_OP_CLOSE = 19
    IORING_OP_FILES_UPDATE = 20
    IORING_OP_STATX = 21
    IORING_OP_READ = 22
    IORING_OP_WRITE = 23
    IORING_OP_FADVISE = 24
    IORING_OP_MADVISE = 25
    IORING_OP_SEND = 26
    IORING_OP_RECV = 27
    IORING_OP_OPENAT2 = 28
    IORING_OP_EPOLL_CTL = 29
    IORING_OP_SPLICE = 30
    IORING_OP_PROVIDE_BUFFERS = 31
    IORING_OP_REMOVE_BUFFERS = 32
    IORING_OP_TEE = 33
    IORING_OP_SHUTDOWN = 34
    IORING_OP_RENAMEAT = 35
    IORING_OP_UNLINKAT = 36
    IORING_OP_MKDIRAT = 37
    IORING_OP_SYMLINKAT = 38
    IORING_OP_LINKAT = 39
    IORING_OP_MSG_RING = 40
    IORING_OP_FSETXATTR = 41
    IORING_OP_SETXATTR = 42
    IORING_OP_FGETXATTR = 43
    IORING_OP_GETXATTR = 44
    IORING_OP_SOCKET = 45
    IORING_OP_URING_CMD = 46
    IORING_OP_SEND_ZC = 47
    IORING_OP_SENDMSG_ZC = 48
    IORING_OP_LAST = 49
end

@cenum var"##Ctag#346"::UInt32 begin
    IORING_MSG_DATA = 0
    IORING_MSG_SEND_FD = 1
end

struct io_uring_cqe
    user_data::__u64
    res::__s32
    flags::__u32
    big_cqe::Ptr{__u64}
end

@cenum var"##Ctag#347"::UInt32 begin
    IORING_CQE_BUFFER_SHIFT = 16
end

struct io_sqring_offsets
    head::__u32
    tail::__u32
    ring_mask::__u32
    ring_entries::__u32
    flags::__u32
    dropped::__u32
    array::__u32
    resv1::__u32
    resv2::__u64
end

struct io_cqring_offsets
    head::__u32
    tail::__u32
    ring_mask::__u32
    ring_entries::__u32
    overflow::__u32
    cqes::__u32
    flags::__u32
    resv1::__u32
    resv2::__u64
end

struct io_uring_params
    sq_entries::__u32
    cq_entries::__u32
    flags::__u32
    sq_thread_cpu::__u32
    sq_thread_idle::__u32
    features::__u32
    wq_fd::__u32
    resv::NTuple{3, __u32}
    sq_off::io_sqring_offsets
    cq_off::io_cqring_offsets
end

@cenum var"##Ctag#348"::UInt32 begin
    IORING_REGISTER_BUFFERS = 0
    IORING_UNREGISTER_BUFFERS = 1
    IORING_REGISTER_FILES = 2
    IORING_UNREGISTER_FILES = 3
    IORING_REGISTER_EVENTFD = 4
    IORING_UNREGISTER_EVENTFD = 5
    IORING_REGISTER_FILES_UPDATE = 6
    IORING_REGISTER_EVENTFD_ASYNC = 7
    IORING_REGISTER_PROBE = 8
    IORING_REGISTER_PERSONALITY = 9
    IORING_UNREGISTER_PERSONALITY = 10
    IORING_REGISTER_RESTRICTIONS = 11
    IORING_REGISTER_ENABLE_RINGS = 12
    IORING_REGISTER_FILES2 = 13
    IORING_REGISTER_FILES_UPDATE2 = 14
    IORING_REGISTER_BUFFERS2 = 15
    IORING_REGISTER_BUFFERS_UPDATE = 16
    IORING_REGISTER_IOWQ_AFF = 17
    IORING_UNREGISTER_IOWQ_AFF = 18
    IORING_REGISTER_IOWQ_MAX_WORKERS = 19
    IORING_REGISTER_RING_FDS = 20
    IORING_UNREGISTER_RING_FDS = 21
    IORING_REGISTER_PBUF_RING = 22
    IORING_UNREGISTER_PBUF_RING = 23
    IORING_REGISTER_SYNC_CANCEL = 24
    IORING_REGISTER_FILE_ALLOC_RANGE = 25
    IORING_REGISTER_LAST = 26
end

@cenum var"##Ctag#349"::UInt32 begin
    IO_WQ_BOUND = 0
    IO_WQ_UNBOUND = 1
end

struct io_uring_files_update
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_files_update}, f::Symbol)
    f === :offset && return Ptr{__u32}(x + 0)
    f === :resv && return Ptr{__u32}(x + 4)
    f === :fds && return Ptr{__u64}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_files_update, f::Symbol)
    r = Ref{io_uring_files_update}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_files_update}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_files_update}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct io_uring_rsrc_register
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_rsrc_register}, f::Symbol)
    f === :nr && return Ptr{__u32}(x + 0)
    f === :flags && return Ptr{__u32}(x + 4)
    f === :resv2 && return Ptr{__u64}(x + 8)
    f === :data && return Ptr{__u64}(x + 16)
    f === :tags && return Ptr{__u64}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_rsrc_register, f::Symbol)
    r = Ref{io_uring_rsrc_register}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_rsrc_register}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_rsrc_register}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct io_uring_rsrc_update
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_rsrc_update}, f::Symbol)
    f === :offset && return Ptr{__u32}(x + 0)
    f === :resv && return Ptr{__u32}(x + 4)
    f === :data && return Ptr{__u64}(x + 8)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_rsrc_update, f::Symbol)
    r = Ref{io_uring_rsrc_update}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_rsrc_update}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_rsrc_update}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct io_uring_rsrc_update2
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_rsrc_update2}, f::Symbol)
    f === :offset && return Ptr{__u32}(x + 0)
    f === :resv && return Ptr{__u32}(x + 4)
    f === :data && return Ptr{__u64}(x + 8)
    f === :tags && return Ptr{__u64}(x + 16)
    f === :nr && return Ptr{__u32}(x + 24)
    f === :resv2 && return Ptr{__u32}(x + 28)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_rsrc_update2, f::Symbol)
    r = Ref{io_uring_rsrc_update2}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_rsrc_update2}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_rsrc_update2}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

mutable struct io_uring_notification_slot
    tag::__u64
    resv::NTuple{3, __u64}
    io_uring_notification_slot() = new()
end

mutable struct io_uring_notification_register
    nr_slots::__u32
    resv::__u32
    resv2::__u64
    data::__u64
    resv3::__u64
    io_uring_notification_register() = new()
end

struct io_uring_probe_op
    op::__u8
    resv::__u8
    flags::__u16
    resv2::__u32
end

struct io_uring_probe
    last_op::__u8
    ops_len::__u8
    resv::__u16
    resv2::NTuple{3, __u32}
    ops::Ptr{io_uring_probe_op}
end

struct io_uring_restriction
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_restriction}, f::Symbol)
    f === :opcode && return Ptr{__u16}(x + 0)
    f === :register_op && return Ptr{__u8}(x + 2)
    f === :sqe_op && return Ptr{__u8}(x + 2)
    f === :sqe_flags && return Ptr{__u8}(x + 2)
    f === :resv && return Ptr{__u8}(x + 3)
    f === :resv2 && return Ptr{NTuple{3, __u32}}(x + 4)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_restriction, f::Symbol)
    r = Ref{io_uring_restriction}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_restriction}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_restriction}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

mutable struct io_uring_buf
    addr::__u64
    len::__u32
    bid::__u16
    resv::__u16
    io_uring_buf() = new()
end

struct io_uring_buf_ring
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{io_uring_buf_ring}, f::Symbol)
    f === :resv1 && return Ptr{__u64}(x + 0)
    f === :resv2 && return Ptr{__u32}(x + 8)
    f === :resv3 && return Ptr{__u16}(x + 12)
    f === :tail && return Ptr{__u16}(x + 14)
    f === :bufs && return Ptr{NTuple{0, io_uring_buf}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::io_uring_buf_ring, f::Symbol)
    r = Ref{io_uring_buf_ring}(x)
    ptr = Base.unsafe_convert(Ptr{io_uring_buf_ring}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{io_uring_buf_ring}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct io_uring_buf_reg
    ring_addr::__u64
    ring_entries::__u32
    bgid::__u16
    pad::__u16
    resv::NTuple{3, __u64}
end

@cenum var"##Ctag#350"::UInt32 begin
    IORING_RESTRICTION_REGISTER_OP = 0
    IORING_RESTRICTION_SQE_OP = 1
    IORING_RESTRICTION_SQE_FLAGS_ALLOWED = 2
    IORING_RESTRICTION_SQE_FLAGS_REQUIRED = 3
    IORING_RESTRICTION_LAST = 4
end

mutable struct io_uring_getevents_arg
    sigmask::__u64
    sigmask_sz::__u32
    pad::__u32
    ts::__u64
    io_uring_getevents_arg() = new()
end

mutable struct io_uring_sync_cancel_reg
    addr::__u64
    fd::__s32
    flags::__u32
    timeout::__kernel_timespec
    pad::NTuple{4, __u64}
    io_uring_sync_cancel_reg() = new()
end

mutable struct io_uring_file_index_range
    off::__u32
    len::__u32
    resv::__u64
    io_uring_file_index_range() = new()
end

struct io_uring_recvmsg_out
    namelen::__u32
    controllen::__u32
    payloadlen::__u32
    flags::__u32
end

struct io_uring_sq
    khead::Ptr{Cuint}
    ktail::Ptr{Cuint}
    kring_mask::Ptr{Cuint}
    kring_entries::Ptr{Cuint}
    kflags::Ptr{Cuint}
    kdropped::Ptr{Cuint}
    array::Ptr{Cuint}
    sqes::Ptr{io_uring_sqe}
    sqe_head::Cuint
    sqe_tail::Cuint
    ring_sz::Csize_t
    ring_ptr::Ptr{Cvoid}
    ring_mask::Cuint
    ring_entries::Cuint
    pad::NTuple{2, Cuint}
end

struct io_uring_cq
    khead::Ptr{Cuint}
    ktail::Ptr{Cuint}
    kring_mask::Ptr{Cuint}
    kring_entries::Ptr{Cuint}
    kflags::Ptr{Cuint}
    koverflow::Ptr{Cuint}
    cqes::Ptr{io_uring_cqe}
    ring_sz::Csize_t
    ring_ptr::Ptr{Cvoid}
    ring_mask::Cuint
    ring_entries::Cuint
    pad::NTuple{2, Cuint}
end

struct io_uring
    sq::io_uring_sq
    cq::io_uring_cq
    flags::Cuint
    ring_fd::Cint
    features::Cuint
    enter_ring_fd::Cint
    int_flags::__u8
    pad::NTuple{3, __u8}
    pad2::Cuint
end

function io_uring_get_probe_ring(ring)
    @ccall liburing.io_uring_get_probe_ring(ring::Ptr{io_uring})::Ptr{io_uring_probe}
end

function io_uring_get_probe()
    @ccall liburing.io_uring_get_probe()::Ptr{io_uring_probe}
end

function io_uring_free_probe(probe)
    @ccall liburing.io_uring_free_probe(probe::Ptr{io_uring_probe})::Cvoid
end

function io_uring_opcode_supported(p, op)
    @ccall liburing.io_uring_opcode_supported(p::Ptr{io_uring_probe}, op::Cint)::Cint
end

function io_uring_queue_init_params(entries, ring, p)
    @ccall liburing.io_uring_queue_init_params(entries::Cuint, ring::Ptr{io_uring}, p::Ptr{io_uring_params})::Cint
end

function io_uring_queue_init(entries, ring, flags)
    @ccall liburing.io_uring_queue_init(entries::Cuint, ring::Ptr{io_uring}, flags::Cuint)::Cint
end

function io_uring_queue_mmap(fd, p, ring)
    @ccall liburing.io_uring_queue_mmap(fd::Cint, p::Ptr{io_uring_params}, ring::Ptr{io_uring})::Cint
end

function io_uring_ring_dontfork(ring)
    @ccall liburing.io_uring_ring_dontfork(ring::Ptr{io_uring})::Cint
end

function io_uring_queue_exit(ring)
    @ccall liburing.io_uring_queue_exit(ring::Ptr{io_uring})::Cvoid
end

function io_uring_peek_batch_cqe(ring, cqes, count)
    @ccall liburing.io_uring_peek_batch_cqe(ring::Ptr{io_uring}, cqes::Ptr{Ptr{io_uring_cqe}}, count::Cuint)::Cuint
end

function io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts, sigmask)
    @ccall liburing.io_uring_wait_cqes(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}}, wait_nr::Cuint, ts::Ptr{__kernel_timespec}, sigmask::Ptr{sigset_t})::Cint
end

function io_uring_wait_cqe_timeout(ring, cqe_ptr, ts)
    @ccall liburing.io_uring_wait_cqe_timeout(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}}, ts::Ptr{__kernel_timespec})::Cint
end

function io_uring_submit(ring)
    @ccall liburing.io_uring_submit(ring::Ptr{io_uring})::Cint
end

function io_uring_submit_and_wait(ring, wait_nr)
    @ccall liburing.io_uring_submit_and_wait(ring::Ptr{io_uring}, wait_nr::Cuint)::Cint
end

function io_uring_submit_and_wait_timeout(ring, cqe_ptr, wait_nr, ts, sigmask)
    @ccall liburing.io_uring_submit_and_wait_timeout(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}}, wait_nr::Cuint, ts::Ptr{__kernel_timespec}, sigmask::Ptr{sigset_t})::Cint
end

function io_uring_register_buffers(ring, iovecs, nr_iovecs)
    @ccall liburing.io_uring_register_buffers(ring::Ptr{io_uring}, iovecs::Ptr{Cvoid}, nr_iovecs::Cuint)::Cint
end

function io_uring_register_buffers_tags(ring, iovecs, tags, nr)
    @ccall liburing.io_uring_register_buffers_tags(ring::Ptr{io_uring}, iovecs::Ptr{Cvoid}, tags::Ptr{__u64}, nr::Cuint)::Cint
end

function io_uring_register_buffers_sparse(ring, nr)
    @ccall liburing.io_uring_register_buffers_sparse(ring::Ptr{io_uring}, nr::Cuint)::Cint
end

function io_uring_register_buffers_update_tag(ring, off, iovecs, tags, nr)
    @ccall liburing.io_uring_register_buffers_update_tag(ring::Ptr{io_uring}, off::Cuint, iovecs::Ptr{Cvoid}, tags::Ptr{__u64}, nr::Cuint)::Cint
end

function io_uring_unregister_buffers(ring)
    @ccall liburing.io_uring_unregister_buffers(ring::Ptr{io_uring})::Cint
end

function io_uring_register_files(ring, files, nr_files)
    @ccall liburing.io_uring_register_files(ring::Ptr{io_uring}, files::Ptr{Cint}, nr_files::Cuint)::Cint
end

function io_uring_register_files_tags(ring, files, tags, nr)
    @ccall liburing.io_uring_register_files_tags(ring::Ptr{io_uring}, files::Ptr{Cint}, tags::Ptr{__u64}, nr::Cuint)::Cint
end

function io_uring_register_files_sparse(ring, nr)
    @ccall liburing.io_uring_register_files_sparse(ring::Ptr{io_uring}, nr::Cuint)::Cint
end

function io_uring_register_files_update_tag(ring, off, files, tags, nr_files)
    @ccall liburing.io_uring_register_files_update_tag(ring::Ptr{io_uring}, off::Cuint, files::Ptr{Cint}, tags::Ptr{__u64}, nr_files::Cuint)::Cint
end

function io_uring_unregister_files(ring)
    @ccall liburing.io_uring_unregister_files(ring::Ptr{io_uring})::Cint
end

function io_uring_register_files_update(ring, off, files, nr_files)
    @ccall liburing.io_uring_register_files_update(ring::Ptr{io_uring}, off::Cuint, files::Ptr{Cint}, nr_files::Cuint)::Cint
end

function io_uring_register_eventfd(ring, fd)
    @ccall liburing.io_uring_register_eventfd(ring::Ptr{io_uring}, fd::Cint)::Cint
end

function io_uring_register_eventfd_async(ring, fd)
    @ccall liburing.io_uring_register_eventfd_async(ring::Ptr{io_uring}, fd::Cint)::Cint
end

function io_uring_unregister_eventfd(ring)
    @ccall liburing.io_uring_unregister_eventfd(ring::Ptr{io_uring})::Cint
end

function io_uring_register_probe(ring, p, nr)
    @ccall liburing.io_uring_register_probe(ring::Ptr{io_uring}, p::Ptr{io_uring_probe}, nr::Cuint)::Cint
end

function io_uring_register_personality(ring)
    @ccall liburing.io_uring_register_personality(ring::Ptr{io_uring})::Cint
end

function io_uring_unregister_personality(ring, id)
    @ccall liburing.io_uring_unregister_personality(ring::Ptr{io_uring}, id::Cint)::Cint
end

function io_uring_register_restrictions(ring, res, nr_res)
    @ccall liburing.io_uring_register_restrictions(ring::Ptr{io_uring}, res::Ptr{io_uring_restriction}, nr_res::Cuint)::Cint
end

function io_uring_enable_rings(ring)
    @ccall liburing.io_uring_enable_rings(ring::Ptr{io_uring})::Cint
end

function __io_uring_sqring_wait(ring)
    @ccall liburing.__io_uring_sqring_wait(ring::Ptr{io_uring})::Cint
end

function io_uring_register_iowq_aff(ring, cpusz, mask)
    @ccall liburing.io_uring_register_iowq_aff(ring::Ptr{io_uring}, cpusz::Csize_t, mask::Ptr{cpu_set_t})::Cint
end

function io_uring_unregister_iowq_aff(ring)
    @ccall liburing.io_uring_unregister_iowq_aff(ring::Ptr{io_uring})::Cint
end

function io_uring_register_iowq_max_workers(ring, values)
    @ccall liburing.io_uring_register_iowq_max_workers(ring::Ptr{io_uring}, values::Ptr{Cuint})::Cint
end

function io_uring_register_ring_fd(ring)
    @ccall liburing.io_uring_register_ring_fd(ring::Ptr{io_uring})::Cint
end

function io_uring_unregister_ring_fd(ring)
    @ccall liburing.io_uring_unregister_ring_fd(ring::Ptr{io_uring})::Cint
end

function io_uring_register_buf_ring(ring, reg, flags)
    @ccall liburing.io_uring_register_buf_ring(ring::Ptr{io_uring}, reg::Ptr{io_uring_buf_reg}, flags::Cuint)::Cint
end

function io_uring_unregister_buf_ring(ring, bgid)
    @ccall liburing.io_uring_unregister_buf_ring(ring::Ptr{io_uring}, bgid::Cint)::Cint
end

function io_uring_register_sync_cancel(ring, reg)
    @ccall liburing.io_uring_register_sync_cancel(ring::Ptr{io_uring}, reg::Ptr{io_uring_sync_cancel_reg})::Cint
end

function io_uring_register_file_alloc_range(ring, off, len)
    @ccall liburing.io_uring_register_file_alloc_range(ring::Ptr{io_uring}, off::Cuint, len::Cuint)::Cint
end

function io_uring_get_events(ring)
    @ccall liburing.io_uring_get_events(ring::Ptr{io_uring})::Cint
end

function io_uring_submit_and_get_events(ring)
    @ccall liburing.io_uring_submit_and_get_events(ring::Ptr{io_uring})::Cint
end

function io_uring_enter(fd, to_submit, min_complete, flags, sig)
    @ccall liburing.io_uring_enter(fd::Cuint, to_submit::Cuint, min_complete::Cuint, flags::Cuint, sig::Ptr{sigset_t})::Cint
end

function io_uring_enter2(fd, to_submit, min_complete, flags, sig, sz)
    @ccall liburing.io_uring_enter2(fd::Cuint, to_submit::Cuint, min_complete::Cuint, flags::Cuint, sig::Ptr{sigset_t}, sz::Csize_t)::Cint
end

function io_uring_setup(entries, p)
    @ccall liburing.io_uring_setup(entries::Cuint, p::Ptr{io_uring_params})::Cint
end

function io_uring_register(fd, opcode, arg, nr_args)
    @ccall liburing.io_uring_register(fd::Cuint, opcode::Cuint, arg::Ptr{Cvoid}, nr_args::Cuint)::Cint
end

function __io_uring_get_cqe(ring, cqe_ptr, submit, wait_nr, sigmask)
    @ccall liburing.__io_uring_get_cqe(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}}, submit::Cuint, wait_nr::Cuint, sigmask::Ptr{sigset_t})::Cint
end

function io_uring_cq_advance(ring, nr)
    @ccall liburing.io_uring_cq_advance(ring::Ptr{io_uring}, nr::Cuint)::Cvoid
end

function io_uring_cqe_seen(ring, cqe)
    @ccall liburing.io_uring_cqe_seen(ring::Ptr{io_uring}, cqe::Ptr{io_uring_cqe})::Cvoid
end

function io_uring_sqe_set_data(sqe, data)
    @ccall liburing.io_uring_sqe_set_data(sqe::Ptr{io_uring_sqe}, data::Ptr{Cvoid})::Cvoid
end

function io_uring_cqe_get_data(cqe)
    @ccall liburing.io_uring_cqe_get_data(cqe::Ptr{io_uring_cqe})::Ptr{Cvoid}
end

function io_uring_sqe_set_data64(sqe, data)
    @ccall liburing.io_uring_sqe_set_data64(sqe::Ptr{io_uring_sqe}, data::__u64)::Cvoid
end

function io_uring_cqe_get_data64(cqe)
    @ccall liburing.io_uring_cqe_get_data64(cqe::Ptr{io_uring_cqe})::__u64
end

function io_uring_sqe_set_flags(sqe, flags)
    @ccall liburing.io_uring_sqe_set_flags(sqe::Ptr{io_uring_sqe}, flags::Cuint)::Cvoid
end

function __io_uring_set_target_fixed_file(sqe, file_index)
    @ccall liburing.__io_uring_set_target_fixed_file(sqe::Ptr{io_uring_sqe}, file_index::Cuint)::Cvoid
end

function io_uring_prep_rw(op, sqe, fd, addr, len, offset)
    @ccall liburing.io_uring_prep_rw(op::Cint, sqe::Ptr{io_uring_sqe}, fd::Cint, addr::Ptr{Cvoid}, len::Cuint, offset::__u64)::Cvoid
end

"""
    io_uring_prep_splice(sqe, fd_in, off_in, fd_out, off_out, nbytes, splice_flags)

@pre Either fd_in or fd_out must be a pipe.
@param off_in If fd_in refers to a pipe, off_in must be (int64_t) -1;
	 If fd_in does not refer to a pipe and off_in is (int64_t) -1,
	 then bytes are read from fd_in starting from the file offset
	 and it is adjust appropriately;
              If fd_in does not refer to a pipe and off_in is not
	 (int64_t) -1, then the  starting offset of fd_in will be
	 off_in.
@param off_out The description of off_in also applied to off_out.
@param splice_flags see man splice(2) for description of flags.

This splice operation can be used to implement sendfile by splicing to an
intermediate pipe first, then splice to the final destination.
In fact, the implementation of sendfile in kernel uses splice internally.

NOTE that even if fd_in or fd_out refers to a pipe, the splice operation
can still failed with EINVAL if one of the fd doesn't explicitly support
splice operation, e.g. reading from terminal is unsupported from kernel 5.7
to 5.11.
Check issue #291 for more information.
"""
function io_uring_prep_splice(sqe, fd_in, off_in, fd_out, off_out, nbytes, splice_flags)
    @ccall liburing.io_uring_prep_splice(sqe::Ptr{io_uring_sqe}, fd_in::Cint, off_in::Int64, fd_out::Cint, off_out::Int64, nbytes::Cuint, splice_flags::Cuint)::Cvoid
end

function io_uring_prep_tee(sqe, fd_in, fd_out, nbytes, splice_flags)
    @ccall liburing.io_uring_prep_tee(sqe::Ptr{io_uring_sqe}, fd_in::Cint, fd_out::Cint, nbytes::Cuint, splice_flags::Cuint)::Cvoid
end

function io_uring_prep_readv(sqe, fd, iovecs, nr_vecs, offset)
    @ccall liburing.io_uring_prep_readv(sqe::Ptr{io_uring_sqe}, fd::Cint, iovecs::Ptr{Cvoid}, nr_vecs::Cuint, offset::__u64)::Cvoid
end

function io_uring_prep_readv2(sqe, fd, iovecs, nr_vecs, offset, flags)
    @ccall liburing.io_uring_prep_readv2(sqe::Ptr{io_uring_sqe}, fd::Cint, iovecs::Ptr{Cvoid}, nr_vecs::Cuint, offset::__u64, flags::Cint)::Cvoid
end

function io_uring_prep_read_fixed(sqe, fd, buf, nbytes, offset, buf_index)
    @ccall liburing.io_uring_prep_read_fixed(sqe::Ptr{io_uring_sqe}, fd::Cint, buf::Ptr{Cvoid}, nbytes::Cuint, offset::__u64, buf_index::Cint)::Cvoid
end

function io_uring_prep_writev(sqe, fd, iovecs, nr_vecs, offset)
    @ccall liburing.io_uring_prep_writev(sqe::Ptr{io_uring_sqe}, fd::Cint, iovecs::Ptr{Cvoid}, nr_vecs::Cuint, offset::__u64)::Cvoid
end

function io_uring_prep_writev2(sqe, fd, iovecs, nr_vecs, offset, flags)
    @ccall liburing.io_uring_prep_writev2(sqe::Ptr{io_uring_sqe}, fd::Cint, iovecs::Ptr{Cvoid}, nr_vecs::Cuint, offset::__u64, flags::Cint)::Cvoid
end

function io_uring_prep_write_fixed(sqe, fd, buf, nbytes, offset, buf_index)
    @ccall liburing.io_uring_prep_write_fixed(sqe::Ptr{io_uring_sqe}, fd::Cint, buf::Ptr{Cvoid}, nbytes::Cuint, offset::__u64, buf_index::Cint)::Cvoid
end

function io_uring_prep_recvmsg(sqe, fd, msg, flags)
    @ccall liburing.io_uring_prep_recvmsg(sqe::Ptr{io_uring_sqe}, fd::Cint, msg::Ptr{Cvoid}, flags::Cuint)::Cvoid
end

function io_uring_prep_recvmsg_multishot(sqe, fd, msg, flags)
    @ccall liburing.io_uring_prep_recvmsg_multishot(sqe::Ptr{io_uring_sqe}, fd::Cint, msg::Ptr{Cvoid}, flags::Cuint)::Cvoid
end

function io_uring_prep_sendmsg(sqe, fd, msg, flags)
    @ccall liburing.io_uring_prep_sendmsg(sqe::Ptr{io_uring_sqe}, fd::Cint, msg::Ptr{Cvoid}, flags::Cuint)::Cvoid
end

function __io_uring_prep_poll_mask(poll_mask)
    @ccall liburing.__io_uring_prep_poll_mask(poll_mask::Cuint)::Cuint
end

function io_uring_prep_poll_add(sqe, fd, poll_mask)
    @ccall liburing.io_uring_prep_poll_add(sqe::Ptr{io_uring_sqe}, fd::Cint, poll_mask::Cuint)::Cvoid
end

function io_uring_prep_poll_multishot(sqe, fd, poll_mask)
    @ccall liburing.io_uring_prep_poll_multishot(sqe::Ptr{io_uring_sqe}, fd::Cint, poll_mask::Cuint)::Cvoid
end

function io_uring_prep_poll_remove(sqe, user_data)
    @ccall liburing.io_uring_prep_poll_remove(sqe::Ptr{io_uring_sqe}, user_data::__u64)::Cvoid
end

function io_uring_prep_poll_update(sqe, old_user_data, new_user_data, poll_mask, flags)
    @ccall liburing.io_uring_prep_poll_update(sqe::Ptr{io_uring_sqe}, old_user_data::__u64, new_user_data::__u64, poll_mask::Cuint, flags::Cuint)::Cvoid
end

function io_uring_prep_fsync(sqe, fd, fsync_flags)
    @ccall liburing.io_uring_prep_fsync(sqe::Ptr{io_uring_sqe}, fd::Cint, fsync_flags::Cuint)::Cvoid
end

function io_uring_prep_nop(sqe)
    @ccall liburing.io_uring_prep_nop(sqe::Ptr{io_uring_sqe})::Cvoid
end

function io_uring_prep_timeout(sqe, ts, count, flags)
    @ccall liburing.io_uring_prep_timeout(sqe::Ptr{io_uring_sqe}, ts::Ptr{__kernel_timespec}, count::Cuint, flags::Cuint)::Cvoid
end

function io_uring_prep_timeout_remove(sqe, user_data, flags)
    @ccall liburing.io_uring_prep_timeout_remove(sqe::Ptr{io_uring_sqe}, user_data::__u64, flags::Cuint)::Cvoid
end

function io_uring_prep_timeout_update(sqe, ts, user_data, flags)
    @ccall liburing.io_uring_prep_timeout_update(sqe::Ptr{io_uring_sqe}, ts::Ptr{__kernel_timespec}, user_data::__u64, flags::Cuint)::Cvoid
end

function io_uring_prep_accept(sqe, fd, addr, addrlen, flags)
    @ccall liburing.io_uring_prep_accept(sqe::Ptr{io_uring_sqe}, fd::Cint, addr::Ptr{Cvoid}, addrlen::Ptr{socklen_t}, flags::Cint)::Cvoid
end

function io_uring_prep_accept_direct(sqe, fd, addr, addrlen, flags, file_index)
    @ccall liburing.io_uring_prep_accept_direct(sqe::Ptr{io_uring_sqe}, fd::Cint, addr::Ptr{Cvoid}, addrlen::Ptr{socklen_t}, flags::Cint, file_index::Cuint)::Cvoid
end

function io_uring_prep_multishot_accept(sqe, fd, addr, addrlen, flags)
    @ccall liburing.io_uring_prep_multishot_accept(sqe::Ptr{io_uring_sqe}, fd::Cint, addr::Ptr{Cvoid}, addrlen::Ptr{socklen_t}, flags::Cint)::Cvoid
end

function io_uring_prep_multishot_accept_direct(sqe, fd, addr, addrlen, flags)
    @ccall liburing.io_uring_prep_multishot_accept_direct(sqe::Ptr{io_uring_sqe}, fd::Cint, addr::Ptr{Cvoid}, addrlen::Ptr{socklen_t}, flags::Cint)::Cvoid
end

function io_uring_prep_cancel64(sqe, user_data, flags)
    @ccall liburing.io_uring_prep_cancel64(sqe::Ptr{io_uring_sqe}, user_data::__u64, flags::Cint)::Cvoid
end

function io_uring_prep_cancel(sqe, user_data, flags)
    @ccall liburing.io_uring_prep_cancel(sqe::Ptr{io_uring_sqe}, user_data::Ptr{Cvoid}, flags::Cint)::Cvoid
end

function io_uring_prep_cancel_fd(sqe, fd, flags)
    @ccall liburing.io_uring_prep_cancel_fd(sqe::Ptr{io_uring_sqe}, fd::Cint, flags::Cuint)::Cvoid
end

function io_uring_prep_link_timeout(sqe, ts, flags)
    @ccall liburing.io_uring_prep_link_timeout(sqe::Ptr{io_uring_sqe}, ts::Ptr{__kernel_timespec}, flags::Cuint)::Cvoid
end

function io_uring_prep_connect(sqe, fd, addr, addrlen)
    @ccall liburing.io_uring_prep_connect(sqe::Ptr{io_uring_sqe}, fd::Cint, addr::Ptr{Cvoid}, addrlen::socklen_t)::Cvoid
end

function io_uring_prep_files_update(sqe, fds, nr_fds, offset)
    @ccall liburing.io_uring_prep_files_update(sqe::Ptr{io_uring_sqe}, fds::Ptr{Cint}, nr_fds::Cuint, offset::Cint)::Cvoid
end

function io_uring_prep_fallocate(sqe, fd, mode, offset, len)
    @ccall liburing.io_uring_prep_fallocate(sqe::Ptr{io_uring_sqe}, fd::Cint, mode::Cint, offset::off_t, len::off_t)::Cvoid
end

function io_uring_prep_openat(sqe, dfd, path, flags, mode)
    @ccall liburing.io_uring_prep_openat(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, flags::Cint, mode::mode_t)::Cvoid
end

function io_uring_prep_openat_direct(sqe, dfd, path, flags, mode, file_index)
    @ccall liburing.io_uring_prep_openat_direct(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, flags::Cint, mode::mode_t, file_index::Cuint)::Cvoid
end

function io_uring_prep_close(sqe, fd)
    @ccall liburing.io_uring_prep_close(sqe::Ptr{io_uring_sqe}, fd::Cint)::Cvoid
end

function io_uring_prep_close_direct(sqe, file_index)
    @ccall liburing.io_uring_prep_close_direct(sqe::Ptr{io_uring_sqe}, file_index::Cuint)::Cvoid
end

function io_uring_prep_read(sqe, fd, buf, nbytes, offset)
    @ccall liburing.io_uring_prep_read(sqe::Ptr{io_uring_sqe}, fd::Cint, buf::Ptr{Cvoid}, nbytes::Cuint, offset::__u64)::Cvoid
end

function io_uring_prep_write(sqe, fd, buf, nbytes, offset)
    @ccall liburing.io_uring_prep_write(sqe::Ptr{io_uring_sqe}, fd::Cint, buf::Ptr{Cvoid}, nbytes::Cuint, offset::__u64)::Cvoid
end

mutable struct statx end

function io_uring_prep_statx(sqe, dfd, path, flags, mask, statxbuf)
    @ccall liburing.io_uring_prep_statx(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, flags::Cint, mask::Cuint, statxbuf::Ptr{statx})::Cvoid
end

function io_uring_prep_fadvise(sqe, fd, offset, len, advice)
    @ccall liburing.io_uring_prep_fadvise(sqe::Ptr{io_uring_sqe}, fd::Cint, offset::__u64, len::off_t, advice::Cint)::Cvoid
end

function io_uring_prep_madvise(sqe, addr, length, advice)
    @ccall liburing.io_uring_prep_madvise(sqe::Ptr{io_uring_sqe}, addr::Ptr{Cvoid}, length::off_t, advice::Cint)::Cvoid
end

function io_uring_prep_send(sqe, sockfd, buf, len, flags)
    @ccall liburing.io_uring_prep_send(sqe::Ptr{io_uring_sqe}, sockfd::Cint, buf::Ptr{Cvoid}, len::Csize_t, flags::Cint)::Cvoid
end

function io_uring_prep_send_zc(sqe, sockfd, buf, len, flags, zc_flags)
    @ccall liburing.io_uring_prep_send_zc(sqe::Ptr{io_uring_sqe}, sockfd::Cint, buf::Ptr{Cvoid}, len::Csize_t, flags::Cint, zc_flags::Cuint)::Cvoid
end

function io_uring_prep_send_zc_fixed(sqe, sockfd, buf, len, flags, zc_flags, buf_index)
    @ccall liburing.io_uring_prep_send_zc_fixed(sqe::Ptr{io_uring_sqe}, sockfd::Cint, buf::Ptr{Cvoid}, len::Csize_t, flags::Cint, zc_flags::Cuint, buf_index::Cuint)::Cvoid
end

function io_uring_prep_sendmsg_zc(sqe, fd, msg, flags)
    @ccall liburing.io_uring_prep_sendmsg_zc(sqe::Ptr{io_uring_sqe}, fd::Cint, msg::Ptr{Cvoid}, flags::Cuint)::Cvoid
end

function io_uring_prep_send_set_addr(sqe, dest_addr, addr_len)
    @ccall liburing.io_uring_prep_send_set_addr(sqe::Ptr{io_uring_sqe}, dest_addr::Ptr{Cvoid}, addr_len::__u16)::Cvoid
end

function io_uring_prep_recv(sqe, sockfd, buf, len, flags)
    @ccall liburing.io_uring_prep_recv(sqe::Ptr{io_uring_sqe}, sockfd::Cint, buf::Ptr{Cvoid}, len::Csize_t, flags::Cint)::Cvoid
end

function io_uring_prep_recv_multishot(sqe, sockfd, buf, len, flags)
    @ccall liburing.io_uring_prep_recv_multishot(sqe::Ptr{io_uring_sqe}, sockfd::Cint, buf::Ptr{Cvoid}, len::Csize_t, flags::Cint)::Cvoid
end

function io_uring_recvmsg_validate(buf, buf_len, msgh)
    @ccall liburing.io_uring_recvmsg_validate(buf::Ptr{Cvoid}, buf_len::Cint, msgh::Ptr{Cvoid})::Ptr{io_uring_recvmsg_out}
end

function io_uring_recvmsg_name(o)
    @ccall liburing.io_uring_recvmsg_name(o::Ptr{io_uring_recvmsg_out})::Ptr{Cvoid}
end

function io_uring_recvmsg_cmsg_firsthdr(o, msgh)
    @ccall liburing.io_uring_recvmsg_cmsg_firsthdr(o::Ptr{io_uring_recvmsg_out}, msgh::Ptr{Cvoid})::Ptr{Cvoid}
end

function io_uring_recvmsg_cmsg_nexthdr(o, msgh, cmsg)
    @ccall liburing.io_uring_recvmsg_cmsg_nexthdr(o::Ptr{io_uring_recvmsg_out}, msgh::Ptr{Cvoid}, cmsg::Ptr{Cvoid})::Ptr{Cvoid}
end

function io_uring_recvmsg_payload(o, msgh)
    @ccall liburing.io_uring_recvmsg_payload(o::Ptr{io_uring_recvmsg_out}, msgh::Ptr{Cvoid})::Ptr{Cvoid}
end

function io_uring_recvmsg_payload_length(o, buf_len, msgh)
    @ccall liburing.io_uring_recvmsg_payload_length(o::Ptr{io_uring_recvmsg_out}, buf_len::Cint, msgh::Ptr{Cvoid})::Cuint
end

function io_uring_prep_openat2(sqe, dfd, path, how)
    @ccall liburing.io_uring_prep_openat2(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, how::Ptr{open_how})::Cvoid
end

function io_uring_prep_openat2_direct(sqe, dfd, path, how, file_index)
    @ccall liburing.io_uring_prep_openat2_direct(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, how::Ptr{open_how}, file_index::Cuint)::Cvoid
end

mutable struct epoll_event end

function io_uring_prep_epoll_ctl(sqe, epfd, fd, op, ev)
    @ccall liburing.io_uring_prep_epoll_ctl(sqe::Ptr{io_uring_sqe}, epfd::Cint, fd::Cint, op::Cint, ev::Ptr{epoll_event})::Cvoid
end

function io_uring_prep_provide_buffers(sqe, addr, len, nr, bgid, bid)
    @ccall liburing.io_uring_prep_provide_buffers(sqe::Ptr{io_uring_sqe}, addr::Ptr{Cvoid}, len::Cint, nr::Cint, bgid::Cint, bid::Cint)::Cvoid
end

function io_uring_prep_remove_buffers(sqe, nr, bgid)
    @ccall liburing.io_uring_prep_remove_buffers(sqe::Ptr{io_uring_sqe}, nr::Cint, bgid::Cint)::Cvoid
end

function io_uring_prep_shutdown(sqe, fd, how)
    @ccall liburing.io_uring_prep_shutdown(sqe::Ptr{io_uring_sqe}, fd::Cint, how::Cint)::Cvoid
end

function io_uring_prep_unlinkat(sqe, dfd, path, flags)
    @ccall liburing.io_uring_prep_unlinkat(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, flags::Cint)::Cvoid
end

function io_uring_prep_unlink(sqe, path, flags)
    @ccall liburing.io_uring_prep_unlink(sqe::Ptr{io_uring_sqe}, path::Ptr{Cchar}, flags::Cint)::Cvoid
end

function io_uring_prep_renameat(sqe, olddfd, oldpath, newdfd, newpath, flags)
    @ccall liburing.io_uring_prep_renameat(sqe::Ptr{io_uring_sqe}, olddfd::Cint, oldpath::Ptr{Cchar}, newdfd::Cint, newpath::Ptr{Cchar}, flags::Cuint)::Cvoid
end

function io_uring_prep_rename(sqe, oldpath, newpath)
    @ccall liburing.io_uring_prep_rename(sqe::Ptr{io_uring_sqe}, oldpath::Ptr{Cchar}, newpath::Ptr{Cchar})::Cvoid
end

function io_uring_prep_sync_file_range(sqe, fd, len, offset, flags)
    @ccall liburing.io_uring_prep_sync_file_range(sqe::Ptr{io_uring_sqe}, fd::Cint, len::Cuint, offset::__u64, flags::Cint)::Cvoid
end

function io_uring_prep_mkdirat(sqe, dfd, path, mode)
    @ccall liburing.io_uring_prep_mkdirat(sqe::Ptr{io_uring_sqe}, dfd::Cint, path::Ptr{Cchar}, mode::mode_t)::Cvoid
end

function io_uring_prep_mkdir(sqe, path, mode)
    @ccall liburing.io_uring_prep_mkdir(sqe::Ptr{io_uring_sqe}, path::Ptr{Cchar}, mode::mode_t)::Cvoid
end

function io_uring_prep_symlinkat(sqe, target, newdirfd, linkpath)
    @ccall liburing.io_uring_prep_symlinkat(sqe::Ptr{io_uring_sqe}, target::Ptr{Cchar}, newdirfd::Cint, linkpath::Ptr{Cchar})::Cvoid
end

function io_uring_prep_symlink(sqe, target, linkpath)
    @ccall liburing.io_uring_prep_symlink(sqe::Ptr{io_uring_sqe}, target::Ptr{Cchar}, linkpath::Ptr{Cchar})::Cvoid
end

function io_uring_prep_linkat(sqe, olddfd, oldpath, newdfd, newpath, flags)
    @ccall liburing.io_uring_prep_linkat(sqe::Ptr{io_uring_sqe}, olddfd::Cint, oldpath::Ptr{Cchar}, newdfd::Cint, newpath::Ptr{Cchar}, flags::Cint)::Cvoid
end

function io_uring_prep_link(sqe, oldpath, newpath, flags)
    @ccall liburing.io_uring_prep_link(sqe::Ptr{io_uring_sqe}, oldpath::Ptr{Cchar}, newpath::Ptr{Cchar}, flags::Cint)::Cvoid
end

function io_uring_prep_msg_ring(sqe, fd, len, data, flags)
    @ccall liburing.io_uring_prep_msg_ring(sqe::Ptr{io_uring_sqe}, fd::Cint, len::Cuint, data::__u64, flags::Cuint)::Cvoid
end

function io_uring_prep_getxattr(sqe, name, value, path, len)
    @ccall liburing.io_uring_prep_getxattr(sqe::Ptr{io_uring_sqe}, name::Ptr{Cchar}, value::Ptr{Cchar}, path::Ptr{Cchar}, len::Cuint)::Cvoid
end

function io_uring_prep_setxattr(sqe, name, value, path, flags, len)
    @ccall liburing.io_uring_prep_setxattr(sqe::Ptr{io_uring_sqe}, name::Ptr{Cchar}, value::Ptr{Cchar}, path::Ptr{Cchar}, flags::Cint, len::Cuint)::Cvoid
end

function io_uring_prep_fgetxattr(sqe, fd, name, value, len)
    @ccall liburing.io_uring_prep_fgetxattr(sqe::Ptr{io_uring_sqe}, fd::Cint, name::Ptr{Cchar}, value::Ptr{Cchar}, len::Cuint)::Cvoid
end

function io_uring_prep_fsetxattr(sqe, fd, name, value, flags, len)
    @ccall liburing.io_uring_prep_fsetxattr(sqe::Ptr{io_uring_sqe}, fd::Cint, name::Ptr{Cchar}, value::Ptr{Cchar}, flags::Cint, len::Cuint)::Cvoid
end

function io_uring_prep_socket(sqe, domain, type, protocol, flags)
    @ccall liburing.io_uring_prep_socket(sqe::Ptr{io_uring_sqe}, domain::Cint, type::Cint, protocol::Cint, flags::Cuint)::Cvoid
end

function io_uring_prep_socket_direct(sqe, domain, type, protocol, file_index, flags)
    @ccall liburing.io_uring_prep_socket_direct(sqe::Ptr{io_uring_sqe}, domain::Cint, type::Cint, protocol::Cint, file_index::Cuint, flags::Cuint)::Cvoid
end

function io_uring_prep_socket_direct_alloc(sqe, domain, type, protocol, flags)
    @ccall liburing.io_uring_prep_socket_direct_alloc(sqe::Ptr{io_uring_sqe}, domain::Cint, type::Cint, protocol::Cint, flags::Cuint)::Cvoid
end

function io_uring_sq_ready(ring)
    @ccall liburing.io_uring_sq_ready(ring::Ptr{io_uring})::Cuint
end

function io_uring_sq_space_left(ring)
    @ccall liburing.io_uring_sq_space_left(ring::Ptr{io_uring})::Cuint
end

function io_uring_sqring_wait(ring)
    @ccall liburing.io_uring_sqring_wait(ring::Ptr{io_uring})::Cint
end

function io_uring_cq_ready(ring)
    @ccall liburing.io_uring_cq_ready(ring::Ptr{io_uring})::Cuint
end

function io_uring_cq_has_overflow(ring)
    @ccall liburing.io_uring_cq_has_overflow(ring::Ptr{io_uring})::Bool
end

function io_uring_cq_eventfd_enabled(ring)
    @ccall liburing.io_uring_cq_eventfd_enabled(ring::Ptr{io_uring})::Bool
end

function io_uring_cq_eventfd_toggle(ring, enabled)
    @ccall liburing.io_uring_cq_eventfd_toggle(ring::Ptr{io_uring}, enabled::Bool)::Cint
end

function io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr)
    @ccall liburing.io_uring_wait_cqe_nr(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}}, wait_nr::Cuint)::Cint
end

function __io_uring_peek_cqe(ring, cqe_ptr, nr_available)
    @ccall liburing.__io_uring_peek_cqe(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}}, nr_available::Ptr{Cuint})::Cint
end

function io_uring_peek_cqe(ring, cqe_ptr)
    @ccall liburing.io_uring_peek_cqe(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}})::Cint
end

function io_uring_wait_cqe(ring, cqe_ptr)
    @ccall liburing.io_uring_wait_cqe(ring::Ptr{io_uring}, cqe_ptr::Ptr{Ptr{io_uring_cqe}})::Cint
end

function _io_uring_get_sqe(ring)
    @ccall liburing._io_uring_get_sqe(ring::Ptr{io_uring})::Ptr{io_uring_sqe}
end

function io_uring_buf_ring_mask(ring_entries)
    @ccall liburing.io_uring_buf_ring_mask(ring_entries::__u32)::Cint
end

function io_uring_buf_ring_init(br)
    @ccall liburing.io_uring_buf_ring_init(br::Ptr{io_uring_buf_ring})::Cvoid
end

function io_uring_buf_ring_add(br, addr, len, bid, mask, buf_offset)
    @ccall liburing.io_uring_buf_ring_add(br::Ptr{io_uring_buf_ring}, addr::Ptr{Cvoid}, len::Cuint, bid::Cushort, mask::Cint, buf_offset::Cint)::Cvoid
end

function io_uring_buf_ring_advance(br, count)
    @ccall liburing.io_uring_buf_ring_advance(br::Ptr{io_uring_buf_ring}, count::Cint)::Cvoid
end

function io_uring_buf_ring_cq_advance(ring, br, count)
    @ccall liburing.io_uring_buf_ring_cq_advance(ring::Ptr{io_uring}, br::Ptr{io_uring_buf_ring}, count::Cint)::Cvoid
end

function io_uring_get_sqe(ring)
    @ccall liburing.io_uring_get_sqe(ring::Ptr{io_uring})::Ptr{io_uring_sqe}
end

function io_uring_mlock_size(entries, flags)
    @ccall liburing.io_uring_mlock_size(entries::Cuint, flags::Cuint)::Cssize_t
end

function io_uring_mlock_size_params(entries, p)
    @ccall liburing.io_uring_mlock_size_params(entries::Cuint, p::Ptr{io_uring_params})::Cssize_t
end

function io_uring_major_version()
    @ccall liburing.io_uring_major_version()::Cint
end

function io_uring_minor_version()
    @ccall liburing.io_uring_minor_version()::Cint
end

function io_uring_check_version(major, minor)
    @ccall liburing.io_uring_check_version(major::Cint, minor::Cint)::Bool
end

const _XOPEN_SOURCE = 500

const IORING_FILE_INDEX_ALLOC = ~(Cuint(0))

const IOSQE_FIXED_FILE = Cuint(1) << Cuint(IOSQE_FIXED_FILE_BIT)

const IOSQE_IO_DRAIN = Cuint(1) << Cuint(IOSQE_IO_DRAIN_BIT)

const IOSQE_IO_LINK = Cuint(1) << Cuint(IOSQE_IO_LINK_BIT)

const IOSQE_IO_HARDLINK = Cuint(1) << Cuint(IOSQE_IO_HARDLINK_BIT)

const IOSQE_ASYNC = Cuint(1) << Cuint(IOSQE_ASYNC_BIT)

const IOSQE_BUFFER_SELECT = Cuint(1) << Cuint(IOSQE_BUFFER_SELECT_BIT)

const IOSQE_CQE_SKIP_SUCCESS = Cuint(1) << Cuint(IOSQE_CQE_SKIP_SUCCESS_BIT)

const IORING_SETUP_IOPOLL = Cuint(1) << 0

const IORING_SETUP_SQPOLL = Cuint(1) << 1

const IORING_SETUP_SQ_AFF = Cuint(1) << 2

const IORING_SETUP_CQSIZE = Cuint(1) << 3

const IORING_SETUP_CLAMP = Cuint(1) << 4

const IORING_SETUP_ATTACH_WQ = Cuint(1) << 5

const IORING_SETUP_R_DISABLED = Cuint(1) << 6

const IORING_SETUP_SUBMIT_ALL = Cuint(1) << 7

const IORING_SETUP_COOP_TASKRUN = Cuint(1) << 8

const IORING_SETUP_TASKRUN_FLAG = Cuint(1) << 9

const IORING_SETUP_SQE128 = Cuint(1) << 10

const IORING_SETUP_CQE32 = Cuint(1) << 11

const IORING_SETUP_SINGLE_ISSUER = Cuint(1) << 12

const IORING_SETUP_DEFER_TASKRUN = Cuint(1) << 13

const IORING_URING_CMD_FIXED = Cuint(1) << 0

const IORING_FSYNC_DATASYNC = Cuint(1) << 0

const IORING_TIMEOUT_ABS = Cuint(1) << 0

const IORING_TIMEOUT_UPDATE = Cuint(1) << 1

const IORING_TIMEOUT_BOOTTIME = Cuint(1) << 2

const IORING_TIMEOUT_REALTIME = Cuint(1) << 3

const IORING_LINK_TIMEOUT_UPDATE = Cuint(1) << 4

const IORING_TIMEOUT_ETIME_SUCCESS = Cuint(1) << 5

const IORING_TIMEOUT_CLOCK_MASK = IORING_TIMEOUT_BOOTTIME | IORING_TIMEOUT_REALTIME

const IORING_TIMEOUT_UPDATE_MASK = IORING_TIMEOUT_UPDATE | IORING_LINK_TIMEOUT_UPDATE

const SPLICE_F_FD_IN_FIXED = Cuint(1) << 31

const IORING_POLL_ADD_MULTI = Cuint(1) << 0

const IORING_POLL_UPDATE_EVENTS = Cuint(1) << 1

const IORING_POLL_UPDATE_USER_DATA = Cuint(1) << 2

const IORING_POLL_ADD_LEVEL = Cuint(1) << 3

const IORING_ASYNC_CANCEL_ALL = Cuint(1) << 0

const IORING_ASYNC_CANCEL_FD = Cuint(1) << 1

const IORING_ASYNC_CANCEL_ANY = Cuint(1) << 2

const IORING_ASYNC_CANCEL_FD_FIXED = Cuint(1) << 3

const IORING_RECVSEND_POLL_FIRST = Cuint(1) << 0

const IORING_RECV_MULTISHOT = Cuint(1) << 1

const IORING_RECVSEND_FIXED_BUF = Cuint(1) << 2

const IORING_ACCEPT_MULTISHOT = Cuint(1) << 0

const IORING_MSG_RING_CQE_SKIP = Cuint(1) << 0

const IORING_CQE_F_BUFFER = Cuint(1) << 0

const IORING_CQE_F_MORE = Cuint(1) << 1

const IORING_CQE_F_SOCK_NONEMPTY = Cuint(1) << 2

const IORING_CQE_F_NOTIF = Cuint(1) << 3

const IORING_OFF_SQ_RING = Culonglong(0)

const IORING_OFF_CQ_RING = Culonglong(0x08000000)

const IORING_OFF_SQES = Culonglong(0x10000000)

const IORING_SQ_NEED_WAKEUP = Cuint(1) << 0

const IORING_SQ_CQ_OVERFLOW = Cuint(1) << 1

const IORING_SQ_TASKRUN = Cuint(1) << 2

const IORING_CQ_EVENTFD_DISABLED = Cuint(1) << 0

const IORING_ENTER_GETEVENTS = Cuint(1) << 0

const IORING_ENTER_SQ_WAKEUP = Cuint(1) << 1

const IORING_ENTER_SQ_WAIT = Cuint(1) << 2

const IORING_ENTER_EXT_ARG = Cuint(1) << 3

const IORING_ENTER_REGISTERED_RING = Cuint(1) << 4

const IORING_FEAT_SINGLE_MMAP = Cuint(1) << 0

const IORING_FEAT_NODROP = Cuint(1) << 1

const IORING_FEAT_SUBMIT_STABLE = Cuint(1) << 2

const IORING_FEAT_RW_CUR_POS = Cuint(1) << 3

const IORING_FEAT_CUR_PERSONALITY = Cuint(1) << 4

const IORING_FEAT_FAST_POLL = Cuint(1) << 5

const IORING_FEAT_POLL_32BITS = Cuint(1) << 6

const IORING_FEAT_SQPOLL_NONFIXED = Cuint(1) << 7

const IORING_FEAT_EXT_ARG = Cuint(1) << 8

const IORING_FEAT_NATIVE_WORKERS = Cuint(1) << 9

const IORING_FEAT_RSRC_TAGS = Cuint(1) << 10

const IORING_FEAT_CQE_SKIP = Cuint(1) << 11

const IORING_FEAT_LINKED_FILE = Cuint(1) << 12

const IORING_RSRC_REGISTER_SPARSE = Cuint(1) << 0

const IORING_REGISTER_FILES_SKIP = -2

const IO_URING_OP_SUPPORTED = Cuint(1) << 0

const IO_URING_VERSION_MAJOR = 2

const IO_URING_VERSION_MINOR = 4

# Skipping MacroDefinition: IOURINGINLINE static inline

const __NR_io_uring_setup = 425

const __NR_io_uring_enter = 426

const __NR_io_uring_register = 427

const LIBURING_UDATA_TIMEOUT = -1

