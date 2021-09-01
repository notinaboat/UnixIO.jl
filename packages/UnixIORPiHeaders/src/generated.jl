czeros(T) =
    (hasmethod(zero, (t,)) ? zero(t) :
                t <: Tuple ? (czeros(t)...,) :
                            t(czeros(t)...)
     for t in fieldtypes(T))

import Base

using Base: |

using CEnum

const Ctm = Base.Libc.TmStruct

const Ctime_t = UInt

const Cclock_t = UInt

const Clong = Base.Clong

const Bool = Base.Bool

const Int64 = Base.Int64

const Cwchar_t = Base.Cwchar_t

const C_NULL = Base.C_NULL

const UInt64 = Base.UInt64

const Int16 = Base.Int16

const UInt32 = Base.UInt32

const UInt32 = Base.UInt32

const Culonglong = Base.Culonglong

const Csize_t = Base.Csize_t

const UInt128 = Base.UInt128

const Cdouble = Base.Cdouble

const Complex = Base.Complex

const UInt8 = Base.UInt8

const Culong = Base.Culong

const Cuchar = Base.Cuchar

const Int32 = Base.Int32

const Int128 = Base.Int128

const Cptrdiff_t = Base.Cptrdiff_t

const UInt8 = Base.UInt8

const Csize_t = Base.Csize_t

const Clong = Base.Clong

const Int8 = Base.Int8

const UInt16 = Base.UInt16

const UInt16 = Base.UInt16

const Char = Base.Char

const UInt8 = Base.UInt8

const Clonglong = Base.Clonglong

const UInt32 = Base.UInt32

const Int16 = Base.Int16

const Cfloat = Base.Cfloat

const UInt16 = Base.UInt16

const Float64 = Base.Float64

const UInt8 = Base.UInt8

const error_t = Cint

const size_t = UInt32

const SEM_VALUE_MAX = 2147483647

const RE_DUP_MAX = Float32(0x07ff)

const wchar_t = UInt32

function __locale_struct()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __locale_struct(CInclude.czeros(__locale_struct)...)
end

const __locale_t = Ptr{__locale_struct}

const locale_t = __locale_t

@cenum ANONYMOUS_ENUM_1::UInt32 begin
        P_ALL = 0
        P_PID = 1
        P_PGID = 2
    end

const _Float32 = Cfloat

const _Float64 = Float64

const _Float32x = Cdouble

struct div_t
    quot::Cint
    rem::Cint
end

mutable struct div_t_m
    quot::Cint
    rem::Cint
end

struct ldiv_t
    quot::Clong
    rem::Clong
end

mutable struct ldiv_t_m
    quot::Clong
    rem::Clong
end

struct lldiv_t
    quot::Clonglong
    rem::Clonglong
end

mutable struct lldiv_t_m
    quot::Clonglong
    rem::Clonglong
end

const __u_char = Cuchar

const __u_short = UInt16

const __u_int = UInt32

const __u_long = Culong

const __int8_t = UInt8

const __uint8_t = Cuchar

const __int16_t = Int16

const __uint16_t = UInt16

const __int32_t = Cint

const __uint32_t = UInt32

const __int64_t = Clonglong

const __uint64_t = Culonglong

const __int_least8_t = __int8_t

const __uint_least8_t = __uint8_t

const __int_least16_t = __int16_t

const __uint_least16_t = __uint16_t

const __int_least32_t = __int32_t

const __uint_least32_t = __uint32_t

const __int_least64_t = __int64_t

const __uint_least64_t = __uint64_t

const __quad_t = Clonglong

const __u_quad_t = Culonglong

const __intmax_t = Clonglong

const __uintmax_t = Culonglong

const __dev_t = __u_quad_t

const __uid_t = UInt32

const __gid_t = UInt32

const __ino_t = Culong

const __ino64_t = __u_quad_t

const __mode_t = UInt32

const __nlink_t = UInt32

const __off_t = Clong

const __off64_t = __quad_t

const __pid_t = Cint

struct __fsid_t
    __val::NTuple{2, Cint}
end

mutable struct __fsid_t_m
    __val::NTuple{2, Cint}
end

const __clock_t = Clong

const __rlim_t = Culong

const __rlim64_t = __u_quad_t

const __id_t = UInt32

const __time_t = Clong

const __useconds_t = UInt32

const __suseconds_t = Clong

const __daddr_t = Cint

const __key_t = Cint

const __clockid_t = Cint

const __timer_t = Ptr{Cvoid}

const __blksize_t = Clong

const __blkcnt_t = Clong

const __blkcnt64_t = __quad_t

const __fsblkcnt_t = Culong

const __fsblkcnt64_t = __u_quad_t

const __fsfilcnt_t = Culong

const __fsfilcnt64_t = __u_quad_t

const __fsword_t = Cint

const __ssize_t = Cint

const __syscall_slong_t = Clong

const __syscall_ulong_t = Culong

const __loff_t = __off64_t

const __caddr_t = Cstring

const __intptr_t = Cint

const __socklen_t = UInt32

const __sig_atomic_t = Cint

const u_char = __u_char

const u_short = __u_short

const u_int = __u_int

const u_long = __u_long

const quad_t = __quad_t

const u_quad_t = __u_quad_t

const fsid_t = __fsid_t

const loff_t = __loff_t

const ino_t = __ino_t

const ino64_t = __ino64_t

const dev_t = __dev_t

const gid_t = __gid_t

const mode_t = __mode_t

const nlink_t = __nlink_t

const uid_t = __uid_t

const off_t = __off_t

const off64_t = __off64_t

const pid_t = __pid_t

const id_t = __id_t

const ssize_t = __ssize_t

const daddr_t = __daddr_t

const caddr_t = __caddr_t

const key_t = __key_t

const clock_t = __clock_t

const clockid_t = __clockid_t

const time_t = __time_t

const timer_t = __timer_t

const useconds_t = __useconds_t

const suseconds_t = __suseconds_t

const ulong = Culong

const ushort = UInt16

const uint = UInt32

const int8_t = __int8_t

const int16_t = __int16_t

const int32_t = __int32_t

const int64_t = __int64_t

const u_int8_t = Cuchar

const u_int16_t = UInt16

const u_int32_t = UInt32

const u_int64_t = Culonglong

const register_t = Cint

struct __sigset_t
    __val::NTuple{32, Culong}
end

mutable struct __sigset_t_m
    __val::NTuple{32, Culong}
end

const sigset_t = __sigset_t

struct timeval
    tv_sec::__time_t
    tv_usec::__suseconds_t
end

mutable struct timeval_m
    tv_sec::__time_t
    tv_usec::__suseconds_t
end

struct timespec
    tv_sec::__time_t
    tv_nsec::__syscall_slong_t
end

mutable struct timespec_m
    tv_sec::__time_t
    tv_nsec::__syscall_slong_t
end

const __fd_mask = Clong

struct fd_set
    fds_bits::NTuple{32, __fd_mask}
end

mutable struct fd_set_m
    fds_bits::NTuple{32, __fd_mask}
end

const fd_mask = __fd_mask

const blksize_t = __blksize_t

const blkcnt_t = __blkcnt_t

const fsblkcnt_t = __fsblkcnt_t

const fsfilcnt_t = __fsfilcnt_t

const blkcnt64_t = __blkcnt64_t

const fsblkcnt64_t = __fsblkcnt64_t

const fsfilcnt64_t = __fsfilcnt64_t

struct __pthread_rwlock_arch_t
    __readers::UInt32
    __writers::UInt32
    __wrphase_futex::UInt32
    __writers_futex::UInt32
    __pad3::UInt32
    __pad4::UInt32
    __flags::Cuchar
    __shared::Cuchar
    __pad1::Cuchar
    __pad2::Cuchar
    __cur_writer::Cint
end

mutable struct __pthread_rwlock_arch_t_m
    __readers::UInt32
    __writers::UInt32
    __wrphase_futex::UInt32
    __writers_futex::UInt32
    __pad3::UInt32
    __pad4::UInt32
    __flags::Cuchar
    __shared::Cuchar
    __pad1::Cuchar
    __pad2::Cuchar
    __cur_writer::Cint
end

struct __pthread_internal_slist
    __next::Ptr{__pthread_internal_slist}
end

mutable struct __pthread_internal_slist_m
    __next::Ptr{__pthread_internal_slist}
end

const __pthread_slist_t = __pthread_internal_slist

struct __pthread_mutex_s
    __lock::Cint
    __count::UInt32
    __owner::Cint
    __kind::Cint
    __nusers::UInt32
end

mutable struct __pthread_mutex_s_m
    __lock::Cint
    __count::UInt32
    __owner::Cint
    __kind::Cint
    __nusers::UInt32
end

struct __pthread_cond_s
    __g_refs::NTuple{2, UInt32}
    __g_size::NTuple{2, UInt32}
    __g1_orig_size::UInt32
    __wrefs::UInt32
    __g_signals::NTuple{2, UInt32}
end

mutable struct __pthread_cond_s_m
    __g_refs::NTuple{2, UInt32}
    __g_size::NTuple{2, UInt32}
    __g1_orig_size::UInt32
    __wrefs::UInt32
    __g_signals::NTuple{2, UInt32}
end

const pthread_t = Culong

struct pthread_mutexattr_t
    __size::NTuple{4, UInt8}
end

mutable struct pthread_mutexattr_t_m
    __size::NTuple{4, UInt8}
end

struct pthread_condattr_t
    __size::NTuple{4, UInt8}
end

mutable struct pthread_condattr_t_m
    __size::NTuple{4, UInt8}
end

const pthread_key_t = UInt32

const pthread_once_t = Cint

struct pthread_attr_t
    __size::NTuple{36, UInt8}
end

mutable struct pthread_attr_t_m
    __size::NTuple{36, UInt8}
end

struct pthread_mutex_t
    __data::__pthread_mutex_s
end

mutable struct pthread_mutex_t_m
    __data::__pthread_mutex_s
end

struct pthread_cond_t
    __data::__pthread_cond_s
end

mutable struct pthread_cond_t_m
    __data::__pthread_cond_s
end

struct pthread_rwlock_t
    __data::__pthread_rwlock_arch_t
end

mutable struct pthread_rwlock_t_m
    __data::__pthread_rwlock_arch_t
end

struct pthread_rwlockattr_t
    __size::NTuple{8, UInt8}
end

mutable struct pthread_rwlockattr_t_m
    __size::NTuple{8, UInt8}
end

const pthread_spinlock_t = Cint

struct pthread_barrier_t
    __size::NTuple{20, UInt8}
end

mutable struct pthread_barrier_t_m
    __size::NTuple{20, UInt8}
end

struct pthread_barrierattr_t
    __size::NTuple{4, UInt8}
end

mutable struct pthread_barrierattr_t_m
    __size::NTuple{4, UInt8}
end

struct random_data
    fptr::Ptr{Int32}
    rptr::Ptr{Int32}
    state::Ptr{Int32}
    rand_type::Cint
    rand_deg::Cint
    rand_sep::Cint
    end_ptr::Ptr{Int32}
end

mutable struct random_data_m
    fptr::Ptr{Int32}
    rptr::Ptr{Int32}
    state::Ptr{Int32}
    rand_type::Cint
    rand_deg::Cint
    rand_sep::Cint
    end_ptr::Ptr{Int32}
end

struct drand48_data
    __x::NTuple{3, UInt16}
    __old_x::NTuple{3, UInt16}
    __c::UInt16
    __init::UInt16
    __a::Culonglong
end

mutable struct drand48_data_m
    __x::NTuple{3, UInt16}
    __old_x::NTuple{3, UInt16}
    __c::UInt16
    __init::UInt16
    __a::Culonglong
end

const __compar_fn_t = Ptr{Cvoid}

const comparison_fn_t = __compar_fn_t

const __compar_d_fn_t = Ptr{Cvoid}

struct sched_param
    sched_priority::Cint
end

mutable struct sched_param_m
    sched_priority::Cint
end

const __cpu_mask = Culong

struct cpu_set_t
    __bits::NTuple{32, __cpu_mask}
end

mutable struct cpu_set_t_m
    __bits::NTuple{32, __cpu_mask}
end

struct tm
    tm_sec::Cint
    tm_min::Cint
    tm_hour::Cint
    tm_mday::Cint
    tm_mon::Cint
    tm_year::Cint
    tm_wday::Cint
    tm_yday::Cint
    tm_isdst::Cint
    tm_gmtoff::Clong
    tm_zone::Cstring
end

mutable struct tm_m
    tm_sec::Cint
    tm_min::Cint
    tm_hour::Cint
    tm_mday::Cint
    tm_mon::Cint
    tm_year::Cint
    tm_wday::Cint
    tm_yday::Cint
    tm_isdst::Cint
    tm_gmtoff::Clong
    tm_zone::Cstring
end

struct itimerspec
    it_interval::timespec
    it_value::timespec
end

mutable struct itimerspec_m
    it_interval::timespec
    it_value::timespec
end

struct sigval
    sival_int::Cint
end

mutable struct sigval_m
    sival_int::Cint
end

const __sigval_t = sigval

struct ANONYMOUS29__sigev_un
    _pad::NTuple{13, Cint}
end

mutable struct ANONYMOUS29__sigev_un_m
    _pad::NTuple{13, Cint}
end

struct sigevent
    sigev_value::__sigval_t
    sigev_signo::Cint
    sigev_notify::Cint
    _sigev_un::ANONYMOUS29__sigev_un
end

mutable struct sigevent_m
    sigev_value::__sigval_t
    sigev_signo::Cint
    sigev_notify::Cint
    _sigev_un::ANONYMOUS29__sigev_un
end

const __jmp_buf = NTuple{64, Cint}

@cenum ANONYMOUS_ENUM_2::UInt32 begin
        PTHREAD_CREATE_JOINABLE = 0
        PTHREAD_CREATE_DETACHED = 1
    end

@cenum ANONYMOUS_ENUM_3::UInt32 begin
        PTHREAD_MUTEX_TIMED_NP = 0
        PTHREAD_MUTEX_RECURSIVE_NP = 1
        PTHREAD_MUTEX_ERRORCHECK_NP = 2
        PTHREAD_MUTEX_ADAPTIVE_NP = 3
        PTHREAD_MUTEX_NORMAL = 0
        PTHREAD_MUTEX_RECURSIVE = 1
        PTHREAD_MUTEX_ERRORCHECK = 2
        PTHREAD_MUTEX_DEFAULT = 0
        PTHREAD_MUTEX_FAST_NP = 0
    end

@cenum ANONYMOUS_ENUM_4::UInt32 begin
        PTHREAD_MUTEX_STALLED = 0
        PTHREAD_MUTEX_STALLED_NP = 0
        PTHREAD_MUTEX_ROBUST = 1
        PTHREAD_MUTEX_ROBUST_NP = 1
    end

@cenum ANONYMOUS_ENUM_5::UInt32 begin
        PTHREAD_PRIO_NONE = 0
        PTHREAD_PRIO_INHERIT = 1
        PTHREAD_PRIO_PROTECT = 2
    end

@cenum ANONYMOUS_ENUM_6::UInt32 begin
        PTHREAD_RWLOCK_PREFER_READER_NP = 0
        PTHREAD_RWLOCK_PREFER_WRITER_NP = 1
        PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP = 2
        PTHREAD_RWLOCK_DEFAULT_NP = 0
    end

@cenum ANONYMOUS_ENUM_7::UInt32 begin
        PTHREAD_INHERIT_SCHED = 0
        PTHREAD_EXPLICIT_SCHED = 1
    end

@cenum ANONYMOUS_ENUM_8::UInt32 begin
        PTHREAD_SCOPE_SYSTEM = 0
        PTHREAD_SCOPE_PROCESS = 1
    end

@cenum ANONYMOUS_ENUM_9::UInt32 begin
        PTHREAD_PROCESS_PRIVATE = 0
        PTHREAD_PROCESS_SHARED = 1
    end

struct _pthread_cleanup_buffer
    __routine::Ptr{Cvoid}
    __arg::Ptr{Cvoid}
    __canceltype::Cint
    __prev::Ptr{_pthread_cleanup_buffer}
end

mutable struct _pthread_cleanup_buffer_m
    __routine::Ptr{Cvoid}
    __arg::Ptr{Cvoid}
    __canceltype::Cint
    __prev::Ptr{_pthread_cleanup_buffer}
end

@cenum ANONYMOUS_ENUM_10::UInt32 begin
        PTHREAD_CANCEL_ENABLE = 0
        PTHREAD_CANCEL_DISABLE = 1
    end

@cenum ANONYMOUS_ENUM_11::UInt32 begin
        PTHREAD_CANCEL_DEFERRED = 0
        PTHREAD_CANCEL_ASYNCHRONOUS = 1
    end

struct ANONYMOUS12___cancel_jmp_buf
    __cancel_jmp_buf::__jmp_buf
    __mask_was_saved::Cint
end

mutable struct ANONYMOUS12___cancel_jmp_buf_m
    __cancel_jmp_buf::__jmp_buf
    __mask_was_saved::Cint
end

struct __pthread_unwind_buf_t
    __cancel_jmp_buf::ANONYMOUS12___cancel_jmp_buf
    __pad::NTuple{4, Ptr{Cvoid}}
end

mutable struct __pthread_unwind_buf_t_m
    __cancel_jmp_buf::ANONYMOUS12___cancel_jmp_buf
    __pad::NTuple{4, Ptr{Cvoid}}
end

struct __pthread_cleanup_frame
    __cancel_routine::Ptr{Cvoid}
    __cancel_arg::Ptr{Cvoid}
    __do_it::Cint
    __cancel_type::Cint
end

mutable struct __pthread_cleanup_frame_m
    __cancel_routine::Ptr{Cvoid}
    __cancel_arg::Ptr{Cvoid}
    __do_it::Cint
    __cancel_type::Cint
end

const __jmp_buf_tag = Cvoid

struct winsize
    ws_row::UInt16
    ws_col::UInt16
    ws_xpixel::UInt16
    ws_ypixel::UInt16
end

mutable struct winsize_m
    ws_row::UInt16
    ws_col::UInt16
    ws_xpixel::UInt16
    ws_ypixel::UInt16
end

struct termio
    c_iflag::UInt16
    c_oflag::UInt16
    c_cflag::UInt16
    c_lflag::UInt16
    c_line::Cuchar
    c_cc::NTuple{8, Cuchar}
end

mutable struct termio_m
    c_iflag::UInt16
    c_oflag::UInt16
    c_cflag::UInt16
    c_lflag::UInt16
    c_line::Cuchar
    c_cc::NTuple{8, Cuchar}
end

const cc_t = Cuchar

const speed_t = UInt32

const tcflag_t = UInt32

struct termios
    c_iflag::tcflag_t
    c_oflag::tcflag_t
    c_cflag::tcflag_t
    c_lflag::tcflag_t
    c_line::cc_t
    c_cc::NTuple{32, cc_t}
    c_ispeed::speed_t
    c_ospeed::speed_t
end

mutable struct termios_m
    c_iflag::tcflag_t
    c_oflag::tcflag_t
    c_cflag::tcflag_t
    c_lflag::tcflag_t
    c_line::cc_t
    c_cc::NTuple{32, cc_t}
    c_ispeed::speed_t
    c_ospeed::speed_t
end

struct flock
    l_type::Int16
    l_whence::Int16
    l_start::__off_t
    l_len::__off_t
    l_pid::__pid_t
end

mutable struct flock_m
    l_type::Int16
    l_whence::Int16
    l_start::__off_t
    l_len::__off_t
    l_pid::__pid_t
end

struct flock64
    l_type::Int16
    l_whence::Int16
    l_start::__off64_t
    l_len::__off64_t
    l_pid::__pid_t
end

mutable struct flock64_m
    l_type::Int16
    l_whence::Int16
    l_start::__off64_t
    l_len::__off64_t
    l_pid::__pid_t
end

struct iovec
    iov_base::Ptr{Cvoid}
    iov_len::Csize_t
end

mutable struct iovec_m
    iov_base::Ptr{Cvoid}
    iov_len::Csize_t
end

@cenum __pid_type::UInt32 begin
        F_OWNER_TID = 0
        F_OWNER_PID = 1
        F_OWNER_PGRP = 2
        F_OWNER_GID = 2
    end

struct f_owner_ex
    type::__pid_type
    pid::__pid_t
end

mutable struct f_owner_ex_m
    type::__pid_type
    pid::__pid_t
end

struct file_handle
    handle_bytes::UInt32
    handle_type::Cint
    f_handle::NTuple{0, Cuchar}
end

mutable struct file_handle_m
    handle_bytes::UInt32
    handle_type::Cint
    f_handle::NTuple{0, Cuchar}
end

struct stat
    st_dev::__dev_t
    __pad1::UInt16
    st_ino::__ino_t
    st_mode::__mode_t
    st_nlink::__nlink_t
    st_uid::__uid_t
    st_gid::__gid_t
    st_rdev::__dev_t
    __pad2::UInt16
    st_size::__off_t
    st_blksize::__blksize_t
    st_blocks::__blkcnt_t
    st_atim::timespec
    st_mtim::timespec
    st_ctim::timespec
    __glibc_reserved4::Culong
    __glibc_reserved5::Culong
end

mutable struct stat_m
    st_dev::__dev_t
    __pad1::UInt16
    st_ino::__ino_t
    st_mode::__mode_t
    st_nlink::__nlink_t
    st_uid::__uid_t
    st_gid::__gid_t
    st_rdev::__dev_t
    __pad2::UInt16
    st_size::__off_t
    st_blksize::__blksize_t
    st_blocks::__blkcnt_t
    st_atim::timespec
    st_mtim::timespec
    st_ctim::timespec
    __glibc_reserved4::Culong
    __glibc_reserved5::Culong
end

struct stat64
    st_dev::__dev_t
    __pad1::UInt32
    __st_ino::__ino_t
    st_mode::__mode_t
    st_nlink::__nlink_t
    st_uid::__uid_t
    st_gid::__gid_t
    st_rdev::__dev_t
    __pad2::UInt32
    st_size::__off64_t
    st_blksize::__blksize_t
    st_blocks::__blkcnt64_t
    st_atim::timespec
    st_mtim::timespec
    st_ctim::timespec
    st_ino::__ino64_t
end

mutable struct stat64_m
    st_dev::__dev_t
    __pad1::UInt32
    __st_ino::__ino_t
    st_mode::__mode_t
    st_nlink::__nlink_t
    st_uid::__uid_t
    st_gid::__gid_t
    st_rdev::__dev_t
    __pad2::UInt32
    st_size::__off64_t
    st_blksize::__blksize_t
    st_blocks::__blkcnt64_t
    st_atim::timespec
    st_mtim::timespec
    st_ctim::timespec
    st_ino::__ino64_t
end

const nfds_t = Culong

struct pollfd
    fd::Cint
    events::Int16
    revents::Int16
end

mutable struct pollfd_m
    fd::Cint
    events::Int16
    revents::Int16
end

const INT8_MIN = -128

const INT8_MAX = 127

const INT16_MAX = 32767

const INT32_MAX = 2147483647

const UINT8_MAX = 255

const UINT16_MAX = 65535

const UINT32_MAX = UInt32(4294967295)

const INT_LEAST8_MIN = -128

const INT_LEAST8_MAX = 127

const INT_LEAST16_MAX = 32767

const INT_LEAST32_MAX = 2147483647

const UINT_LEAST8_MAX = 255

const UINT_LEAST16_MAX = 65535

const UINT_LEAST32_MAX = UInt32(4294967295)

const INT_FAST8_MIN = -128

const INT_FAST8_MAX = 127

const INT_FAST16_MAX = 2147483647

const INT_FAST32_MAX = 2147483647

const UINT_FAST8_MAX = 255

const UINT_FAST16_MAX = UInt32(4294967295)

const UINT_FAST32_MAX = UInt32(4294967295)

const INTPTR_MAX = 2147483647

const UINTPTR_MAX = UInt32(4294967295)

const PTRDIFF_MAX = 2147483647

const SIG_ATOMIC_MAX = 2147483647

const SIZE_MAX = UInt32(4294967295)

const WINT_MIN = UInt32(0)

const WINT_MAX = UInt32(4294967295)

const uint8_t = __uint8_t

const uint16_t = __uint16_t

const uint32_t = __uint32_t

const uint64_t = __uint64_t

const int_least8_t = __int_least8_t

const int_least16_t = __int_least16_t

const int_least32_t = __int_least32_t

const int_least64_t = __int_least64_t

const uint_least8_t = __uint_least8_t

const uint_least16_t = __uint_least16_t

const uint_least32_t = __uint_least32_t

const uint_least64_t = __uint_least64_t

const int_fast8_t = UInt8

const int_fast16_t = Cint

const int_fast32_t = Cint

const int_fast64_t = Clonglong

const uint_fast8_t = Cuchar

const uint_fast16_t = UInt32

const uint_fast32_t = UInt32

const uint_fast64_t = Culonglong

const intptr_t = Cint

const uintptr_t = UInt32

const intmax_t = __intmax_t

const uintmax_t = __uintmax_t

@cenum ANONYMOUS_ENUM_13::UInt32 begin
        EPOLL_CLOEXEC = 524288
    end

struct epoll_data
    u64::UInt64
end

mutable struct epoll_data_m
    u64::UInt64
end

const epoll_data_t = epoll_data

struct epoll_event
    events::UInt32
    data::epoll_data_t
end

mutable struct epoll_event_m
    events::UInt32
    data::epoll_data_t
end

const socklen_t = __socklen_t

@cenum ANONYMOUS_ENUM_14::UInt32 begin
        _PC_LINK_MAX = 0
        _PC_MAX_CANON = 1
        _PC_MAX_INPUT = 2
        _PC_NAME_MAX = 3
        _PC_PATH_MAX = 4
        _PC_PIPE_BUF = 5
        _PC_CHOWN_RESTRICTED = 6
        _PC_NO_TRUNC = 7
        _PC_VDISABLE = 8
        _PC_SYNC_IO = 9
        _PC_ASYNC_IO = 10
        _PC_PRIO_IO = 11
        _PC_SOCK_MAXBUF = 12
        _PC_FILESIZEBITS = 13
        _PC_REC_INCR_XFER_SIZE = 14
        _PC_REC_MAX_XFER_SIZE = 15
        _PC_REC_MIN_XFER_SIZE = 16
        _PC_REC_XFER_ALIGN = 17
        _PC_ALLOC_SIZE_MIN = 18
        _PC_SYMLINK_MAX = 19
        _PC_2_SYMLINKS = 20
    end

@cenum ANONYMOUS_ENUM_15::UInt32 begin
        _SC_ARG_MAX = 0
        _SC_CHILD_MAX = 1
        _SC_CLK_TCK = 2
        _SC_NGROUPS_MAX = 3
        _SC_OPEN_MAX = 4
        _SC_STREAM_MAX = 5
        _SC_TZNAME_MAX = 6
        _SC_JOB_CONTROL = 7
        _SC_SAVED_IDS = 8
        _SC_REALTIME_SIGNALS = 9
        _SC_PRIORITY_SCHEDULING = 10
        _SC_TIMERS = 11
        _SC_ASYNCHRONOUS_IO = 12
        _SC_PRIORITIZED_IO = 13
        _SC_SYNCHRONIZED_IO = 14
        _SC_FSYNC = 15
        _SC_MAPPED_FILES = 16
        _SC_MEMLOCK = 17
        _SC_MEMLOCK_RANGE = 18
        _SC_MEMORY_PROTECTION = 19
        _SC_MESSAGE_PASSING = 20
        _SC_SEMAPHORES = 21
        _SC_SHARED_MEMORY_OBJECTS = 22
        _SC_AIO_LISTIO_MAX = 23
        _SC_AIO_MAX = 24
        _SC_AIO_PRIO_DELTA_MAX = 25
        _SC_DELAYTIMER_MAX = 26
        _SC_MQ_OPEN_MAX = 27
        _SC_MQ_PRIO_MAX = 28
        _SC_VERSION = 29
        _SC_PAGESIZE = 30
        _SC_RTSIG_MAX = 31
        _SC_SEM_NSEMS_MAX = 32
        _SC_SEM_VALUE_MAX = 33
        _SC_SIGQUEUE_MAX = 34
        _SC_TIMER_MAX = 35
        _SC_BC_BASE_MAX = 36
        _SC_BC_DIM_MAX = 37
        _SC_BC_SCALE_MAX = 38
        _SC_BC_STRING_MAX = 39
        _SC_COLL_WEIGHTS_MAX = 40
        _SC_EQUIV_CLASS_MAX = 41
        _SC_EXPR_NEST_MAX = 42
        _SC_LINE_MAX = 43
        _SC_RE_DUP_MAX = 44
        _SC_CHARCLASS_NAME_MAX = 45
        _SC_2_VERSION = 46
        _SC_2_C_BIND = 47
        _SC_2_C_DEV = 48
        _SC_2_FORT_DEV = 49
        _SC_2_FORT_RUN = 50
        _SC_2_SW_DEV = 51
        _SC_2_LOCALEDEF = 52
        _SC_PII = 53
        _SC_PII_XTI = 54
        _SC_PII_SOCKET = 55
        _SC_PII_INTERNET = 56
        _SC_PII_OSI = 57
        _SC_POLL = 58
        _SC_SELECT = 59
        _SC_UIO_MAXIOV = 60
        _SC_IOV_MAX = 60
        _SC_PII_INTERNET_STREAM = 61
        _SC_PII_INTERNET_DGRAM = 62
        _SC_PII_OSI_COTS = 63
        _SC_PII_OSI_CLTS = 64
        _SC_PII_OSI_M = 65
        _SC_T_IOV_MAX = 66
        _SC_THREADS = 67
        _SC_THREAD_SAFE_FUNCTIONS = 68
        _SC_GETGR_R_SIZE_MAX = 69
        _SC_GETPW_R_SIZE_MAX = 70
        _SC_LOGIN_NAME_MAX = 71
        _SC_TTY_NAME_MAX = 72
        _SC_THREAD_DESTRUCTOR_ITERATIONS = 73
        _SC_THREAD_KEYS_MAX = 74
        _SC_THREAD_STACK_MIN = 75
        _SC_THREAD_THREADS_MAX = 76
        _SC_THREAD_ATTR_STACKADDR = 77
        _SC_THREAD_ATTR_STACKSIZE = 78
        _SC_THREAD_PRIORITY_SCHEDULING = 79
        _SC_THREAD_PRIO_INHERIT = 80
        _SC_THREAD_PRIO_PROTECT = 81
        _SC_THREAD_PROCESS_SHARED = 82
        _SC_NPROCESSORS_CONF = 83
        _SC_NPROCESSORS_ONLN = 84
        _SC_PHYS_PAGES = 85
        _SC_AVPHYS_PAGES = 86
        _SC_ATEXIT_MAX = 87
        _SC_PASS_MAX = 88
        _SC_XOPEN_VERSION = 89
        _SC_XOPEN_XCU_VERSION = 90
        _SC_XOPEN_UNIX = 91
        _SC_XOPEN_CRYPT = 92
        _SC_XOPEN_ENH_I18N = 93
        _SC_XOPEN_SHM = 94
        _SC_2_CHAR_TERM = 95
        _SC_2_C_VERSION = 96
        _SC_2_UPE = 97
        _SC_XOPEN_XPG2 = 98
        _SC_XOPEN_XPG3 = 99
        _SC_XOPEN_XPG4 = 100
        _SC_CHAR_BIT = 101
        _SC_CHAR_MAX = 102
        _SC_CHAR_MIN = 103
        _SC_INT_MAX = 104
        _SC_INT_MIN = 105
        _SC_LONG_BIT = 106
        _SC_WORD_BIT = 107
        _SC_MB_LEN_MAX = 108
        _SC_NZERO = 109
        _SC_SSIZE_MAX = 110
        _SC_SCHAR_MAX = 111
        _SC_SCHAR_MIN = 112
        _SC_SHRT_MAX = 113
        _SC_SHRT_MIN = 114
        _SC_UCHAR_MAX = 115
        _SC_UINT_MAX = 116
        _SC_ULONG_MAX = 117
        _SC_USHRT_MAX = 118
        _SC_NL_ARGMAX = 119
        _SC_NL_LANGMAX = 120
        _SC_NL_MSGMAX = 121
        _SC_NL_NMAX = 122
        _SC_NL_SETMAX = 123
        _SC_NL_TEXTMAX = 124
        _SC_XBS5_ILP32_OFF32 = 125
        _SC_XBS5_ILP32_OFFBIG = 126
        _SC_XBS5_LP64_OFF64 = 127
        _SC_XBS5_LPBIG_OFFBIG = 128
        _SC_XOPEN_LEGACY = 129
        _SC_XOPEN_REALTIME = 130
        _SC_XOPEN_REALTIME_THREADS = 131
        _SC_ADVISORY_INFO = 132
        _SC_BARRIERS = 133
        _SC_BASE = 134
        _SC_C_LANG_SUPPORT = 135
        _SC_C_LANG_SUPPORT_R = 136
        _SC_CLOCK_SELECTION = 137
        _SC_CPUTIME = 138
        _SC_THREAD_CPUTIME = 139
        _SC_DEVICE_IO = 140
        _SC_DEVICE_SPECIFIC = 141
        _SC_DEVICE_SPECIFIC_R = 142
        _SC_FD_MGMT = 143
        _SC_FIFO = 144
        _SC_PIPE = 145
        _SC_FILE_ATTRIBUTES = 146
        _SC_FILE_LOCKING = 147
        _SC_FILE_SYSTEM = 148
        _SC_MONOTONIC_CLOCK = 149
        _SC_MULTI_PROCESS = 150
        _SC_SINGLE_PROCESS = 151
        _SC_NETWORKING = 152
        _SC_READER_WRITER_LOCKS = 153
        _SC_SPIN_LOCKS = 154
        _SC_REGEXP = 155
        _SC_REGEX_VERSION = 156
        _SC_SHELL = 157
        _SC_SIGNALS = 158
        _SC_SPAWN = 159
        _SC_SPORADIC_SERVER = 160
        _SC_THREAD_SPORADIC_SERVER = 161
        _SC_SYSTEM_DATABASE = 162
        _SC_SYSTEM_DATABASE_R = 163
        _SC_TIMEOUTS = 164
        _SC_TYPED_MEMORY_OBJECTS = 165
        _SC_USER_GROUPS = 166
        _SC_USER_GROUPS_R = 167
        _SC_2_PBS = 168
        _SC_2_PBS_ACCOUNTING = 169
        _SC_2_PBS_LOCATE = 170
        _SC_2_PBS_MESSAGE = 171
        _SC_2_PBS_TRACK = 172
        _SC_SYMLOOP_MAX = 173
        _SC_STREAMS = 174
        _SC_2_PBS_CHECKPOINT = 175
        _SC_V6_ILP32_OFF32 = 176
        _SC_V6_ILP32_OFFBIG = 177
        _SC_V6_LP64_OFF64 = 178
        _SC_V6_LPBIG_OFFBIG = 179
        _SC_HOST_NAME_MAX = 180
        _SC_TRACE = 181
        _SC_TRACE_EVENT_FILTER = 182
        _SC_TRACE_INHERIT = 183
        _SC_TRACE_LOG = 184
        _SC_LEVEL1_ICACHE_SIZE = 185
        _SC_LEVEL1_ICACHE_ASSOC = 186
        _SC_LEVEL1_ICACHE_LINESIZE = 187
        _SC_LEVEL1_DCACHE_SIZE = 188
        _SC_LEVEL1_DCACHE_ASSOC = 189
        _SC_LEVEL1_DCACHE_LINESIZE = 190
        _SC_LEVEL2_CACHE_SIZE = 191
        _SC_LEVEL2_CACHE_ASSOC = 192
        _SC_LEVEL2_CACHE_LINESIZE = 193
        _SC_LEVEL3_CACHE_SIZE = 194
        _SC_LEVEL3_CACHE_ASSOC = 195
        _SC_LEVEL3_CACHE_LINESIZE = 196
        _SC_LEVEL4_CACHE_SIZE = 197
        _SC_LEVEL4_CACHE_ASSOC = 198
        _SC_LEVEL4_CACHE_LINESIZE = 199
        _SC_IPV6 = 235
        _SC_RAW_SOCKETS = 236
        _SC_V7_ILP32_OFF32 = 237
        _SC_V7_ILP32_OFFBIG = 238
        _SC_V7_LP64_OFF64 = 239
        _SC_V7_LPBIG_OFFBIG = 240
        _SC_SS_REPL_MAX = 241
        _SC_TRACE_EVENT_NAME_MAX = 242
        _SC_TRACE_NAME_MAX = 243
        _SC_TRACE_SYS_MAX = 244
        _SC_TRACE_USER_EVENT_MAX = 245
        _SC_XOPEN_STREAMS = 246
        _SC_THREAD_ROBUST_PRIO_INHERIT = 247
        _SC_THREAD_ROBUST_PRIO_PROTECT = 248
    end

@cenum ANONYMOUS_ENUM_16::UInt32 begin
        _CS_PATH = 0
        _CS_V6_WIDTH_RESTRICTED_ENVS = 1
        _CS_GNU_LIBC_VERSION = 2
        _CS_GNU_LIBPTHREAD_VERSION = 3
        _CS_V5_WIDTH_RESTRICTED_ENVS = 4
        _CS_V7_WIDTH_RESTRICTED_ENVS = 5
        _CS_LFS_CFLAGS = 1000
        _CS_LFS_LDFLAGS = 1001
        _CS_LFS_LIBS = 1002
        _CS_LFS_LINTFLAGS = 1003
        _CS_LFS64_CFLAGS = 1004
        _CS_LFS64_LDFLAGS = 1005
        _CS_LFS64_LIBS = 1006
        _CS_LFS64_LINTFLAGS = 1007
        _CS_XBS5_ILP32_OFF32_CFLAGS = 1100
        _CS_XBS5_ILP32_OFF32_LDFLAGS = 1101
        _CS_XBS5_ILP32_OFF32_LIBS = 1102
        _CS_XBS5_ILP32_OFF32_LINTFLAGS = 1103
        _CS_XBS5_ILP32_OFFBIG_CFLAGS = 1104
        _CS_XBS5_ILP32_OFFBIG_LDFLAGS = 1105
        _CS_XBS5_ILP32_OFFBIG_LIBS = 1106
        _CS_XBS5_ILP32_OFFBIG_LINTFLAGS = 1107
        _CS_XBS5_LP64_OFF64_CFLAGS = 1108
        _CS_XBS5_LP64_OFF64_LDFLAGS = 1109
        _CS_XBS5_LP64_OFF64_LIBS = 1110
        _CS_XBS5_LP64_OFF64_LINTFLAGS = 1111
        _CS_XBS5_LPBIG_OFFBIG_CFLAGS = 1112
        _CS_XBS5_LPBIG_OFFBIG_LDFLAGS = 1113
        _CS_XBS5_LPBIG_OFFBIG_LIBS = 1114
        _CS_XBS5_LPBIG_OFFBIG_LINTFLAGS = 1115
        _CS_POSIX_V6_ILP32_OFF32_CFLAGS = 1116
        _CS_POSIX_V6_ILP32_OFF32_LDFLAGS = 1117
        _CS_POSIX_V6_ILP32_OFF32_LIBS = 1118
        _CS_POSIX_V6_ILP32_OFF32_LINTFLAGS = 1119
        _CS_POSIX_V6_ILP32_OFFBIG_CFLAGS = 1120
        _CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS = 1121
        _CS_POSIX_V6_ILP32_OFFBIG_LIBS = 1122
        _CS_POSIX_V6_ILP32_OFFBIG_LINTFLAGS = 1123
        _CS_POSIX_V6_LP64_OFF64_CFLAGS = 1124
        _CS_POSIX_V6_LP64_OFF64_LDFLAGS = 1125
        _CS_POSIX_V6_LP64_OFF64_LIBS = 1126
        _CS_POSIX_V6_LP64_OFF64_LINTFLAGS = 1127
        _CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS = 1128
        _CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS = 1129
        _CS_POSIX_V6_LPBIG_OFFBIG_LIBS = 1130
        _CS_POSIX_V6_LPBIG_OFFBIG_LINTFLAGS = 1131
        _CS_POSIX_V7_ILP32_OFF32_CFLAGS = 1132
        _CS_POSIX_V7_ILP32_OFF32_LDFLAGS = 1133
        _CS_POSIX_V7_ILP32_OFF32_LIBS = 1134
        _CS_POSIX_V7_ILP32_OFF32_LINTFLAGS = 1135
        _CS_POSIX_V7_ILP32_OFFBIG_CFLAGS = 1136
        _CS_POSIX_V7_ILP32_OFFBIG_LDFLAGS = 1137
        _CS_POSIX_V7_ILP32_OFFBIG_LIBS = 1138
        _CS_POSIX_V7_ILP32_OFFBIG_LINTFLAGS = 1139
        _CS_POSIX_V7_LP64_OFF64_CFLAGS = 1140
        _CS_POSIX_V7_LP64_OFF64_LDFLAGS = 1141
        _CS_POSIX_V7_LP64_OFF64_LIBS = 1142
        _CS_POSIX_V7_LP64_OFF64_LINTFLAGS = 1143
        _CS_POSIX_V7_LPBIG_OFFBIG_CFLAGS = 1144
        _CS_POSIX_V7_LPBIG_OFFBIG_LDFLAGS = 1145
        _CS_POSIX_V7_LPBIG_OFFBIG_LIBS = 1146
        _CS_POSIX_V7_LPBIG_OFFBIG_LINTFLAGS = 1147
        _CS_V6_ENV = 1148
        _CS_V7_ENV = 1149
    end

struct statx_timestamp
    tv_sec::__int64_t
    tv_nsec::__uint32_t
    __statx_timestamp_pad1::NTuple{1, __int32_t}
end

mutable struct statx_timestamp_m
    tv_sec::__int64_t
    tv_nsec::__uint32_t
    __statx_timestamp_pad1::NTuple{1, __int32_t}
end

struct statx
    stx_mask::__uint32_t
    stx_blksize::__uint32_t
    stx_attributes::__uint64_t
    stx_nlink::__uint32_t
    stx_uid::__uint32_t
    stx_gid::__uint32_t
    stx_mode::__uint16_t
    __statx_pad1::NTuple{1, __uint16_t}
    stx_ino::__uint64_t
    stx_size::__uint64_t
    stx_blocks::__uint64_t
    stx_attributes_mask::__uint64_t
    stx_atime::statx_timestamp
    stx_btime::statx_timestamp
    stx_ctime::statx_timestamp
    stx_mtime::statx_timestamp
    stx_rdev_major::__uint32_t
    stx_rdev_minor::__uint32_t
    stx_dev_major::__uint32_t
    stx_dev_minor::__uint32_t
    __statx_pad2::NTuple{14, __uint64_t}
end

mutable struct statx_m
    stx_mask::__uint32_t
    stx_blksize::__uint32_t
    stx_attributes::__uint64_t
    stx_nlink::__uint32_t
    stx_uid::__uint32_t
    stx_gid::__uint32_t
    stx_mode::__uint16_t
    __statx_pad1::NTuple{1, __uint16_t}
    stx_ino::__uint64_t
    stx_size::__uint64_t
    stx_blocks::__uint64_t
    stx_attributes_mask::__uint64_t
    stx_atime::statx_timestamp
    stx_btime::statx_timestamp
    stx_ctime::statx_timestamp
    stx_mtime::statx_timestamp
    stx_rdev_major::__uint32_t
    stx_rdev_minor::__uint32_t
    stx_dev_major::__uint32_t
    stx_dev_minor::__uint32_t
    __statx_pad2::NTuple{14, __uint64_t}
end

@cenum __socket_type::UInt32 begin
        SOCK_STREAM = 1
        SOCK_DGRAM = 2
        SOCK_RAW = 3
        SOCK_RDM = 4
        SOCK_SEQPACKET = 5
        SOCK_DCCP = 6
        SOCK_PACKET = 10
        SOCK_CLOEXEC = 524288
        SOCK_NONBLOCK = 2048
    end

const sa_family_t = UInt16

struct sockaddr
    sa_family::sa_family_t
    sa_data::NTuple{14, UInt8}
end

mutable struct sockaddr_m
    sa_family::sa_family_t
    sa_data::NTuple{14, UInt8}
end

struct sockaddr_storage
    ss_family::sa_family_t
    __ss_padding::NTuple{122, UInt8}
    __ss_align::Culong
end

mutable struct sockaddr_storage_m
    ss_family::sa_family_t
    __ss_padding::NTuple{122, UInt8}
    __ss_align::Culong
end

@cenum ANONYMOUS_ENUM_17::UInt32 begin
        MSG_OOB = 1
        MSG_PEEK = 2
        MSG_DONTROUTE = 4
        MSG_TRYHARD = 4
        MSG_CTRUNC = 8
        MSG_PROXY = 16
        MSG_TRUNC = 32
        MSG_DONTWAIT = 64
        MSG_EOR = 128
        MSG_WAITALL = 256
        MSG_FIN = 512
        MSG_SYN = 1024
        MSG_CONFIRM = 2048
        MSG_RST = 4096
        MSG_ERRQUEUE = 8192
        MSG_NOSIGNAL = 16384
        MSG_MORE = 32768
        MSG_WAITFORONE = 65536
        MSG_BATCH = 262144
        MSG_ZEROCOPY = 67108864
        MSG_FASTOPEN = 536870912
        MSG_CMSG_CLOEXEC = 1073741824
    end

struct msghdr
    msg_name::Ptr{Cvoid}
    msg_namelen::socklen_t
    msg_iov::Ptr{iovec}
    msg_iovlen::Csize_t
    msg_control::Ptr{Cvoid}
    msg_controllen::Csize_t
    msg_flags::Cint
end

mutable struct msghdr_m
    msg_name::Ptr{Cvoid}
    msg_namelen::socklen_t
    msg_iov::Ptr{iovec}
    msg_iovlen::Csize_t
    msg_control::Ptr{Cvoid}
    msg_controllen::Csize_t
    msg_flags::Cint
end

struct cmsghdr
    cmsg_len::Csize_t
    cmsg_level::Cint
    cmsg_type::Cint
    __cmsg_data::Ptr{Cuchar}
end

mutable struct cmsghdr_m
    cmsg_len::Csize_t
    cmsg_level::Cint
    cmsg_type::Cint
    __cmsg_data::Ptr{Cuchar}
end

@cenum ANONYMOUS_ENUM_18::UInt32 begin
        SCM_RIGHTS = 1
        SCM_CREDENTIALS = 2
    end

struct ucred
    pid::pid_t
    uid::uid_t
    gid::gid_t
end

mutable struct ucred_m
    pid::pid_t
    uid::uid_t
    gid::gid_t
end

struct linger
    l_onoff::Cint
    l_linger::Cint
end

mutable struct linger_m
    l_onoff::Cint
    l_linger::Cint
end

struct osockaddr
    sa_family::UInt16
    sa_data::NTuple{14, Cuchar}
end

mutable struct osockaddr_m
    sa_family::UInt16
    sa_data::NTuple{14, Cuchar}
end

@cenum ANONYMOUS_ENUM_19::UInt32 begin
        SHUT_RD = 0
        SHUT_WR = 1
        SHUT_RDWR = 2
    end

struct __SOCKADDR_ARG
    __sockaddr__::Ptr{sockaddr}
end

mutable struct __SOCKADDR_ARG_m
    __sockaddr__::Ptr{sockaddr}
end

struct __CONST_SOCKADDR_ARG
    __sockaddr__::Ptr{sockaddr}
end

mutable struct __CONST_SOCKADDR_ARG_m
    __sockaddr__::Ptr{sockaddr}
end

struct mmsghdr
    msg_hdr::msghdr
    msg_len::UInt32
end

mutable struct mmsghdr_m
    msg_hdr::msghdr
    msg_len::UInt32
end

const sig_atomic_t = __sig_atomic_t

struct ANONYMOUS20__sifields
    _pad::NTuple{29, Cint}
end

mutable struct ANONYMOUS20__sifields_m
    _pad::NTuple{29, Cint}
end

struct siginfo_t
    si_signo::Cint
    si_errno::Cint
    si_code::Cint
    _sifields::ANONYMOUS20__sifields
end

mutable struct siginfo_t_m
    si_signo::Cint
    si_errno::Cint
    si_code::Cint
    _sifields::ANONYMOUS20__sifields
end

@cenum ANONYMOUS_ENUM_21::Int32 begin
        SI_ASYNCNL = -60
        SI_TKILL = -6
        SI_SIGIO = -5
        SI_ASYNCIO = -4
        SI_MESGQ = -3
        SI_TIMER = -2
        SI_QUEUE = -1
        SI_USER = 0
        SI_KERNEL = 128
    end

@cenum ANONYMOUS_ENUM_22::UInt32 begin
        ILL_ILLOPC = 1
        ILL_ILLOPN = 2
        ILL_ILLADR = 3
        ILL_ILLTRP = 4
        ILL_PRVOPC = 5
        ILL_PRVREG = 6
        ILL_COPROC = 7
        ILL_BADSTK = 8
    end

@cenum ANONYMOUS_ENUM_23::UInt32 begin
        FPE_INTDIV = 1
        FPE_INTOVF = 2
        FPE_FLTDIV = 3
        FPE_FLTOVF = 4
        FPE_FLTUND = 5
        FPE_FLTRES = 6
        FPE_FLTINV = 7
        FPE_FLTSUB = 8
    end

@cenum ANONYMOUS_ENUM_24::UInt32 begin
        SEGV_MAPERR = 1
        SEGV_ACCERR = 2
        SEGV_BNDERR = 3
        SEGV_PKUERR = 4
    end

@cenum ANONYMOUS_ENUM_25::UInt32 begin
        BUS_ADRALN = 1
        BUS_ADRERR = 2
        BUS_OBJERR = 3
        BUS_MCEERR_AR = 4
        BUS_MCEERR_AO = 5
    end

@cenum ANONYMOUS_ENUM_26::UInt32 begin
        TRAP_BRKPT = 1
        TRAP_TRACE = 2
    end

@cenum ANONYMOUS_ENUM_27::UInt32 begin
        CLD_EXITED = 1
        CLD_KILLED = 2
        CLD_DUMPED = 3
        CLD_TRAPPED = 4
        CLD_STOPPED = 5
        CLD_CONTINUED = 6
    end

@cenum ANONYMOUS_ENUM_28::UInt32 begin
        POLL_IN = 1
        POLL_OUT = 2
        POLL_MSG = 3
        POLL_ERR = 4
        POLL_PRI = 5
        POLL_HUP = 6
    end

const sigval_t = __sigval_t

const sigevent_t = sigevent

@cenum ANONYMOUS_ENUM_30::UInt32 begin
        SIGEV_SIGNAL = 0
        SIGEV_NONE = 1
        SIGEV_THREAD = 2
        SIGEV_THREAD_ID = 4
    end

const __sighandler_t = Ptr{Cvoid}

const sighandler_t = __sighandler_t

const sig_t = __sighandler_t

struct ANONYMOUS31___sigaction_handler
    sa_handler::__sighandler_t
end

mutable struct ANONYMOUS31___sigaction_handler_m
    sa_handler::__sighandler_t
end

struct sigaction
    __sigaction_handler::ANONYMOUS31___sigaction_handler
    sa_mask::__sigset_t
    sa_flags::Cint
    sa_restorer::Ptr{Cvoid}
end

mutable struct sigaction_m
    __sigaction_handler::ANONYMOUS31___sigaction_handler
    sa_mask::__sigset_t
    sa_flags::Cint
    sa_restorer::Ptr{Cvoid}
end

struct sigcontext
    trap_no::Culong
    error_code::Culong
    oldmask::Culong
    arm_r0::Culong
    arm_r1::Culong
    arm_r2::Culong
    arm_r3::Culong
    arm_r4::Culong
    arm_r5::Culong
    arm_r6::Culong
    arm_r7::Culong
    arm_r8::Culong
    arm_r9::Culong
    arm_r10::Culong
    arm_fp::Culong
    arm_ip::Culong
    arm_sp::Culong
    arm_lr::Culong
    arm_pc::Culong
    arm_cpsr::Culong
    fault_address::Culong
end

mutable struct sigcontext_m
    trap_no::Culong
    error_code::Culong
    oldmask::Culong
    arm_r0::Culong
    arm_r1::Culong
    arm_r2::Culong
    arm_r3::Culong
    arm_r4::Culong
    arm_r5::Culong
    arm_r6::Culong
    arm_r7::Culong
    arm_r8::Culong
    arm_r9::Culong
    arm_r10::Culong
    arm_fp::Culong
    arm_ip::Culong
    arm_sp::Culong
    arm_lr::Culong
    arm_pc::Culong
    arm_cpsr::Culong
    fault_address::Culong
end

struct stack_t
    ss_sp::Ptr{Cvoid}
    ss_flags::Cint
    ss_size::Csize_t
end

mutable struct stack_t_m
    ss_sp::Ptr{Cvoid}
    ss_flags::Cint
    ss_size::Csize_t
end

const greg_t = Cint

const gregset_t = NTuple{18, greg_t}

@cenum ANONYMOUS_ENUM_32::UInt32 begin
        REG_R0 = 0
        REG_R1 = 1
        REG_R2 = 2
        REG_R3 = 3
        REG_R4 = 4
        REG_R5 = 5
        REG_R6 = 6
        REG_R7 = 7
        REG_R8 = 8
        REG_R9 = 9
        REG_R10 = 10
        REG_R11 = 11
        REG_R12 = 12
        REG_R13 = 13
        REG_R14 = 14
        REG_R15 = 15
    end

struct ANONYMOUS33_fpregs
    sign1::UInt32
    unused::UInt32
    sign2::UInt32
    exponent::UInt32
    j::UInt32
    mantissa1::UInt32
    mantissa0::UInt32
end

mutable struct ANONYMOUS33_fpregs_m
    sign1::UInt32
    unused::UInt32
    sign2::UInt32
    exponent::UInt32
    j::UInt32
    mantissa1::UInt32
    mantissa0::UInt32
end

struct _libc_fpstate
    fpregs::ANONYMOUS33_fpregs
    fpsr::UInt32
    fpcr::UInt32
    ftype::NTuple{8, Cuchar}
    init_flag::UInt32
end

mutable struct _libc_fpstate_m
    fpregs::ANONYMOUS33_fpregs
    fpsr::UInt32
    fpcr::UInt32
    ftype::NTuple{8, Cuchar}
    init_flag::UInt32
end

const fpregset_t = _libc_fpstate

struct mcontext_t
    trap_no::Culong
    error_code::Culong
    oldmask::Culong
    arm_r0::Culong
    arm_r1::Culong
    arm_r2::Culong
    arm_r3::Culong
    arm_r4::Culong
    arm_r5::Culong
    arm_r6::Culong
    arm_r7::Culong
    arm_r8::Culong
    arm_r9::Culong
    arm_r10::Culong
    arm_fp::Culong
    arm_ip::Culong
    arm_sp::Culong
    arm_lr::Culong
    arm_pc::Culong
    arm_cpsr::Culong
    fault_address::Culong
end

mutable struct mcontext_t_m
    trap_no::Culong
    error_code::Culong
    oldmask::Culong
    arm_r0::Culong
    arm_r1::Culong
    arm_r2::Culong
    arm_r3::Culong
    arm_r4::Culong
    arm_r5::Culong
    arm_r6::Culong
    arm_r7::Culong
    arm_r8::Culong
    arm_r9::Culong
    arm_r10::Culong
    arm_fp::Culong
    arm_ip::Culong
    arm_sp::Culong
    arm_lr::Culong
    arm_pc::Culong
    arm_cpsr::Culong
    fault_address::Culong
end

struct ucontext_t
    uc_flags::Culong
    uc_link::Ptr{ucontext_t}
    uc_stack::stack_t
    uc_mcontext::mcontext_t
    uc_sigmask::sigset_t
    uc_regspace::NTuple{128, Culong}
end

mutable struct ucontext_t_m
    uc_flags::Culong
    uc_link::Ptr{ucontext_t}
    uc_stack::stack_t
    uc_mcontext::mcontext_t
    uc_sigmask::sigset_t
    uc_regspace::NTuple{128, Culong}
end

@cenum ANONYMOUS_ENUM_34::UInt32 begin
        SS_ONSTACK = 1
        SS_DISABLE = 2
    end

struct sigstack
    ss_sp::Ptr{Cvoid}
    ss_onstack::Cint
end

mutable struct sigstack_m
    ss_sp::Ptr{Cvoid}
    ss_onstack::Cint
end

const WAIT_ANY = -1

struct ANONYMOUS35__sifields
    _pad::NTuple{29, Cint}
end

mutable struct ANONYMOUS35__sifields_m
    _pad::NTuple{29, Cint}
end

struct ANONYMOUS44__sigev_un
    _pad::NTuple{13, Cint}
end

mutable struct ANONYMOUS44__sigev_un_m
    _pad::NTuple{13, Cint}
end

struct ANONYMOUS46___sigaction_handler
    sa_handler::__sighandler_t
end

mutable struct ANONYMOUS46___sigaction_handler_m
    sa_handler::__sighandler_t
end

struct ANONYMOUS48_fpregs
    sign1::UInt32
    unused::UInt32
    sign2::UInt32
    exponent::UInt32
    j::UInt32
    mantissa1::UInt32
    mantissa0::UInt32
end

mutable struct ANONYMOUS48_fpregs_m
    sign1::UInt32
    unused::UInt32
    sign2::UInt32
    exponent::UInt32
    j::UInt32
    mantissa1::UInt32
    mantissa0::UInt32
end

const rusage = Cvoid

struct posix_spawnattr_t
    __flags::Int16
    __pgrp::pid_t
    __sd::sigset_t
    __ss::sigset_t
    __sp::sched_param
    __policy::Cint
    __pad::NTuple{16, Cint}
end

mutable struct posix_spawnattr_t_m
    __flags::Int16
    __pgrp::pid_t
    __sd::sigset_t
    __ss::sigset_t
    __sp::sched_param
    __policy::Cint
    __pad::NTuple{16, Cint}
end

struct posix_spawn_file_actions_t
    __allocated::Cint
    __used::Cint
    __actions::Ptr{__spawn_action}
    __pad::NTuple{16, Cint}
end

mutable struct posix_spawn_file_actions_t_m
    __allocated::Cint
    __used::Cint
    __actions::Ptr{__spawn_action}
    __pad::NTuple{16, Cint}
end

function __errno_location()
    ccall(:__errno_location, Ptr{Cint}, ())
end

function memcpy(__dest, __src, __n)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt32), __dest, __src, __n)
end

function memmove(__dest, __src, __n)
    ccall(:memmove, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt32), __dest, __src, __n)
end

function memccpy(__dest, __src, __c, __n)
    ccall(:memccpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Csize_t), __dest, __src, __c, __n)
end

function memset(__s, __c, __n)
    ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, UInt32), __s, __c, __n)
end

function memcmp(__s1, __s2, __n)
    ccall(:memcmp, Cint, (Ptr{Cvoid}, Ptr{Cvoid}, UInt32), __s1, __s2, __n)
end

function memchr(__s, __c, __n)
    ccall(:memchr, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, UInt32), __s, __c, __n)
end

function rawmemchr(__s, __c)
    ccall(:rawmemchr, Ptr{Cvoid}, (Ptr{Cvoid}, Cint), __s, __c)
end

function memrchr(__s, __c, __n)
    ccall(:memrchr, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t), __s, __c, __n)
end

function strcpy(__dest, __src)
    ccall(:strcpy, Cstring, (Cstring, Cstring), __dest, __src)
end

function strncpy(__dest, __src, __n)
    ccall(:strncpy, Cstring, (Cstring, Cstring, UInt32), __dest, __src, __n)
end

function strcat(__dest, __src)
    ccall(:strcat, Cstring, (Cstring, Cstring), __dest, __src)
end

function strncat(__dest, __src, __n)
    ccall(:strncat, Cstring, (Cstring, Cstring, UInt32), __dest, __src, __n)
end

function strcmp(__s1, __s2)
    ccall(:strcmp, Cint, (Cstring, Cstring), __s1, __s2)
end

function strncmp(__s1, __s2, __n)
    ccall(:strncmp, Cint, (Cstring, Cstring, UInt32), __s1, __s2, __n)
end

function strcoll(__s1, __s2)
    ccall(:strcoll, Cint, (Cstring, Cstring), __s1, __s2)
end

function strxfrm(__dest, __src, __n)
    ccall(:strxfrm, UInt32, (Cstring, Cstring, UInt32), __dest, __src, __n)
end

function strcoll_l(__s1, __s2, __l)
    ccall(:strcoll_l, Cint, (Cstring, Cstring, locale_t), __s1, __s2, __l)
end

function strxfrm_l(__dest, __src, __n, __l)
    ccall(:strxfrm_l, Csize_t, (Cstring, Cstring, Csize_t, locale_t), __dest, __src, __n, __l)
end

function strdup(__s)
    ccall(:strdup, Cstring, (Cstring,), __s)
end

function strndup(__string, __n)
    ccall(:strndup, Cstring, (Cstring, UInt32), __string, __n)
end

function strchr(__s, __c)
    ccall(:strchr, Cstring, (Cstring, Cint), __s, __c)
end

function strrchr(__s, __c)
    ccall(:strrchr, Cstring, (Cstring, Cint), __s, __c)
end

function strchrnul(__s, __c)
    ccall(:strchrnul, Cstring, (Cstring, Cint), __s, __c)
end

function strcspn(__s, __reject)
    ccall(:strcspn, UInt32, (Cstring, Cstring), __s, __reject)
end

function strspn(__s, __accept)
    ccall(:strspn, UInt32, (Cstring, Cstring), __s, __accept)
end

function strpbrk(__s, __accept)
    ccall(:strpbrk, Cstring, (Cstring, Cstring), __s, __accept)
end

function strstr(__haystack, __needle)
    ccall(:strstr, Cstring, (Cstring, Cstring), __haystack, __needle)
end

function strtok(__s, __delim)
    ccall(:strtok, Cstring, (Cstring, Cstring), __s, __delim)
end

function __strtok_r(__s, __delim, __save_ptr)
    ccall(:__strtok_r, Cstring, (Cstring, Cstring, Ptr{Cstring}), __s, __delim, __save_ptr)
end

function strtok_r(__s, __delim, __save_ptr)
    ccall(:strtok_r, Cstring, (Cstring, Cstring, Ptr{Cstring}), __s, __delim, __save_ptr)
end

function strcasestr(__haystack, __needle)
    ccall(:strcasestr, Cstring, (Cstring, Cstring), __haystack, __needle)
end

function memmem(__haystack, __haystacklen, __needle, __needlelen)
    ccall(:memmem, Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t), __haystack, __haystacklen, __needle, __needlelen)
end

function __mempcpy(__dest, __src, __n)
    ccall(:__mempcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), __dest, __src, __n)
end

function mempcpy(__dest, __src, __n)
    ccall(:mempcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), __dest, __src, __n)
end

function strlen(__s)
    ccall(:strlen, UInt32, (Cstring,), __s)
end

function strnlen(__string, __maxlen)
    ccall(:strnlen, Csize_t, (Cstring, Csize_t), __string, __maxlen)
end

function strerror(__errnum)
    ccall(:strerror, Cstring, (Cint,), __errnum)
end

function strerror_r(__errnum, __buf, __buflen)
    ccall(:strerror_r, Cstring, (Cint, Cstring, Csize_t), __errnum, __buf, __buflen)
end

function strerror_l(__errnum, __l)
    ccall(:strerror_l, Cstring, (Cint, locale_t), __errnum, __l)
end

function bcmp(__s1, __s2, __n)
    ccall(:bcmp, Cint, (Ptr{Cvoid}, Ptr{Cvoid}, UInt32), __s1, __s2, __n)
end

function bcopy(__src, __dest, __n)
    ccall(:bcopy, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), __src, __dest, __n)
end

function bzero(__s, __n)
    ccall(:bzero, Cvoid, (Ptr{Cvoid}, UInt32), __s, __n)
end

function index(__s, __c)
    ccall(:index, Cstring, (Cstring, Cint), __s, __c)
end

function rindex(__s, __c)
    ccall(:rindex, Cstring, (Cstring, Cint), __s, __c)
end

function ffs(__i)
    ccall(:ffs, Cint, (Cint,), __i)
end

function ffsl(__l)
    ccall(:ffsl, Cint, (Clong,), __l)
end

function ffsll(__ll)
    ccall(:ffsll, Cint, (Clonglong,), __ll)
end

function strcasecmp(__s1, __s2)
    ccall(:strcasecmp, Cint, (Cstring, Cstring), __s1, __s2)
end

function strncasecmp(__s1, __s2, __n)
    ccall(:strncasecmp, Cint, (Cstring, Cstring, UInt32), __s1, __s2, __n)
end

function strcasecmp_l(__s1, __s2, __loc)
    ccall(:strcasecmp_l, Cint, (Cstring, Cstring, locale_t), __s1, __s2, __loc)
end

function strncasecmp_l(__s1, __s2, __n, __loc)
    ccall(:strncasecmp_l, Cint, (Cstring, Cstring, Csize_t, locale_t), __s1, __s2, __n, __loc)
end

function explicit_bzero(__s, __n)
    ccall(:explicit_bzero, Cvoid, (Ptr{Cvoid}, Csize_t), __s, __n)
end

function strsep(__stringp, __delim)
    ccall(:strsep, Cstring, (Ptr{Cstring}, Cstring), __stringp, __delim)
end

function strsignal(__sig)
    ccall(:strsignal, Cstring, (Cint,), __sig)
end

function __stpcpy(__dest, __src)
    ccall(:__stpcpy, Cstring, (Cstring, Cstring), __dest, __src)
end

function stpcpy(__dest, __src)
    ccall(:stpcpy, Cstring, (Cstring, Cstring), __dest, __src)
end

function __stpncpy(__dest, __src, __n)
    ccall(:__stpncpy, Cstring, (Cstring, Cstring, Csize_t), __dest, __src, __n)
end

function stpncpy(__dest, __src, __n)
    ccall(:stpncpy, Cstring, (Cstring, Cstring, UInt32), __dest, __src, __n)
end

function strverscmp(__s1, __s2)
    ccall(:strverscmp, Cint, (Cstring, Cstring), __s1, __s2)
end

function strfry(__string)
    ccall(:strfry, Cstring, (Cstring,), __string)
end

function memfrob(__s, __n)
    ccall(:memfrob, Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t), __s, __n)
end

function basename(__filename)
    ccall(:basename, Cstring, (Cstring,), __filename)
end

function __ctype_get_mb_cur_max()
    ccall(:__ctype_get_mb_cur_max, Csize_t, ())
end

function atof(__nptr)
    ccall(:atof, Cdouble, (Cstring,), __nptr)
end

function atoi(__nptr)
    ccall(:atoi, Cint, (Cstring,), __nptr)
end

function atol(__nptr)
    ccall(:atol, Clong, (Cstring,), __nptr)
end

function atoll(__nptr)
    ccall(:atoll, Clonglong, (Cstring,), __nptr)
end

function strtod(__nptr, __endptr)
    ccall(:strtod, Cdouble, (Cstring, Ptr{Cstring}), __nptr, __endptr)
end

function strtof(__nptr, __endptr)
    ccall(:strtof, Cfloat, (Cstring, Ptr{Cstring}), __nptr, __endptr)
end

function strtold(__nptr, __endptr)
    ccall(:strtold, Float64, (Cstring, Ptr{Cstring}), __nptr, __endptr)
end

function strtof32(__nptr, __endptr)
    ccall(:strtof32, _Float32, (Cstring, Ptr{Cstring}), __nptr, __endptr)
end

function strtof64(__nptr, __endptr)
    ccall(:strtof64, _Float64, (Cstring, Ptr{Cstring}), __nptr, __endptr)
end

function strtof32x(__nptr, __endptr)
    ccall(:strtof32x, _Float32x, (Cstring, Ptr{Cstring}), __nptr, __endptr)
end

function strtol(__nptr, __endptr, __base)
    ccall(:strtol, Clong, (Cstring, Ptr{Cstring}, Cint), __nptr, __endptr, __base)
end

function strtoul(__nptr, __endptr, __base)
    ccall(:strtoul, Culong, (Cstring, Ptr{Cstring}, Cint), __nptr, __endptr, __base)
end

function strtoq(__nptr, __endptr, __base)
    ccall(:strtoq, Clonglong, (Cstring, Ptr{Cstring}, Cint), __nptr, __endptr, __base)
end

function strtouq(__nptr, __endptr, __base)
    ccall(:strtouq, Culonglong, (Cstring, Ptr{Cstring}, Cint), __nptr, __endptr, __base)
end

function strtoll(__nptr, __endptr, __base)
    ccall(:strtoll, Clonglong, (Cstring, Ptr{Cstring}, Cint), __nptr, __endptr, __base)
end

function strtoull(__nptr, __endptr, __base)
    ccall(:strtoull, Culonglong, (Cstring, Ptr{Cstring}, Cint), __nptr, __endptr, __base)
end

function strfromd(__dest, __size, __format, __f)
    ccall(:strfromd, Cint, (Cstring, Csize_t, Cstring, Cdouble), __dest, __size, __format, __f)
end

function strfromf(__dest, __size, __format, __f)
    ccall(:strfromf, Cint, (Cstring, Csize_t, Cstring, Cfloat), __dest, __size, __format, __f)
end

function strfroml(__dest, __size, __format, __f)
    ccall(:strfroml, Cint, (Cstring, Csize_t, Cstring, Float64), __dest, __size, __format, __f)
end

function strfromf32(__dest, __size, __format, __f)
    ccall(:strfromf32, Cint, (Cstring, Csize_t, Cstring, _Float32), __dest, __size, __format, __f)
end

function strfromf64(__dest, __size, __format, __f)
    ccall(:strfromf64, Cint, (Cstring, Csize_t, Cstring, _Float64), __dest, __size, __format, __f)
end

function strfromf32x(__dest, __size, __format, __f)
    ccall(:strfromf32x, Cint, (Cstring, Csize_t, Cstring, _Float32x), __dest, __size, __format, __f)
end

function strtol_l(__nptr, __endptr, __base, __loc)
    ccall(:strtol_l, Clong, (Cstring, Ptr{Cstring}, Cint, locale_t), __nptr, __endptr, __base, __loc)
end

function strtoul_l(__nptr, __endptr, __base, __loc)
    ccall(:strtoul_l, Culong, (Cstring, Ptr{Cstring}, Cint, locale_t), __nptr, __endptr, __base, __loc)
end

function strtoll_l(__nptr, __endptr, __base, __loc)
    ccall(:strtoll_l, Clonglong, (Cstring, Ptr{Cstring}, Cint, locale_t), __nptr, __endptr, __base, __loc)
end

function strtoull_l(__nptr, __endptr, __base, __loc)
    ccall(:strtoull_l, Culonglong, (Cstring, Ptr{Cstring}, Cint, locale_t), __nptr, __endptr, __base, __loc)
end

function strtod_l(__nptr, __endptr, __loc)
    ccall(:strtod_l, Cdouble, (Cstring, Ptr{Cstring}, locale_t), __nptr, __endptr, __loc)
end

function strtof_l(__nptr, __endptr, __loc)
    ccall(:strtof_l, Cfloat, (Cstring, Ptr{Cstring}, locale_t), __nptr, __endptr, __loc)
end

function strtold_l(__nptr, __endptr, __loc)
    ccall(:strtold_l, Float64, (Cstring, Ptr{Cstring}, locale_t), __nptr, __endptr, __loc)
end

function strtof32_l(__nptr, __endptr, __loc)
    ccall(:strtof32_l, _Float32, (Cstring, Ptr{Cstring}, locale_t), __nptr, __endptr, __loc)
end

function strtof64_l(__nptr, __endptr, __loc)
    ccall(:strtof64_l, _Float64, (Cstring, Ptr{Cstring}, locale_t), __nptr, __endptr, __loc)
end

function strtof32x_l(__nptr, __endptr, __loc)
    ccall(:strtof32x_l, _Float32x, (Cstring, Ptr{Cstring}, locale_t), __nptr, __endptr, __loc)
end

function l64a(__n)
    ccall(:l64a, Cstring, (Clong,), __n)
end

function a64l(__s)
    ccall(:a64l, Clong, (Cstring,), __s)
end

function __bswap_16(__bsx)
    ccall(:__bswap_16, __uint16_t, (__uint16_t,), __bsx)
end

function __bswap_32(__bsx)
    ccall(:__bswap_32, __uint32_t, (__uint32_t,), __bsx)
end

function __bswap_64(__bsx)
    ccall(:__bswap_64, __uint64_t, (__uint64_t,), __bsx)
end

function __uint16_identity(__x)
    ccall(:__uint16_identity, __uint16_t, (__uint16_t,), __x)
end

function __uint32_identity(__x)
    ccall(:__uint32_identity, __uint32_t, (__uint32_t,), __x)
end

function __uint64_identity(__x)
    ccall(:__uint64_identity, __uint64_t, (__uint64_t,), __x)
end

function select(__nfds, __readfds, __writefds, __exceptfds, __timeout)
    ccall(:select, Cint, (Cint, Ptr{fd_set}, Ptr{fd_set}, Ptr{fd_set}, Ptr{timeval}), __nfds, __readfds, __writefds, __exceptfds, __timeout)
end

function pselect(__nfds, __readfds, __writefds, __exceptfds, __timeout, __sigmask)
    ccall(:pselect, Cint, (Cint, Ptr{fd_set}, Ptr{fd_set}, Ptr{fd_set}, Ptr{timespec}, Ptr{__sigset_t}), __nfds, __readfds, __writefds, __exceptfds, __timeout, __sigmask)
end

function random()
    ccall(:random, Clong, ())
end

function srandom(__seed)
    ccall(:srandom, Cvoid, (UInt32,), __seed)
end

function initstate(__seed, __statebuf, __statelen)
    ccall(:initstate, Cstring, (UInt32, Cstring, Csize_t), __seed, __statebuf, __statelen)
end

function setstate(__statebuf)
    ccall(:setstate, Cstring, (Cstring,), __statebuf)
end

function random_r(__buf, __result)
    ccall(:random_r, Cint, (Ptr{random_data}, Ptr{Int32}), __buf, __result)
end

function srandom_r(__seed, __buf)
    ccall(:srandom_r, Cint, (UInt32, Ptr{random_data}), __seed, __buf)
end

function initstate_r(__seed, __statebuf, __statelen, __buf)
    ccall(:initstate_r, Cint, (UInt32, Cstring, Csize_t, Ptr{random_data}), __seed, __statebuf, __statelen, __buf)
end

function setstate_r(__statebuf, __buf)
    ccall(:setstate_r, Cint, (Cstring, Ptr{random_data}), __statebuf, __buf)
end

function rand()
    ccall(:rand, Cint, ())
end

function srand(__seed)
    ccall(:srand, Cvoid, (UInt32,), __seed)
end

function rand_r(__seed)
    ccall(:rand_r, Cint, (Ptr{UInt32},), __seed)
end

function drand48()
    ccall(:drand48, Cdouble, ())
end

function erand48(__xsubi)
    ccall(:erand48, Cdouble, (Ptr{UInt16},), __xsubi)
end

function lrand48()
    ccall(:lrand48, Clong, ())
end

function nrand48(__xsubi)
    ccall(:nrand48, Clong, (Ptr{UInt16},), __xsubi)
end

function mrand48()
    ccall(:mrand48, Clong, ())
end

function jrand48(__xsubi)
    ccall(:jrand48, Clong, (Ptr{UInt16},), __xsubi)
end

function srand48(__seedval)
    ccall(:srand48, Cvoid, (Clong,), __seedval)
end

function seed48(__seed16v)
    ccall(:seed48, Ptr{UInt16}, (Ptr{UInt16},), __seed16v)
end

function lcong48(__param)
    ccall(:lcong48, Cvoid, (Ptr{UInt16},), __param)
end

function drand48_r(__buffer, __result)
    ccall(:drand48_r, Cint, (Ptr{drand48_data}, Ptr{Cdouble}), __buffer, __result)
end

function erand48_r(__xsubi, __buffer, __result)
    ccall(:erand48_r, Cint, (Ptr{UInt16}, Ptr{drand48_data}, Ptr{Cdouble}), __xsubi, __buffer, __result)
end

function lrand48_r(__buffer, __result)
    ccall(:lrand48_r, Cint, (Ptr{drand48_data}, Ptr{Clong}), __buffer, __result)
end

function nrand48_r(__xsubi, __buffer, __result)
    ccall(:nrand48_r, Cint, (Ptr{UInt16}, Ptr{drand48_data}, Ptr{Clong}), __xsubi, __buffer, __result)
end

function mrand48_r(__buffer, __result)
    ccall(:mrand48_r, Cint, (Ptr{drand48_data}, Ptr{Clong}), __buffer, __result)
end

function jrand48_r(__xsubi, __buffer, __result)
    ccall(:jrand48_r, Cint, (Ptr{UInt16}, Ptr{drand48_data}, Ptr{Clong}), __xsubi, __buffer, __result)
end

function srand48_r(__seedval, __buffer)
    ccall(:srand48_r, Cint, (Clong, Ptr{drand48_data}), __seedval, __buffer)
end

function seed48_r(__seed16v, __buffer)
    ccall(:seed48_r, Cint, (Ptr{UInt16}, Ptr{drand48_data}), __seed16v, __buffer)
end

function lcong48_r(__param, __buffer)
    ccall(:lcong48_r, Cint, (Ptr{UInt16}, Ptr{drand48_data}), __param, __buffer)
end

function malloc(__size)
    ccall(:malloc, Ptr{Cvoid}, (UInt32,), __size)
end

function calloc(__nmemb, __size)
    ccall(:calloc, Ptr{Cvoid}, (UInt32, UInt32), __nmemb, __size)
end

function realloc(__ptr, __size)
    ccall(:realloc, Ptr{Cvoid}, (Ptr{Cvoid}, UInt32), __ptr, __size)
end

function reallocarray(__ptr, __nmemb, __size)
    ccall(:reallocarray, Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t, Csize_t), __ptr, __nmemb, __size)
end

function free(__ptr)
    ccall(:free, Cvoid, (Ptr{Cvoid},), __ptr)
end

function alloca(__size)
    ccall(:alloca, Ptr{Cvoid}, (UInt32,), __size)
end

function valloc(__size)
    ccall(:valloc, Ptr{Cvoid}, (Csize_t,), __size)
end

function posix_memalign(__memptr, __alignment, __size)
    ccall(:posix_memalign, Cint, (Ptr{Ptr{Cvoid}}, Csize_t, Csize_t), __memptr, __alignment, __size)
end

function aligned_alloc(__alignment, __size)
    ccall(:aligned_alloc, Ptr{Cvoid}, (Csize_t, Csize_t), __alignment, __size)
end

function abort()
    ccall(:abort, Cvoid, ())
end

function atexit(__func)
    ccall(:atexit, Cint, (Ptr{Cvoid},), __func)
end

function at_quick_exit(__func)
    ccall(:at_quick_exit, Cint, (Ptr{Cvoid},), __func)
end

function on_exit(__func, __arg)
    ccall(:on_exit, Cint, (Ptr{Cvoid}, Ptr{Cvoid}), __func, __arg)
end

function exit(__status)
    ccall(:exit, Cvoid, (Cint,), __status)
end

function quick_exit(__status)
    ccall(:quick_exit, Cvoid, (Cint,), __status)
end

function _Exit(__status)
    ccall(:_Exit, Cvoid, (Cint,), __status)
end

function getenv(__name)
    ccall(:getenv, Cstring, (Cstring,), __name)
end

function secure_getenv(__name)
    ccall(:secure_getenv, Cstring, (Cstring,), __name)
end

function putenv(__string)
    ccall(:putenv, Cint, (Cstring,), __string)
end

function setenv(__name, __value, __replace)
    ccall(:setenv, Cint, (Cstring, Cstring, Cint), __name, __value, __replace)
end

function unsetenv(__name)
    ccall(:unsetenv, Cint, (Cstring,), __name)
end

function clearenv()
    ccall(:clearenv, Cint, ())
end

function mktemp(__template)
    ccall(:mktemp, Cstring, (Cstring,), __template)
end

function mkstemp(__template)
    ccall(:mkstemp, Cint, (Cstring,), __template)
end

function mkstemp64(__template)
    ccall(:mkstemp64, Cint, (Cstring,), __template)
end

function mkstemps(__template, __suffixlen)
    ccall(:mkstemps, Cint, (Cstring, Cint), __template, __suffixlen)
end

function mkstemps64(__template, __suffixlen)
    ccall(:mkstemps64, Cint, (Cstring, Cint), __template, __suffixlen)
end

function mkdtemp(__template)
    ccall(:mkdtemp, Cstring, (Cstring,), __template)
end

function mkostemp(__template, __flags)
    ccall(:mkostemp, Cint, (Cstring, Cint), __template, __flags)
end

function mkostemp64(__template, __flags)
    ccall(:mkostemp64, Cint, (Cstring, Cint), __template, __flags)
end

function mkostemps(__template, __suffixlen, __flags)
    ccall(:mkostemps, Cint, (Cstring, Cint, Cint), __template, __suffixlen, __flags)
end

function mkostemps64(__template, __suffixlen, __flags)
    ccall(:mkostemps64, Cint, (Cstring, Cint, Cint), __template, __suffixlen, __flags)
end

function system(__command)
    ccall(:system, Cint, (Cstring,), __command)
end

function canonicalize_file_name(__name)
    ccall(:canonicalize_file_name, Cstring, (Cstring,), __name)
end

function realpath(__name, __resolved)
    ccall(:realpath, Cstring, (Cstring, Cstring), __name, __resolved)
end

function bsearch(__key, __base, __nmemb, __size, __compar)
    ccall(:bsearch, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Csize_t, __compar_fn_t), __key, __base, __nmemb, __size, __compar)
end

function qsort(__base, __nmemb, __size, __compar)
    ccall(:qsort, Cvoid, (Ptr{Cvoid}, Csize_t, Csize_t, __compar_fn_t), __base, __nmemb, __size, __compar)
end

function qsort_r(__base, __nmemb, __size, __compar, __arg)
    ccall(:qsort_r, Cvoid, (Ptr{Cvoid}, Csize_t, Csize_t, __compar_d_fn_t, Ptr{Cvoid}), __base, __nmemb, __size, __compar, __arg)
end

function abs(__x)
    ccall(:abs, Cint, (Cint,), __x)
end

function labs(__x)
    ccall(:labs, Clong, (Clong,), __x)
end

function llabs(__x)
    ccall(:llabs, Clonglong, (Clonglong,), __x)
end

function div(__numer, __denom)
    ccall(:div, div_t, (Cint, Cint), __numer, __denom)
end

function ldiv(__numer, __denom)
    ccall(:ldiv, ldiv_t, (Clong, Clong), __numer, __denom)
end

function lldiv(__numer, __denom)
    ccall(:lldiv, lldiv_t, (Clonglong, Clonglong), __numer, __denom)
end

function ecvt(__value, __ndigit, __decpt, __sign)
    ccall(:ecvt, Cstring, (Cdouble, Cint, Ptr{Cint}, Ptr{Cint}), __value, __ndigit, __decpt, __sign)
end

function fcvt(__value, __ndigit, __decpt, __sign)
    ccall(:fcvt, Cstring, (Cdouble, Cint, Ptr{Cint}, Ptr{Cint}), __value, __ndigit, __decpt, __sign)
end

function gcvt(__value, __ndigit, __buf)
    ccall(:gcvt, Cstring, (Cdouble, Cint, Cstring), __value, __ndigit, __buf)
end

function qecvt(__value, __ndigit, __decpt, __sign)
    ccall(:qecvt, Cstring, (Float64, Cint, Ptr{Cint}, Ptr{Cint}), __value, __ndigit, __decpt, __sign)
end

function qfcvt(__value, __ndigit, __decpt, __sign)
    ccall(:qfcvt, Cstring, (Float64, Cint, Ptr{Cint}, Ptr{Cint}), __value, __ndigit, __decpt, __sign)
end

function qgcvt(__value, __ndigit, __buf)
    ccall(:qgcvt, Cstring, (Float64, Cint, Cstring), __value, __ndigit, __buf)
end

function ecvt_r(__value, __ndigit, __decpt, __sign, __buf, __len)
    ccall(:ecvt_r, Cint, (Cdouble, Cint, Ptr{Cint}, Ptr{Cint}, Cstring, Csize_t), __value, __ndigit, __decpt, __sign, __buf, __len)
end

function fcvt_r(__value, __ndigit, __decpt, __sign, __buf, __len)
    ccall(:fcvt_r, Cint, (Cdouble, Cint, Ptr{Cint}, Ptr{Cint}, Cstring, Csize_t), __value, __ndigit, __decpt, __sign, __buf, __len)
end

function qecvt_r(__value, __ndigit, __decpt, __sign, __buf, __len)
    ccall(:qecvt_r, Cint, (Float64, Cint, Ptr{Cint}, Ptr{Cint}, Cstring, Csize_t), __value, __ndigit, __decpt, __sign, __buf, __len)
end

function qfcvt_r(__value, __ndigit, __decpt, __sign, __buf, __len)
    ccall(:qfcvt_r, Cint, (Float64, Cint, Ptr{Cint}, Ptr{Cint}, Cstring, Csize_t), __value, __ndigit, __decpt, __sign, __buf, __len)
end

function mblen(__s, __n)
    ccall(:mblen, Cint, (Cstring, Csize_t), __s, __n)
end

function mbtowc(__pwc, __s, __n)
    ccall(:mbtowc, Cint, (Ptr{Cwchar_t}, Cstring, Csize_t), __pwc, __s, __n)
end

function wctomb(__s, __wchar)
    ccall(:wctomb, Cint, (Cstring, Cwchar_t), __s, __wchar)
end

function mbstowcs(__pwcs, __s, __n)
    ccall(:mbstowcs, Csize_t, (Ptr{Cwchar_t}, Cstring, Csize_t), __pwcs, __s, __n)
end

function wcstombs(__s, __pwcs, __n)
    ccall(:wcstombs, Csize_t, (Cstring, Ptr{Cwchar_t}, Csize_t), __s, __pwcs, __n)
end

function rpmatch(__response)
    ccall(:rpmatch, Cint, (Cstring,), __response)
end

function getsubopt(__optionp, __tokens, __valuep)
    ccall(:getsubopt, Cint, (Ptr{Cstring}, Ptr{Cstring}, Ptr{Cstring}), __optionp, __tokens, __valuep)
end

function posix_openpt(__oflag)
    ccall(:posix_openpt, Cint, (Cint,), __oflag)
end

function grantpt(__fd)
    ccall(:grantpt, Cint, (Cint,), __fd)
end

function unlockpt(__fd)
    ccall(:unlockpt, Cint, (Cint,), __fd)
end

function ptsname(__fd)
    ccall(:ptsname, Cstring, (Cint,), __fd)
end

function ptsname_r(__fd, __buf, __buflen)
    ccall(:ptsname_r, Cint, (Cint, Cstring, Csize_t), __fd, __buf, __buflen)
end

function getpt()
    ccall(:getpt, Cint, ())
end

function getloadavg(__loadavg, __nelem)
    ccall(:getloadavg, Cint, (Ptr{Cdouble}, Cint), __loadavg, __nelem)
end

function unshare(__flags)
    ccall(:unshare, Cint, (Cint,), __flags)
end

function sched_getcpu()
    ccall(:sched_getcpu, Cint, ())
end

function setns(__fd, __nstype)
    ccall(:setns, Cint, (Cint, Cint), __fd, __nstype)
end

function __sched_cpucount(__setsize, __setp)
    ccall(:__sched_cpucount, Cint, (Csize_t, Ptr{cpu_set_t}), __setsize, __setp)
end

function __sched_cpualloc(__count)
    ccall(:__sched_cpualloc, Ptr{cpu_set_t}, (Csize_t,), __count)
end

function __sched_cpufree(__set)
    ccall(:__sched_cpufree, Cvoid, (Ptr{cpu_set_t},), __set)
end

function sched_setparam(__pid, __param)
    ccall(:sched_setparam, Cint, (__pid_t, Ptr{sched_param}), __pid, __param)
end

function sched_getparam(__pid, __param)
    ccall(:sched_getparam, Cint, (__pid_t, Ptr{sched_param}), __pid, __param)
end

function sched_setscheduler(__pid, __policy, __param)
    ccall(:sched_setscheduler, Cint, (__pid_t, Cint, Ptr{sched_param}), __pid, __policy, __param)
end

function sched_getscheduler(__pid)
    ccall(:sched_getscheduler, Cint, (__pid_t,), __pid)
end

function sched_yield()
    ccall(:sched_yield, Cint, ())
end

function sched_get_priority_max(__algorithm)
    ccall(:sched_get_priority_max, Cint, (Cint,), __algorithm)
end

function sched_get_priority_min(__algorithm)
    ccall(:sched_get_priority_min, Cint, (Cint,), __algorithm)
end

function sched_rr_get_interval(__pid, __t)
    ccall(:sched_rr_get_interval, Cint, (__pid_t, Ptr{timespec}), __pid, __t)
end

function sched_setaffinity(__pid, __cpusetsize, __cpuset)
    ccall(:sched_setaffinity, Cint, (__pid_t, Csize_t, Ptr{cpu_set_t}), __pid, __cpusetsize, __cpuset)
end

function sched_getaffinity(__pid, __cpusetsize, __cpuset)
    ccall(:sched_getaffinity, Cint, (__pid_t, Csize_t, Ptr{cpu_set_t}), __pid, __cpusetsize, __cpuset)
end

function clock()
    ccall(:clock, Cclock_t, ())
end

function time(__timer)
    ccall(:time, Ctime_t, (Ptr{Ctime_t},), __timer)
end

function difftime(__time1, __time0)
    ccall(:difftime, Cdouble, (Ctime_t, Ctime_t), __time1, __time0)
end

function mktime(__tp)
    ccall(:mktime, Ctime_t, (Ptr{Ctm},), __tp)
end

function strftime(__s, __maxsize, __format, __tp)
    ccall(:strftime, Csize_t, (Cstring, Csize_t, Cstring, Ptr{Ctm}), __s, __maxsize, __format, __tp)
end

function strptime(__s, __fmt, __tp)
    ccall(:strptime, Cstring, (Cstring, Cstring, Ptr{Ctm}), __s, __fmt, __tp)
end

function strftime_l(__s, __maxsize, __format, __tp, __loc)
    ccall(:strftime_l, Csize_t, (Cstring, Csize_t, Cstring, Ptr{Ctm}, locale_t), __s, __maxsize, __format, __tp, __loc)
end

function strptime_l(__s, __fmt, __tp, __loc)
    ccall(:strptime_l, Cstring, (Cstring, Cstring, Ptr{Ctm}, locale_t), __s, __fmt, __tp, __loc)
end

function gmtime(__timer)
    ccall(:gmtime, Ptr{Ctm}, (Ptr{Ctime_t},), __timer)
end

function localtime(__timer)
    ccall(:localtime, Ptr{Ctm}, (Ptr{Ctime_t},), __timer)
end

function gmtime_r(__timer, __tp)
    ccall(:gmtime_r, Ptr{Ctm}, (Ptr{Ctime_t}, Ptr{Ctm}), __timer, __tp)
end

function localtime_r(__timer, __tp)
    ccall(:localtime_r, Ptr{Ctm}, (Ptr{Ctime_t}, Ptr{Ctm}), __timer, __tp)
end

function asctime(__tp)
    ccall(:asctime, Cstring, (Ptr{Ctm},), __tp)
end

function ctime(__timer)
    ccall(:ctime, Cstring, (Ptr{Ctime_t},), __timer)
end

function asctime_r(__tp, __buf)
    ccall(:asctime_r, Cstring, (Ptr{Ctm}, Cstring), __tp, __buf)
end

function ctime_r(__timer, __buf)
    ccall(:ctime_r, Cstring, (Ptr{Ctime_t}, Cstring), __timer, __buf)
end

function tzset()
    ccall(:tzset, Cvoid, ())
end

function stime(__when)
    ccall(:stime, Cint, (Ptr{Ctime_t},), __when)
end

function timegm(__tp)
    ccall(:timegm, Ctime_t, (Ptr{Ctm},), __tp)
end

function timelocal(__tp)
    ccall(:timelocal, Ctime_t, (Ptr{Ctm},), __tp)
end

function dysize(__year)
    ccall(:dysize, Cint, (Cint,), __year)
end

function nanosleep(__requested_time, __remaining)
    ccall(:nanosleep, Cint, (Ptr{timespec}, Ptr{timespec}), __requested_time, __remaining)
end

function clock_getres(__clock_id, __res)
    ccall(:clock_getres, Cint, (clockid_t, Ptr{timespec}), __clock_id, __res)
end

function clock_gettime(__clock_id, __tp)
    ccall(:clock_gettime, Cint, (clockid_t, Ptr{timespec}), __clock_id, __tp)
end

function clock_settime(__clock_id, __tp)
    ccall(:clock_settime, Cint, (clockid_t, Ptr{timespec}), __clock_id, __tp)
end

function clock_nanosleep(__clock_id, __flags, __req, __rem)
    ccall(:clock_nanosleep, Cint, (clockid_t, Cint, Ptr{timespec}, Ptr{timespec}), __clock_id, __flags, __req, __rem)
end

function clock_getcpuclockid(__pid, __clock_id)
    ccall(:clock_getcpuclockid, Cint, (pid_t, Ptr{clockid_t}), __pid, __clock_id)
end

function timer_create(__clock_id, __evp, __timerid)
    ccall(:timer_create, Cint, (clockid_t, Ptr{sigevent}, Ptr{timer_t}), __clock_id, __evp, __timerid)
end

function timer_delete(__timerid)
    ccall(:timer_delete, Cint, (timer_t,), __timerid)
end

function timer_settime(__timerid, __flags, __value, __ovalue)
    ccall(:timer_settime, Cint, (timer_t, Cint, Ptr{itimerspec}, Ptr{itimerspec}), __timerid, __flags, __value, __ovalue)
end

function timer_gettime(__timerid, __value)
    ccall(:timer_gettime, Cint, (timer_t, Ptr{itimerspec}), __timerid, __value)
end

function timer_getoverrun(__timerid)
    ccall(:timer_getoverrun, Cint, (timer_t,), __timerid)
end

function timespec_get(__ts, __base)
    ccall(:timespec_get, Cint, (Ptr{timespec}, Cint), __ts, __base)
end

function getdate(__string)
    ccall(:getdate, Ptr{Ctm}, (Cstring,), __string)
end

function getdate_r(__string, __resbufp)
    ccall(:getdate_r, Cint, (Cstring, Ptr{Ctm}), __string, __resbufp)
end

function pthread_create(__newthread, __attr, __start_routine, __arg)
    ccall(:pthread_create, Cint, (Ptr{pthread_t}, Ptr{pthread_attr_t}, Ptr{Cvoid}, Ptr{Cvoid}), __newthread, __attr, __start_routine, __arg)
end

function pthread_exit(__retval)
    ccall(:pthread_exit, Cvoid, (Ptr{Cvoid},), __retval)
end

function pthread_join(__th, __thread_return)
    ccall(:pthread_join, Cint, (pthread_t, Ptr{Ptr{Cvoid}}), __th, __thread_return)
end

function pthread_tryjoin_np(__th, __thread_return)
    ccall(:pthread_tryjoin_np, Cint, (pthread_t, Ptr{Ptr{Cvoid}}), __th, __thread_return)
end

function pthread_timedjoin_np(__th, __thread_return, __abstime)
    ccall(:pthread_timedjoin_np, Cint, (pthread_t, Ptr{Ptr{Cvoid}}, Ptr{timespec}), __th, __thread_return, __abstime)
end

function pthread_detach(__th)
    ccall(:pthread_detach, Cint, (pthread_t,), __th)
end

function pthread_self()
    ccall(:pthread_self, pthread_t, ())
end

function pthread_equal(__thread1, __thread2)
    ccall(:pthread_equal, Cint, (pthread_t, pthread_t), __thread1, __thread2)
end

function pthread_attr_init(__attr)
    ccall(:pthread_attr_init, Cint, (Ptr{pthread_attr_t},), __attr)
end

function pthread_attr_destroy(__attr)
    ccall(:pthread_attr_destroy, Cint, (Ptr{pthread_attr_t},), __attr)
end

function pthread_attr_getdetachstate(__attr, __detachstate)
    ccall(:pthread_attr_getdetachstate, Cint, (Ptr{pthread_attr_t}, Ptr{Cint}), __attr, __detachstate)
end

function pthread_attr_setdetachstate(__attr, __detachstate)
    ccall(:pthread_attr_setdetachstate, Cint, (Ptr{pthread_attr_t}, Cint), __attr, __detachstate)
end

function pthread_attr_getguardsize(__attr, __guardsize)
    ccall(:pthread_attr_getguardsize, Cint, (Ptr{pthread_attr_t}, Ptr{Csize_t}), __attr, __guardsize)
end

function pthread_attr_setguardsize(__attr, __guardsize)
    ccall(:pthread_attr_setguardsize, Cint, (Ptr{pthread_attr_t}, Csize_t), __attr, __guardsize)
end

function pthread_attr_getschedparam(__attr, __param)
    ccall(:pthread_attr_getschedparam, Cint, (Ptr{pthread_attr_t}, Ptr{sched_param}), __attr, __param)
end

function pthread_attr_setschedparam(__attr, __param)
    ccall(:pthread_attr_setschedparam, Cint, (Ptr{pthread_attr_t}, Ptr{sched_param}), __attr, __param)
end

function pthread_attr_getschedpolicy(__attr, __policy)
    ccall(:pthread_attr_getschedpolicy, Cint, (Ptr{pthread_attr_t}, Ptr{Cint}), __attr, __policy)
end

function pthread_attr_setschedpolicy(__attr, __policy)
    ccall(:pthread_attr_setschedpolicy, Cint, (Ptr{pthread_attr_t}, Cint), __attr, __policy)
end

function pthread_attr_getinheritsched(__attr, __inherit)
    ccall(:pthread_attr_getinheritsched, Cint, (Ptr{pthread_attr_t}, Ptr{Cint}), __attr, __inherit)
end

function pthread_attr_setinheritsched(__attr, __inherit)
    ccall(:pthread_attr_setinheritsched, Cint, (Ptr{pthread_attr_t}, Cint), __attr, __inherit)
end

function pthread_attr_getscope(__attr, __scope)
    ccall(:pthread_attr_getscope, Cint, (Ptr{pthread_attr_t}, Ptr{Cint}), __attr, __scope)
end

function pthread_attr_setscope(__attr, __scope)
    ccall(:pthread_attr_setscope, Cint, (Ptr{pthread_attr_t}, Cint), __attr, __scope)
end

function pthread_attr_getstackaddr(__attr, __stackaddr)
    ccall(:pthread_attr_getstackaddr, Cint, (Ptr{pthread_attr_t}, Ptr{Ptr{Cvoid}}), __attr, __stackaddr)
end

function pthread_attr_setstackaddr(__attr, __stackaddr)
    ccall(:pthread_attr_setstackaddr, Cint, (Ptr{pthread_attr_t}, Ptr{Cvoid}), __attr, __stackaddr)
end

function pthread_attr_getstacksize(__attr, __stacksize)
    ccall(:pthread_attr_getstacksize, Cint, (Ptr{pthread_attr_t}, Ptr{Csize_t}), __attr, __stacksize)
end

function pthread_attr_setstacksize(__attr, __stacksize)
    ccall(:pthread_attr_setstacksize, Cint, (Ptr{pthread_attr_t}, Csize_t), __attr, __stacksize)
end

function pthread_attr_getstack(__attr, __stackaddr, __stacksize)
    ccall(:pthread_attr_getstack, Cint, (Ptr{pthread_attr_t}, Ptr{Ptr{Cvoid}}, Ptr{Csize_t}), __attr, __stackaddr, __stacksize)
end

function pthread_attr_setstack(__attr, __stackaddr, __stacksize)
    ccall(:pthread_attr_setstack, Cint, (Ptr{pthread_attr_t}, Ptr{Cvoid}, Csize_t), __attr, __stackaddr, __stacksize)
end

function pthread_attr_setaffinity_np(__attr, __cpusetsize, __cpuset)
    ccall(:pthread_attr_setaffinity_np, Cint, (Ptr{pthread_attr_t}, Csize_t, Ptr{cpu_set_t}), __attr, __cpusetsize, __cpuset)
end

function pthread_attr_getaffinity_np(__attr, __cpusetsize, __cpuset)
    ccall(:pthread_attr_getaffinity_np, Cint, (Ptr{pthread_attr_t}, Csize_t, Ptr{cpu_set_t}), __attr, __cpusetsize, __cpuset)
end

function pthread_getattr_default_np(__attr)
    ccall(:pthread_getattr_default_np, Cint, (Ptr{pthread_attr_t},), __attr)
end

function pthread_setattr_default_np(__attr)
    ccall(:pthread_setattr_default_np, Cint, (Ptr{pthread_attr_t},), __attr)
end

function pthread_getattr_np(__th, __attr)
    ccall(:pthread_getattr_np, Cint, (pthread_t, Ptr{pthread_attr_t}), __th, __attr)
end

function pthread_setschedparam(__target_thread, __policy, __param)
    ccall(:pthread_setschedparam, Cint, (pthread_t, Cint, Ptr{sched_param}), __target_thread, __policy, __param)
end

function pthread_getschedparam(__target_thread, __policy, __param)
    ccall(:pthread_getschedparam, Cint, (pthread_t, Ptr{Cint}, Ptr{sched_param}), __target_thread, __policy, __param)
end

function pthread_setschedprio(__target_thread, __prio)
    ccall(:pthread_setschedprio, Cint, (pthread_t, Cint), __target_thread, __prio)
end

function pthread_getname_np(__target_thread, __buf, __buflen)
    ccall(:pthread_getname_np, Cint, (pthread_t, Cstring, Csize_t), __target_thread, __buf, __buflen)
end

function pthread_setname_np(__target_thread, __name)
    ccall(:pthread_setname_np, Cint, (pthread_t, Cstring), __target_thread, __name)
end

function pthread_getconcurrency()
    ccall(:pthread_getconcurrency, Cint, ())
end

function pthread_setconcurrency(__level)
    ccall(:pthread_setconcurrency, Cint, (Cint,), __level)
end

function pthread_yield()
    ccall(:pthread_yield, Cint, ())
end

function pthread_setaffinity_np(__th, __cpusetsize, __cpuset)
    ccall(:pthread_setaffinity_np, Cint, (pthread_t, Csize_t, Ptr{cpu_set_t}), __th, __cpusetsize, __cpuset)
end

function pthread_getaffinity_np(__th, __cpusetsize, __cpuset)
    ccall(:pthread_getaffinity_np, Cint, (pthread_t, Csize_t, Ptr{cpu_set_t}), __th, __cpusetsize, __cpuset)
end

function pthread_once(__once_control, __init_routine)
    ccall(:pthread_once, Cint, (Ptr{pthread_once_t}, Ptr{Cvoid}), __once_control, __init_routine)
end

function pthread_setcancelstate(__state, __oldstate)
    ccall(:pthread_setcancelstate, Cint, (Cint, Ptr{Cint}), __state, __oldstate)
end

function pthread_setcanceltype(__type, __oldtype)
    ccall(:pthread_setcanceltype, Cint, (Cint, Ptr{Cint}), __type, __oldtype)
end

function pthread_cancel(__th)
    ccall(:pthread_cancel, Cint, (pthread_t,), __th)
end

function pthread_testcancel()
    ccall(:pthread_testcancel, Cvoid, ())
end

function __pthread_register_cancel(__buf)
    ccall(:__pthread_register_cancel, Cvoid, (Ptr{__pthread_unwind_buf_t},), __buf)
end

function __pthread_unregister_cancel(__buf)
    ccall(:__pthread_unregister_cancel, Cvoid, (Ptr{__pthread_unwind_buf_t},), __buf)
end

function __pthread_register_cancel_defer(__buf)
    ccall(:__pthread_register_cancel_defer, Cvoid, (Ptr{__pthread_unwind_buf_t},), __buf)
end

function __pthread_unregister_cancel_restore(__buf)
    ccall(:__pthread_unregister_cancel_restore, Cvoid, (Ptr{__pthread_unwind_buf_t},), __buf)
end

function __pthread_unwind_next(__buf)
    ccall(:__pthread_unwind_next, Cvoid, (Ptr{__pthread_unwind_buf_t},), __buf)
end

function __sigsetjmp(__env, __savemask)
    ccall(:__sigsetjmp, Cint, (Ptr{__jmp_buf_tag}, Cint), __env, __savemask)
end

function pthread_mutex_init(__mutex, __mutexattr)
    ccall(:pthread_mutex_init, Cint, (Ptr{pthread_mutex_t}, Ptr{pthread_mutexattr_t}), __mutex, __mutexattr)
end

function pthread_mutex_destroy(__mutex)
    ccall(:pthread_mutex_destroy, Cint, (Ptr{pthread_mutex_t},), __mutex)
end

function pthread_mutex_trylock(__mutex)
    ccall(:pthread_mutex_trylock, Cint, (Ptr{pthread_mutex_t},), __mutex)
end

function pthread_mutex_lock(__mutex)
    ccall(:pthread_mutex_lock, Cint, (Ptr{pthread_mutex_t},), __mutex)
end

function pthread_mutex_timedlock(__mutex, __abstime)
    ccall(:pthread_mutex_timedlock, Cint, (Ptr{pthread_mutex_t}, Ptr{timespec}), __mutex, __abstime)
end

function pthread_mutex_unlock(__mutex)
    ccall(:pthread_mutex_unlock, Cint, (Ptr{pthread_mutex_t},), __mutex)
end

function pthread_mutex_getprioceiling(__mutex, __prioceiling)
    ccall(:pthread_mutex_getprioceiling, Cint, (Ptr{pthread_mutex_t}, Ptr{Cint}), __mutex, __prioceiling)
end

function pthread_mutex_setprioceiling(__mutex, __prioceiling, __old_ceiling)
    ccall(:pthread_mutex_setprioceiling, Cint, (Ptr{pthread_mutex_t}, Cint, Ptr{Cint}), __mutex, __prioceiling, __old_ceiling)
end

function pthread_mutex_consistent(__mutex)
    ccall(:pthread_mutex_consistent, Cint, (Ptr{pthread_mutex_t},), __mutex)
end

function pthread_mutex_consistent_np(__mutex)
    ccall(:pthread_mutex_consistent_np, Cint, (Ptr{pthread_mutex_t},), __mutex)
end

function pthread_mutexattr_init(__attr)
    ccall(:pthread_mutexattr_init, Cint, (Ptr{pthread_mutexattr_t},), __attr)
end

function pthread_mutexattr_destroy(__attr)
    ccall(:pthread_mutexattr_destroy, Cint, (Ptr{pthread_mutexattr_t},), __attr)
end

function pthread_mutexattr_getpshared(__attr, __pshared)
    ccall(:pthread_mutexattr_getpshared, Cint, (Ptr{pthread_mutexattr_t}, Ptr{Cint}), __attr, __pshared)
end

function pthread_mutexattr_setpshared(__attr, __pshared)
    ccall(:pthread_mutexattr_setpshared, Cint, (Ptr{pthread_mutexattr_t}, Cint), __attr, __pshared)
end

function pthread_mutexattr_gettype(__attr, __kind)
    ccall(:pthread_mutexattr_gettype, Cint, (Ptr{pthread_mutexattr_t}, Ptr{Cint}), __attr, __kind)
end

function pthread_mutexattr_settype(__attr, __kind)
    ccall(:pthread_mutexattr_settype, Cint, (Ptr{pthread_mutexattr_t}, Cint), __attr, __kind)
end

function pthread_mutexattr_getprotocol(__attr, __protocol)
    ccall(:pthread_mutexattr_getprotocol, Cint, (Ptr{pthread_mutexattr_t}, Ptr{Cint}), __attr, __protocol)
end

function pthread_mutexattr_setprotocol(__attr, __protocol)
    ccall(:pthread_mutexattr_setprotocol, Cint, (Ptr{pthread_mutexattr_t}, Cint), __attr, __protocol)
end

function pthread_mutexattr_getprioceiling(__attr, __prioceiling)
    ccall(:pthread_mutexattr_getprioceiling, Cint, (Ptr{pthread_mutexattr_t}, Ptr{Cint}), __attr, __prioceiling)
end

function pthread_mutexattr_setprioceiling(__attr, __prioceiling)
    ccall(:pthread_mutexattr_setprioceiling, Cint, (Ptr{pthread_mutexattr_t}, Cint), __attr, __prioceiling)
end

function pthread_mutexattr_getrobust(__attr, __robustness)
    ccall(:pthread_mutexattr_getrobust, Cint, (Ptr{pthread_mutexattr_t}, Ptr{Cint}), __attr, __robustness)
end

function pthread_mutexattr_getrobust_np(__attr, __robustness)
    ccall(:pthread_mutexattr_getrobust_np, Cint, (Ptr{pthread_mutexattr_t}, Ptr{Cint}), __attr, __robustness)
end

function pthread_mutexattr_setrobust(__attr, __robustness)
    ccall(:pthread_mutexattr_setrobust, Cint, (Ptr{pthread_mutexattr_t}, Cint), __attr, __robustness)
end

function pthread_mutexattr_setrobust_np(__attr, __robustness)
    ccall(:pthread_mutexattr_setrobust_np, Cint, (Ptr{pthread_mutexattr_t}, Cint), __attr, __robustness)
end

function pthread_rwlock_init(__rwlock, __attr)
    ccall(:pthread_rwlock_init, Cint, (Ptr{pthread_rwlock_t}, Ptr{pthread_rwlockattr_t}), __rwlock, __attr)
end

function pthread_rwlock_destroy(__rwlock)
    ccall(:pthread_rwlock_destroy, Cint, (Ptr{pthread_rwlock_t},), __rwlock)
end

function pthread_rwlock_rdlock(__rwlock)
    ccall(:pthread_rwlock_rdlock, Cint, (Ptr{pthread_rwlock_t},), __rwlock)
end

function pthread_rwlock_tryrdlock(__rwlock)
    ccall(:pthread_rwlock_tryrdlock, Cint, (Ptr{pthread_rwlock_t},), __rwlock)
end

function pthread_rwlock_timedrdlock(__rwlock, __abstime)
    ccall(:pthread_rwlock_timedrdlock, Cint, (Ptr{pthread_rwlock_t}, Ptr{timespec}), __rwlock, __abstime)
end

function pthread_rwlock_wrlock(__rwlock)
    ccall(:pthread_rwlock_wrlock, Cint, (Ptr{pthread_rwlock_t},), __rwlock)
end

function pthread_rwlock_trywrlock(__rwlock)
    ccall(:pthread_rwlock_trywrlock, Cint, (Ptr{pthread_rwlock_t},), __rwlock)
end

function pthread_rwlock_timedwrlock(__rwlock, __abstime)
    ccall(:pthread_rwlock_timedwrlock, Cint, (Ptr{pthread_rwlock_t}, Ptr{timespec}), __rwlock, __abstime)
end

function pthread_rwlock_unlock(__rwlock)
    ccall(:pthread_rwlock_unlock, Cint, (Ptr{pthread_rwlock_t},), __rwlock)
end

function pthread_rwlockattr_init(__attr)
    ccall(:pthread_rwlockattr_init, Cint, (Ptr{pthread_rwlockattr_t},), __attr)
end

function pthread_rwlockattr_destroy(__attr)
    ccall(:pthread_rwlockattr_destroy, Cint, (Ptr{pthread_rwlockattr_t},), __attr)
end

function pthread_rwlockattr_getpshared(__attr, __pshared)
    ccall(:pthread_rwlockattr_getpshared, Cint, (Ptr{pthread_rwlockattr_t}, Ptr{Cint}), __attr, __pshared)
end

function pthread_rwlockattr_setpshared(__attr, __pshared)
    ccall(:pthread_rwlockattr_setpshared, Cint, (Ptr{pthread_rwlockattr_t}, Cint), __attr, __pshared)
end

function pthread_rwlockattr_getkind_np(__attr, __pref)
    ccall(:pthread_rwlockattr_getkind_np, Cint, (Ptr{pthread_rwlockattr_t}, Ptr{Cint}), __attr, __pref)
end

function pthread_rwlockattr_setkind_np(__attr, __pref)
    ccall(:pthread_rwlockattr_setkind_np, Cint, (Ptr{pthread_rwlockattr_t}, Cint), __attr, __pref)
end

function pthread_cond_init(__cond, __cond_attr)
    ccall(:pthread_cond_init, Cint, (Ptr{pthread_cond_t}, Ptr{pthread_condattr_t}), __cond, __cond_attr)
end

function pthread_cond_destroy(__cond)
    ccall(:pthread_cond_destroy, Cint, (Ptr{pthread_cond_t},), __cond)
end

function pthread_cond_signal(__cond)
    ccall(:pthread_cond_signal, Cint, (Ptr{pthread_cond_t},), __cond)
end

function pthread_cond_broadcast(__cond)
    ccall(:pthread_cond_broadcast, Cint, (Ptr{pthread_cond_t},), __cond)
end

function pthread_cond_wait(__cond, __mutex)
    ccall(:pthread_cond_wait, Cint, (Ptr{pthread_cond_t}, Ptr{pthread_mutex_t}), __cond, __mutex)
end

function pthread_cond_timedwait(__cond, __mutex, __abstime)
    ccall(:pthread_cond_timedwait, Cint, (Ptr{pthread_cond_t}, Ptr{pthread_mutex_t}, Ptr{timespec}), __cond, __mutex, __abstime)
end

function pthread_condattr_init(__attr)
    ccall(:pthread_condattr_init, Cint, (Ptr{pthread_condattr_t},), __attr)
end

function pthread_condattr_destroy(__attr)
    ccall(:pthread_condattr_destroy, Cint, (Ptr{pthread_condattr_t},), __attr)
end

function pthread_condattr_getpshared(__attr, __pshared)
    ccall(:pthread_condattr_getpshared, Cint, (Ptr{pthread_condattr_t}, Ptr{Cint}), __attr, __pshared)
end

function pthread_condattr_setpshared(__attr, __pshared)
    ccall(:pthread_condattr_setpshared, Cint, (Ptr{pthread_condattr_t}, Cint), __attr, __pshared)
end

function pthread_condattr_getclock(__attr, __clock_id)
    ccall(:pthread_condattr_getclock, Cint, (Ptr{pthread_condattr_t}, Ptr{__clockid_t}), __attr, __clock_id)
end

function pthread_condattr_setclock(__attr, __clock_id)
    ccall(:pthread_condattr_setclock, Cint, (Ptr{pthread_condattr_t}, __clockid_t), __attr, __clock_id)
end

function pthread_spin_init(__lock, __pshared)
    ccall(:pthread_spin_init, Cint, (Ptr{pthread_spinlock_t}, Cint), __lock, __pshared)
end

function pthread_spin_destroy(__lock)
    ccall(:pthread_spin_destroy, Cint, (Ptr{pthread_spinlock_t},), __lock)
end

function pthread_spin_lock(__lock)
    ccall(:pthread_spin_lock, Cint, (Ptr{pthread_spinlock_t},), __lock)
end

function pthread_spin_trylock(__lock)
    ccall(:pthread_spin_trylock, Cint, (Ptr{pthread_spinlock_t},), __lock)
end

function pthread_spin_unlock(__lock)
    ccall(:pthread_spin_unlock, Cint, (Ptr{pthread_spinlock_t},), __lock)
end

function pthread_barrier_init(__barrier, __attr, __count)
    ccall(:pthread_barrier_init, Cint, (Ptr{pthread_barrier_t}, Ptr{pthread_barrierattr_t}, UInt32), __barrier, __attr, __count)
end

function pthread_barrier_destroy(__barrier)
    ccall(:pthread_barrier_destroy, Cint, (Ptr{pthread_barrier_t},), __barrier)
end

function pthread_barrier_wait(__barrier)
    ccall(:pthread_barrier_wait, Cint, (Ptr{pthread_barrier_t},), __barrier)
end

function pthread_barrierattr_init(__attr)
    ccall(:pthread_barrierattr_init, Cint, (Ptr{pthread_barrierattr_t},), __attr)
end

function pthread_barrierattr_destroy(__attr)
    ccall(:pthread_barrierattr_destroy, Cint, (Ptr{pthread_barrierattr_t},), __attr)
end

function pthread_barrierattr_getpshared(__attr, __pshared)
    ccall(:pthread_barrierattr_getpshared, Cint, (Ptr{pthread_barrierattr_t}, Ptr{Cint}), __attr, __pshared)
end

function pthread_barrierattr_setpshared(__attr, __pshared)
    ccall(:pthread_barrierattr_setpshared, Cint, (Ptr{pthread_barrierattr_t}, Cint), __attr, __pshared)
end

function pthread_key_create(__key, __destr_function)
    ccall(:pthread_key_create, Cint, (Ptr{pthread_key_t}, Ptr{Cvoid}), __key, __destr_function)
end

function pthread_key_delete(__key)
    ccall(:pthread_key_delete, Cint, (pthread_key_t,), __key)
end

function pthread_getspecific(__key)
    ccall(:pthread_getspecific, Ptr{Cvoid}, (pthread_key_t,), __key)
end

function pthread_setspecific(__key, __pointer)
    ccall(:pthread_setspecific, Cint, (pthread_key_t, Ptr{Cvoid}), __key, __pointer)
end

function pthread_getcpuclockid(__thread_id, __clock_id)
    ccall(:pthread_getcpuclockid, Cint, (pthread_t, Ptr{__clockid_t}), __thread_id, __clock_id)
end

function pthread_atfork(__prepare, __parent, __child)
    ccall(:pthread_atfork, Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), __prepare, __parent, __child)
end

function cfgetospeed(__termios_p)
    ccall(:cfgetospeed, speed_t, (Ptr{termios},), __termios_p)
end

function cfgetispeed(__termios_p)
    ccall(:cfgetispeed, speed_t, (Ptr{termios},), __termios_p)
end

function cfsetospeed(__termios_p, __speed)
    ccall(:cfsetospeed, Cint, (Ptr{termios}, speed_t), __termios_p, __speed)
end

function cfsetispeed(__termios_p, __speed)
    ccall(:cfsetispeed, Cint, (Ptr{termios}, speed_t), __termios_p, __speed)
end

function cfsetspeed(__termios_p, __speed)
    ccall(:cfsetspeed, Cint, (Ptr{termios}, speed_t), __termios_p, __speed)
end

function tcgetattr(__fd, __termios_p)
    ccall(:tcgetattr, Cint, (Cint, Ptr{termios}), __fd, __termios_p)
end

function tcsetattr(__fd, __optional_actions, __termios_p)
    ccall(:tcsetattr, Cint, (Cint, Cint, Ptr{termios}), __fd, __optional_actions, __termios_p)
end

function cfmakeraw(__termios_p)
    ccall(:cfmakeraw, Cvoid, (Ptr{termios},), __termios_p)
end

function tcsendbreak(__fd, __duration)
    ccall(:tcsendbreak, Cint, (Cint, Cint), __fd, __duration)
end

function tcdrain(__fd)
    ccall(:tcdrain, Cint, (Cint,), __fd)
end

function tcflush(__fd, __queue_selector)
    ccall(:tcflush, Cint, (Cint, Cint), __fd, __queue_selector)
end

function tcflow(__fd, __action)
    ccall(:tcflow, Cint, (Cint, Cint), __fd, __action)
end

function tcgetsid(__fd)
    ccall(:tcgetsid, __pid_t, (Cint,), __fd)
end

function readahead(__fd, __offset, __count)
    ccall(:readahead, __ssize_t, (Cint, __off64_t, Csize_t), __fd, __offset, __count)
end

function sync_file_range(__fd, __offset, __count, __flags)
    ccall(:sync_file_range, Cint, (Cint, __off64_t, __off64_t, UInt32), __fd, __offset, __count, __flags)
end

function vmsplice(__fdout, __iov, __count, __flags)
    ccall(:vmsplice, __ssize_t, (Cint, Ptr{iovec}, Csize_t, UInt32), __fdout, __iov, __count, __flags)
end

function splice(__fdin, __offin, __fdout, __offout, __len, __flags)
    ccall(:splice, __ssize_t, (Cint, Ptr{__off64_t}, Cint, Ptr{__off64_t}, Csize_t, UInt32), __fdin, __offin, __fdout, __offout, __len, __flags)
end

function tee(__fdin, __fdout, __len, __flags)
    ccall(:tee, __ssize_t, (Cint, Cint, Csize_t, UInt32), __fdin, __fdout, __len, __flags)
end

function fallocate(__fd, __mode, __offset, __len)
    ccall(:fallocate, Cint, (Cint, Cint, __off_t, __off_t), __fd, __mode, __offset, __len)
end

function fallocate64(__fd, __mode, __offset, __len)
    ccall(:fallocate64, Cint, (Cint, Cint, __off64_t, __off64_t), __fd, __mode, __offset, __len)
end

function name_to_handle_at(__dfd, __name, __handle, __mnt_id, __flags)
    ccall(:name_to_handle_at, Cint, (Cint, Cstring, Ptr{file_handle}, Ptr{Cint}, Cint), __dfd, __name, __handle, __mnt_id, __flags)
end

function open_by_handle_at(__mountdirfd, __handle, __flags)
    ccall(:open_by_handle_at, Cint, (Cint, Ptr{file_handle}, Cint), __mountdirfd, __handle, __flags)
end

function creat(__file, __mode)
    ccall(:creat, Cint, (Cstring, mode_t), __file, __mode)
end

function creat64(__file, __mode)
    ccall(:creat64, Cint, (Cstring, mode_t), __file, __mode)
end

function lockf(__fd, __cmd, __len)
    ccall(:lockf, Cint, (Cint, Cint, off_t), __fd, __cmd, __len)
end

function lockf64(__fd, __cmd, __len)
    ccall(:lockf64, Cint, (Cint, Cint, off64_t), __fd, __cmd, __len)
end

function posix_fadvise(__fd, __offset, __len, __advise)
    ccall(:posix_fadvise, Cint, (Cint, off_t, off_t, Cint), __fd, __offset, __len, __advise)
end

function posix_fadvise64(__fd, __offset, __len, __advise)
    ccall(:posix_fadvise64, Cint, (Cint, off64_t, off64_t, Cint), __fd, __offset, __len, __advise)
end

function posix_fallocate(__fd, __offset, __len)
    ccall(:posix_fallocate, Cint, (Cint, off_t, off_t), __fd, __offset, __len)
end

function posix_fallocate64(__fd, __offset, __len)
    ccall(:posix_fallocate64, Cint, (Cint, off64_t, off64_t), __fd, __offset, __len)
end

function poll(__fds, __nfds, __timeout)
    ccall(:poll, Cint, (Ptr{pollfd}, nfds_t, Cint), __fds, __nfds, __timeout)
end

function ppoll(__fds, __nfds, __timeout, __ss)
    ccall(:ppoll, Cint, (Ptr{pollfd}, nfds_t, Ptr{timespec}, Ptr{__sigset_t}), __fds, __nfds, __timeout, __ss)
end

function epoll_create(__size)
    ccall(:epoll_create, Cint, (Cint,), __size)
end

function epoll_create1(__flags)
    ccall(:epoll_create1, Cint, (Cint,), __flags)
end

function epoll_ctl(__epfd, __op, __fd, __event)
    ccall(:epoll_ctl, Cint, (Cint, Cint, Cint, Ptr{epoll_event}), __epfd, __op, __fd, __event)
end

function epoll_wait(__epfd, __events, __maxevents, __timeout)
    ccall(:epoll_wait, Cint, (Cint, Ptr{epoll_event}, Cint, Cint), __epfd, __events, __maxevents, __timeout)
end

function epoll_pwait(__epfd, __events, __maxevents, __timeout, __ss)
    ccall(:epoll_pwait, Cint, (Cint, Ptr{epoll_event}, Cint, Cint, Ptr{__sigset_t}), __epfd, __events, __maxevents, __timeout, __ss)
end

function access(__name, __type)
    ccall(:access, Cint, (Cstring, Cint), __name, __type)
end

function euidaccess(__name, __type)
    ccall(:euidaccess, Cint, (Cstring, Cint), __name, __type)
end

function eaccess(__name, __type)
    ccall(:eaccess, Cint, (Cstring, Cint), __name, __type)
end

function faccessat(__fd, __file, __type, __flag)
    ccall(:faccessat, Cint, (Cint, Cstring, Cint, Cint), __fd, __file, __type, __flag)
end

function lseek(__fd, __offset, __whence)
    ccall(:lseek, __off_t, (Cint, __off_t, Cint), __fd, __offset, __whence)
end

function lseek64(__fd, __offset, __whence)
    ccall(:lseek64, __off64_t, (Cint, __off64_t, Cint), __fd, __offset, __whence)
end

function close(__fd)
    ccall(:close, Cint, (Cint,), __fd)
end

function read(__fd, __buf, __nbytes)
    ccall(:read, ssize_t, (Cint, Ptr{Cvoid}, Csize_t), __fd, __buf, __nbytes)
end

function write(__fd, __buf, __n)
    ccall(:write, ssize_t, (Cint, Ptr{Cvoid}, Csize_t), __fd, __buf, __n)
end

function pread(__fd, __buf, __nbytes, __offset)
    ccall(:pread, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, __off_t), __fd, __buf, __nbytes, __offset)
end

function pwrite(__fd, __buf, __n, __offset)
    ccall(:pwrite, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, __off_t), __fd, __buf, __n, __offset)
end

function pread64(__fd, __buf, __nbytes, __offset)
    ccall(:pread64, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, __off64_t), __fd, __buf, __nbytes, __offset)
end

function pwrite64(__fd, __buf, __n, __offset)
    ccall(:pwrite64, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, __off64_t), __fd, __buf, __n, __offset)
end

function pipe(__pipedes)
    ccall(:pipe, Cint, (Ptr{Cint},), __pipedes)
end

function pipe2(__pipedes, __flags)
    ccall(:pipe2, Cint, (Ptr{Cint}, Cint), __pipedes, __flags)
end

function alarm(__seconds)
    ccall(:alarm, UInt32, (UInt32,), __seconds)
end

function sleep(__seconds)
    ccall(:sleep, UInt32, (UInt32,), __seconds)
end

function ualarm(__value, __interval)
    ccall(:ualarm, __useconds_t, (__useconds_t, __useconds_t), __value, __interval)
end

function usleep(__useconds)
    ccall(:usleep, Cint, (__useconds_t,), __useconds)
end

function pause()
    ccall(:pause, Cint, ())
end

function chown(__file, __owner, __group)
    ccall(:chown, Cint, (Cstring, __uid_t, __gid_t), __file, __owner, __group)
end

function fchown(__fd, __owner, __group)
    ccall(:fchown, Cint, (Cint, __uid_t, __gid_t), __fd, __owner, __group)
end

function lchown(__file, __owner, __group)
    ccall(:lchown, Cint, (Cstring, __uid_t, __gid_t), __file, __owner, __group)
end

function fchownat(__fd, __file, __owner, __group, __flag)
    ccall(:fchownat, Cint, (Cint, Cstring, __uid_t, __gid_t, Cint), __fd, __file, __owner, __group, __flag)
end

function chdir(__path)
    ccall(:chdir, Cint, (Cstring,), __path)
end

function fchdir(__fd)
    ccall(:fchdir, Cint, (Cint,), __fd)
end

function getcwd(__buf, __size)
    ccall(:getcwd, Cstring, (Cstring, Csize_t), __buf, __size)
end

function get_current_dir_name()
    ccall(:get_current_dir_name, Cstring, ())
end

function getwd(__buf)
    ccall(:getwd, Cstring, (Cstring,), __buf)
end

function dup(__fd)
    ccall(:dup, Cint, (Cint,), __fd)
end

function dup2(__fd, __fd2)
    ccall(:dup2, Cint, (Cint, Cint), __fd, __fd2)
end

function dup3(__fd, __fd2, __flags)
    ccall(:dup3, Cint, (Cint, Cint, Cint), __fd, __fd2, __flags)
end

function execve(__path, __argv, __envp)
    ccall(:execve, Cint, (Cstring, Ptr{Cstring}, Ptr{Cstring}), __path, __argv, __envp)
end

function fexecve(__fd, __argv, __envp)
    ccall(:fexecve, Cint, (Cint, Ptr{Cstring}, Ptr{Cstring}), __fd, __argv, __envp)
end

function execv(__path, __argv)
    ccall(:execv, Cint, (Cstring, Ptr{Cstring}), __path, __argv)
end

function execvp(__file, __argv)
    ccall(:execvp, Cint, (Cstring, Ptr{Cstring}), __file, __argv)
end

function execvpe(__file, __argv, __envp)
    ccall(:execvpe, Cint, (Cstring, Ptr{Cstring}, Ptr{Cstring}), __file, __argv, __envp)
end

function nice(__inc)
    ccall(:nice, Cint, (Cint,), __inc)
end

function _exit(__status)
    ccall(:_exit, Cvoid, (Cint,), __status)
end

function pathconf(__path, __name)
    ccall(:pathconf, Clong, (Cstring, Cint), __path, __name)
end

function fpathconf(__fd, __name)
    ccall(:fpathconf, Clong, (Cint, Cint), __fd, __name)
end

function sysconf(__name)
    ccall(:sysconf, Clong, (Cint,), __name)
end

function confstr(__name, __buf, __len)
    ccall(:confstr, Csize_t, (Cint, Cstring, Csize_t), __name, __buf, __len)
end

function getpid()
    ccall(:getpid, __pid_t, ())
end

function getppid()
    ccall(:getppid, __pid_t, ())
end

function getpgrp()
    ccall(:getpgrp, __pid_t, ())
end

function __getpgid(__pid)
    ccall(:__getpgid, __pid_t, (__pid_t,), __pid)
end

function getpgid(__pid)
    ccall(:getpgid, __pid_t, (__pid_t,), __pid)
end

function setpgid(__pid, __pgid)
    ccall(:setpgid, Cint, (__pid_t, __pid_t), __pid, __pgid)
end

function setpgrp()
    ccall(:setpgrp, Cint, ())
end

function setsid()
    ccall(:setsid, __pid_t, ())
end

function getsid(__pid)
    ccall(:getsid, __pid_t, (__pid_t,), __pid)
end

function getuid()
    ccall(:getuid, __uid_t, ())
end

function geteuid()
    ccall(:geteuid, __uid_t, ())
end

function getgid()
    ccall(:getgid, __gid_t, ())
end

function getegid()
    ccall(:getegid, __gid_t, ())
end

function getgroups(__size, __list)
    ccall(:getgroups, Cint, (Cint, Ptr{__gid_t}), __size, __list)
end

function group_member(__gid)
    ccall(:group_member, Cint, (__gid_t,), __gid)
end

function setuid(__uid)
    ccall(:setuid, Cint, (__uid_t,), __uid)
end

function setreuid(__ruid, __euid)
    ccall(:setreuid, Cint, (__uid_t, __uid_t), __ruid, __euid)
end

function seteuid(__uid)
    ccall(:seteuid, Cint, (__uid_t,), __uid)
end

function setgid(__gid)
    ccall(:setgid, Cint, (__gid_t,), __gid)
end

function setregid(__rgid, __egid)
    ccall(:setregid, Cint, (__gid_t, __gid_t), __rgid, __egid)
end

function setegid(__gid)
    ccall(:setegid, Cint, (__gid_t,), __gid)
end

function getresuid(__ruid, __euid, __suid)
    ccall(:getresuid, Cint, (Ptr{__uid_t}, Ptr{__uid_t}, Ptr{__uid_t}), __ruid, __euid, __suid)
end

function getresgid(__rgid, __egid, __sgid)
    ccall(:getresgid, Cint, (Ptr{__gid_t}, Ptr{__gid_t}, Ptr{__gid_t}), __rgid, __egid, __sgid)
end

function setresuid(__ruid, __euid, __suid)
    ccall(:setresuid, Cint, (__uid_t, __uid_t, __uid_t), __ruid, __euid, __suid)
end

function setresgid(__rgid, __egid, __sgid)
    ccall(:setresgid, Cint, (__gid_t, __gid_t, __gid_t), __rgid, __egid, __sgid)
end

function fork()
    ccall(:fork, __pid_t, ())
end

function vfork()
    ccall(:vfork, Cint, ())
end

function ttyname(__fd)
    ccall(:ttyname, Cstring, (Cint,), __fd)
end

function ttyname_r(__fd, __buf, __buflen)
    ccall(:ttyname_r, Cint, (Cint, Cstring, Csize_t), __fd, __buf, __buflen)
end

function isatty(__fd)
    ccall(:isatty, Cint, (Cint,), __fd)
end

function ttyslot()
    ccall(:ttyslot, Cint, ())
end

function link(__from, __to)
    ccall(:link, Cint, (Cstring, Cstring), __from, __to)
end

function linkat(__fromfd, __from, __tofd, __to, __flags)
    ccall(:linkat, Cint, (Cint, Cstring, Cint, Cstring, Cint), __fromfd, __from, __tofd, __to, __flags)
end

function symlink(__from, __to)
    ccall(:symlink, Cint, (Cstring, Cstring), __from, __to)
end

function readlink(__path, __buf, __len)
    ccall(:readlink, ssize_t, (Cstring, Cstring, Csize_t), __path, __buf, __len)
end

function symlinkat(__from, __tofd, __to)
    ccall(:symlinkat, Cint, (Cstring, Cint, Cstring), __from, __tofd, __to)
end

function readlinkat(__fd, __path, __buf, __len)
    ccall(:readlinkat, ssize_t, (Cint, Cstring, Cstring, Csize_t), __fd, __path, __buf, __len)
end

function unlink(__name)
    ccall(:unlink, Cint, (Cstring,), __name)
end

function unlinkat(__fd, __name, __flag)
    ccall(:unlinkat, Cint, (Cint, Cstring, Cint), __fd, __name, __flag)
end

function rmdir(__path)
    ccall(:rmdir, Cint, (Cstring,), __path)
end

function tcgetpgrp(__fd)
    ccall(:tcgetpgrp, __pid_t, (Cint,), __fd)
end

function tcsetpgrp(__fd, __pgrp_id)
    ccall(:tcsetpgrp, Cint, (Cint, __pid_t), __fd, __pgrp_id)
end

function getlogin()
    ccall(:getlogin, Cstring, ())
end

function getlogin_r(__name, __name_len)
    ccall(:getlogin_r, Cint, (Cstring, Csize_t), __name, __name_len)
end

function setlogin(__name)
    ccall(:setlogin, Cint, (Cstring,), __name)
end

function getopt(___argc, ___argv, __shortopts)
    ccall(:getopt, Cint, (Cint, Ptr{Cstring}, Cstring), ___argc, ___argv, __shortopts)
end

function gethostname(__name, __len)
    ccall(:gethostname, Cint, (Cstring, Csize_t), __name, __len)
end

function sethostname(__name, __len)
    ccall(:sethostname, Cint, (Cstring, Csize_t), __name, __len)
end

function sethostid(__id)
    ccall(:sethostid, Cint, (Clong,), __id)
end

function getdomainname(__name, __len)
    ccall(:getdomainname, Cint, (Cstring, Csize_t), __name, __len)
end

function setdomainname(__name, __len)
    ccall(:setdomainname, Cint, (Cstring, Csize_t), __name, __len)
end

function vhangup()
    ccall(:vhangup, Cint, ())
end

function revoke(__file)
    ccall(:revoke, Cint, (Cstring,), __file)
end

function profil(__sample_buffer, __size, __offset, __scale)
    ccall(:profil, Cint, (Ptr{UInt16}, Csize_t, Csize_t, UInt32), __sample_buffer, __size, __offset, __scale)
end

function acct(__name)
    ccall(:acct, Cint, (Cstring,), __name)
end

function getusershell()
    ccall(:getusershell, Cstring, ())
end

function endusershell()
    ccall(:endusershell, Cvoid, ())
end

function setusershell()
    ccall(:setusershell, Cvoid, ())
end

function daemon(__nochdir, __noclose)
    ccall(:daemon, Cint, (Cint, Cint), __nochdir, __noclose)
end

function chroot(__path)
    ccall(:chroot, Cint, (Cstring,), __path)
end

function getpass(__prompt)
    ccall(:getpass, Cstring, (Cstring,), __prompt)
end

function fsync(__fd)
    ccall(:fsync, Cint, (Cint,), __fd)
end

function syncfs(__fd)
    ccall(:syncfs, Cint, (Cint,), __fd)
end

function gethostid()
    ccall(:gethostid, Clong, ())
end

function sync()
    ccall(:sync, Cvoid, ())
end

function getpagesize()
    ccall(:getpagesize, Cint, ())
end

function getdtablesize()
    ccall(:getdtablesize, Cint, ())
end

function truncate(__file, __length)
    ccall(:truncate, Cint, (Cstring, __off_t), __file, __length)
end

function truncate64(__file, __length)
    ccall(:truncate64, Cint, (Cstring, __off64_t), __file, __length)
end

function ftruncate(__fd, __length)
    ccall(:ftruncate, Cint, (Cint, __off_t), __fd, __length)
end

function ftruncate64(__fd, __length)
    ccall(:ftruncate64, Cint, (Cint, __off64_t), __fd, __length)
end

function brk(__addr)
    ccall(:brk, Cint, (Ptr{Cvoid},), __addr)
end

function sbrk(__delta)
    ccall(:sbrk, Ptr{Cvoid}, (intptr_t,), __delta)
end

function copy_file_range(__infd, __pinoff, __outfd, __poutoff, __length, __flags)
    ccall(:copy_file_range, ssize_t, (Cint, Ptr{__off64_t}, Cint, Ptr{__off64_t}, Csize_t, UInt32), __infd, __pinoff, __outfd, __poutoff, __length, __flags)
end

function fdatasync(__fildes)
    ccall(:fdatasync, Cint, (Cint,), __fildes)
end

function crypt(__key, __salt)
    ccall(:crypt, Cstring, (Cstring, Cstring), __key, __salt)
end

function swab(__from, __to, __n)
    ccall(:swab, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, ssize_t), __from, __to, __n)
end

function getentropy(__buffer, __length)
    ccall(:getentropy, Cint, (Ptr{Cvoid}, Csize_t), __buffer, __length)
end

function stat(__file, __buf)
    ccall(:stat, Cint, (Cstring, Ptr{stat}), __file, __buf)
end

function fstat(__fd, __buf)
    ccall(:fstat, Cint, (Cint, Ptr{stat}), __fd, __buf)
end

function stat64(__file, __buf)
    ccall(:stat64, Cint, (Cstring, Ptr{stat64}), __file, __buf)
end

function fstat64(__fd, __buf)
    ccall(:fstat64, Cint, (Cint, Ptr{stat64}), __fd, __buf)
end

function fstatat(__fd, __file, __buf, __flag)
    ccall(:fstatat, Cint, (Cint, Cstring, Ptr{stat}, Cint), __fd, __file, __buf, __flag)
end

function fstatat64(__fd, __file, __buf, __flag)
    ccall(:fstatat64, Cint, (Cint, Cstring, Ptr{stat64}, Cint), __fd, __file, __buf, __flag)
end

function lstat(__file, __buf)
    ccall(:lstat, Cint, (Cstring, Ptr{stat}), __file, __buf)
end

function lstat64(__file, __buf)
    ccall(:lstat64, Cint, (Cstring, Ptr{stat64}), __file, __buf)
end

function chmod(__file, __mode)
    ccall(:chmod, Cint, (Cstring, __mode_t), __file, __mode)
end

function lchmod(__file, __mode)
    ccall(:lchmod, Cint, (Cstring, __mode_t), __file, __mode)
end

function fchmod(__fd, __mode)
    ccall(:fchmod, Cint, (Cint, __mode_t), __fd, __mode)
end

function fchmodat(__fd, __file, __mode, __flag)
    ccall(:fchmodat, Cint, (Cint, Cstring, __mode_t, Cint), __fd, __file, __mode, __flag)
end

function umask(__mask)
    ccall(:umask, __mode_t, (__mode_t,), __mask)
end

function getumask()
    ccall(:getumask, __mode_t, ())
end

function mkdir(__path, __mode)
    ccall(:mkdir, Cint, (Cstring, __mode_t), __path, __mode)
end

function mkdirat(__fd, __path, __mode)
    ccall(:mkdirat, Cint, (Cint, Cstring, __mode_t), __fd, __path, __mode)
end

function mknod(__path, __mode, __dev)
    ccall(:mknod, Cint, (Cstring, __mode_t, __dev_t), __path, __mode, __dev)
end

function mknodat(__fd, __path, __mode, __dev)
    ccall(:mknodat, Cint, (Cint, Cstring, __mode_t, __dev_t), __fd, __path, __mode, __dev)
end

function mkfifo(__path, __mode)
    ccall(:mkfifo, Cint, (Cstring, __mode_t), __path, __mode)
end

function mkfifoat(__fd, __path, __mode)
    ccall(:mkfifoat, Cint, (Cint, Cstring, __mode_t), __fd, __path, __mode)
end

function utimensat(__fd, __path, __times, __flags)
    ccall(:utimensat, Cint, (Cint, Cstring, Ptr{timespec}, Cint), __fd, __path, __times, __flags)
end

function futimens(__fd, __times)
    ccall(:futimens, Cint, (Cint, Ptr{timespec}), __fd, __times)
end

function __fxstat(__ver, __fildes, __stat_buf)
    ccall(:__fxstat, Cint, (Cint, Cint, Ptr{stat}), __ver, __fildes, __stat_buf)
end

function __xstat(__ver, __filename, __stat_buf)
    ccall(:__xstat, Cint, (Cint, Cstring, Ptr{stat}), __ver, __filename, __stat_buf)
end

function __lxstat(__ver, __filename, __stat_buf)
    ccall(:__lxstat, Cint, (Cint, Cstring, Ptr{stat}), __ver, __filename, __stat_buf)
end

function __fxstatat(__ver, __fildes, __filename, __stat_buf, __flag)
    ccall(:__fxstatat, Cint, (Cint, Cint, Cstring, Ptr{stat}, Cint), __ver, __fildes, __filename, __stat_buf, __flag)
end

function __fxstat64(__ver, __fildes, __stat_buf)
    ccall(:__fxstat64, Cint, (Cint, Cint, Ptr{stat64}), __ver, __fildes, __stat_buf)
end

function __xstat64(__ver, __filename, __stat_buf)
    ccall(:__xstat64, Cint, (Cint, Cstring, Ptr{stat64}), __ver, __filename, __stat_buf)
end

function __lxstat64(__ver, __filename, __stat_buf)
    ccall(:__lxstat64, Cint, (Cint, Cstring, Ptr{stat64}), __ver, __filename, __stat_buf)
end

function __fxstatat64(__ver, __fildes, __filename, __stat_buf, __flag)
    ccall(:__fxstatat64, Cint, (Cint, Cint, Cstring, Ptr{stat64}, Cint), __ver, __fildes, __filename, __stat_buf, __flag)
end

function __xmknod(__ver, __path, __mode, __dev)
    ccall(:__xmknod, Cint, (Cint, Cstring, __mode_t, Ptr{__dev_t}), __ver, __path, __mode, __dev)
end

function __xmknodat(__ver, __fd, __path, __mode, __dev)
    ccall(:__xmknodat, Cint, (Cint, Cint, Cstring, __mode_t, Ptr{__dev_t}), __ver, __fd, __path, __mode, __dev)
end

function statx(__dirfd, __path, __flags, __mask, __buf)
    ccall(:statx, Cint, (Cint, Cstring, Cint, UInt32, Ptr{statx}), __dirfd, __path, __flags, __mask, __buf)
end

function __cmsg_nxthdr(__mhdr, __cmsg)
    ccall(:__cmsg_nxthdr, Ptr{cmsghdr}, (Ptr{msghdr}, Ptr{cmsghdr}), __mhdr, __cmsg)
end

function socket(__domain, __type, __protocol)
    ccall(:socket, Cint, (Cint, Cint, Cint), __domain, __type, __protocol)
end

function socketpair(__domain, __type, __protocol, __fds)
    ccall(:socketpair, Cint, (Cint, Cint, Cint, Ptr{Cint}), __domain, __type, __protocol, __fds)
end

function bind(__fd, __addr, __len)
    ccall(:bind, Cint, (Cint, __CONST_SOCKADDR_ARG, socklen_t), __fd, __addr, __len)
end

function getsockname(__fd, __addr, __len)
    ccall(:getsockname, Cint, (Cint, __SOCKADDR_ARG, Ptr{socklen_t}), __fd, __addr, __len)
end

function connect(__fd, __addr, __len)
    ccall(:connect, Cint, (Cint, __CONST_SOCKADDR_ARG, socklen_t), __fd, __addr, __len)
end

function getpeername(__fd, __addr, __len)
    ccall(:getpeername, Cint, (Cint, __SOCKADDR_ARG, Ptr{socklen_t}), __fd, __addr, __len)
end

function send(__fd, __buf, __n, __flags)
    ccall(:send, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint), __fd, __buf, __n, __flags)
end

function recv(__fd, __buf, __n, __flags)
    ccall(:recv, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint), __fd, __buf, __n, __flags)
end

function sendto(__fd, __buf, __n, __flags, __addr, __addr_len)
    ccall(:sendto, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint, __CONST_SOCKADDR_ARG, socklen_t), __fd, __buf, __n, __flags, __addr, __addr_len)
end

function recvfrom(__fd, __buf, __n, __flags, __addr, __addr_len)
    ccall(:recvfrom, ssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint, __SOCKADDR_ARG, Ptr{socklen_t}), __fd, __buf, __n, __flags, __addr, __addr_len)
end

function sendmsg(__fd, __message, __flags)
    ccall(:sendmsg, ssize_t, (Cint, Ptr{msghdr}, Cint), __fd, __message, __flags)
end

function sendmmsg(__fd, __vmessages, __vlen, __flags)
    ccall(:sendmmsg, Cint, (Cint, Ptr{mmsghdr}, UInt32, Cint), __fd, __vmessages, __vlen, __flags)
end

function recvmsg(__fd, __message, __flags)
    ccall(:recvmsg, ssize_t, (Cint, Ptr{msghdr}, Cint), __fd, __message, __flags)
end

function recvmmsg(__fd, __vmessages, __vlen, __flags, __tmo)
    ccall(:recvmmsg, Cint, (Cint, Ptr{mmsghdr}, UInt32, Cint, Ptr{timespec}), __fd, __vmessages, __vlen, __flags, __tmo)
end

function getsockopt(__fd, __level, __optname, __optval, __optlen)
    ccall(:getsockopt, Cint, (Cint, Cint, Cint, Ptr{Cvoid}, Ptr{socklen_t}), __fd, __level, __optname, __optval, __optlen)
end

function setsockopt(__fd, __level, __optname, __optval, __optlen)
    ccall(:setsockopt, Cint, (Cint, Cint, Cint, Ptr{Cvoid}, socklen_t), __fd, __level, __optname, __optval, __optlen)
end

function listen(__fd, __n)
    ccall(:listen, Cint, (Cint, Cint), __fd, __n)
end

function accept(__fd, __addr, __addr_len)
    ccall(:accept, Cint, (Cint, __SOCKADDR_ARG, Ptr{socklen_t}), __fd, __addr, __addr_len)
end

function accept4(__fd, __addr, __addr_len, __flags)
    ccall(:accept4, Cint, (Cint, __SOCKADDR_ARG, Ptr{socklen_t}, Cint), __fd, __addr, __addr_len, __flags)
end

function shutdown(__fd, __how)
    ccall(:shutdown, Cint, (Cint, Cint), __fd, __how)
end

function sockatmark(__fd)
    ccall(:sockatmark, Cint, (Cint,), __fd)
end

function isfdtype(__fd, __fdtype)
    ccall(:isfdtype, Cint, (Cint, Cint), __fd, __fdtype)
end

function __sysv_signal(__sig, __handler)
    ccall(:__sysv_signal, __sighandler_t, (Cint, __sighandler_t), __sig, __handler)
end

function sysv_signal(__sig, __handler)
    ccall(:sysv_signal, __sighandler_t, (Cint, __sighandler_t), __sig, __handler)
end

function signal(__sig, __handler)
    ccall(:signal, __sighandler_t, (Cint, __sighandler_t), __sig, __handler)
end

function kill(__pid, __sig)
    ccall(:kill, Cint, (__pid_t, Cint), __pid, __sig)
end

function killpg(__pgrp, __sig)
    ccall(:killpg, Cint, (__pid_t, Cint), __pgrp, __sig)
end

function raise(__sig)
    ccall(:raise, Cint, (Cint,), __sig)
end

function ssignal(__sig, __handler)
    ccall(:ssignal, __sighandler_t, (Cint, __sighandler_t), __sig, __handler)
end

function gsignal(__sig)
    ccall(:gsignal, Cint, (Cint,), __sig)
end

function psignal(__sig, __s)
    ccall(:psignal, Cvoid, (Cint, Cstring), __sig, __s)
end

function psiginfo(__pinfo, __s)
    ccall(:psiginfo, Cvoid, (Ptr{siginfo_t}, Cstring), __pinfo, __s)
end

function sigpause(__sig)
    ccall(:sigpause, Cint, (Cint,), __sig)
end

function sigblock(__mask)
    ccall(:sigblock, Cint, (Cint,), __mask)
end

function sigsetmask(__mask)
    ccall(:sigsetmask, Cint, (Cint,), __mask)
end

function siggetmask()
    ccall(:siggetmask, Cint, ())
end

function sigemptyset(__set)
    ccall(:sigemptyset, Cint, (Ptr{sigset_t},), __set)
end

function sigfillset(__set)
    ccall(:sigfillset, Cint, (Ptr{sigset_t},), __set)
end

function sigaddset(__set, __signo)
    ccall(:sigaddset, Cint, (Ptr{sigset_t}, Cint), __set, __signo)
end

function sigdelset(__set, __signo)
    ccall(:sigdelset, Cint, (Ptr{sigset_t}, Cint), __set, __signo)
end

function sigismember(__set, __signo)
    ccall(:sigismember, Cint, (Ptr{sigset_t}, Cint), __set, __signo)
end

function sigisemptyset(__set)
    ccall(:sigisemptyset, Cint, (Ptr{sigset_t},), __set)
end

function sigandset(__set, __left, __right)
    ccall(:sigandset, Cint, (Ptr{sigset_t}, Ptr{sigset_t}, Ptr{sigset_t}), __set, __left, __right)
end

function sigorset(__set, __left, __right)
    ccall(:sigorset, Cint, (Ptr{sigset_t}, Ptr{sigset_t}, Ptr{sigset_t}), __set, __left, __right)
end

function sigprocmask(__how, __set, __oset)
    ccall(:sigprocmask, Cint, (Cint, Ptr{sigset_t}, Ptr{sigset_t}), __how, __set, __oset)
end

function sigsuspend(__set)
    ccall(:sigsuspend, Cint, (Ptr{sigset_t},), __set)
end

function sigaction(__sig, __act, __oact)
    ccall(:sigaction, Cint, (Cint, Ptr{sigaction}, Ptr{sigaction}), __sig, __act, __oact)
end

function sigpending(__set)
    ccall(:sigpending, Cint, (Ptr{sigset_t},), __set)
end

function sigwait(__set, __sig)
    ccall(:sigwait, Cint, (Ptr{sigset_t}, Ptr{Cint}), __set, __sig)
end

function sigwaitinfo(__set, __info)
    ccall(:sigwaitinfo, Cint, (Ptr{sigset_t}, Ptr{siginfo_t}), __set, __info)
end

function sigtimedwait(__set, __info, __timeout)
    ccall(:sigtimedwait, Cint, (Ptr{sigset_t}, Ptr{siginfo_t}, Ptr{timespec}), __set, __info, __timeout)
end

function sigqueue(__pid, __sig, __val)
    ccall(:sigqueue, Cint, (__pid_t, Cint, sigval), __pid, __sig, __val)
end

function sigreturn(__scp)
    ccall(:sigreturn, Cint, (Ptr{sigcontext},), __scp)
end

function siginterrupt(__sig, __interrupt)
    ccall(:siginterrupt, Cint, (Cint, Cint), __sig, __interrupt)
end

function sigaltstack(__ss, __oss)
    ccall(:sigaltstack, Cint, (Ptr{stack_t}, Ptr{stack_t}), __ss, __oss)
end

function sighold(__sig)
    ccall(:sighold, Cint, (Cint,), __sig)
end

function sigrelse(__sig)
    ccall(:sigrelse, Cint, (Cint,), __sig)
end

function sigignore(__sig)
    ccall(:sigignore, Cint, (Cint,), __sig)
end

function sigset(__sig, __disp)
    ccall(:sigset, __sighandler_t, (Cint, __sighandler_t), __sig, __disp)
end

function pthread_sigmask(__how, __newmask, __oldmask)
    ccall(:pthread_sigmask, Cint, (Cint, Ptr{__sigset_t}, Ptr{__sigset_t}), __how, __newmask, __oldmask)
end

function pthread_kill(__threadid, __signo)
    ccall(:pthread_kill, Cint, (pthread_t, Cint), __threadid, __signo)
end

function pthread_sigqueue(__threadid, __signo, __value)
    ccall(:pthread_sigqueue, Cint, (pthread_t, Cint, sigval), __threadid, __signo, __value)
end

function __libc_current_sigrtmin()
    ccall(:__libc_current_sigrtmin, Cint, ())
end

function __libc_current_sigrtmax()
    ccall(:__libc_current_sigrtmax, Cint, ())
end

function wait(__stat_loc)
    ccall(:wait, __pid_t, (Ptr{Cint},), __stat_loc)
end

function waitpid(__pid, __stat_loc, __options)
    ccall(:waitpid, __pid_t, (__pid_t, Ptr{Cint}, Cint), __pid, __stat_loc, __options)
end

function wait3(__stat_loc, __options, __usage)
    ccall(:wait3, __pid_t, (Ptr{Cint}, Cint, Ptr{rusage}), __stat_loc, __options, __usage)
end

function wait4(__pid, __stat_loc, __options, __usage)
    ccall(:wait4, __pid_t, (__pid_t, Ptr{Cint}, Cint, Ptr{rusage}), __pid, __stat_loc, __options, __usage)
end

function posix_spawn(__pid, __path, __file_actions, __attrp, __argv, __envp)
    ccall(:posix_spawn, Cint, (Ptr{pid_t}, Cstring, Ptr{posix_spawn_file_actions_t}, Ptr{posix_spawnattr_t}, Ptr{Cstring}, Ptr{Cstring}), __pid, __path, __file_actions, __attrp, __argv, __envp)
end

function posix_spawnp(__pid, __file, __file_actions, __attrp, __argv, __envp)
    ccall(:posix_spawnp, Cint, (Ptr{pid_t}, Cstring, Ptr{posix_spawn_file_actions_t}, Ptr{posix_spawnattr_t}, Ptr{Cstring}, Ptr{Cstring}), __pid, __file, __file_actions, __attrp, __argv, __envp)
end

function posix_spawnattr_init(__attr)
    ccall(:posix_spawnattr_init, Cint, (Ptr{posix_spawnattr_t},), __attr)
end

function posix_spawnattr_destroy(__attr)
    ccall(:posix_spawnattr_destroy, Cint, (Ptr{posix_spawnattr_t},), __attr)
end

function posix_spawnattr_getsigdefault(__attr, __sigdefault)
    ccall(:posix_spawnattr_getsigdefault, Cint, (Ptr{posix_spawnattr_t}, Ptr{sigset_t}), __attr, __sigdefault)
end

function posix_spawnattr_setsigdefault(__attr, __sigdefault)
    ccall(:posix_spawnattr_setsigdefault, Cint, (Ptr{posix_spawnattr_t}, Ptr{sigset_t}), __attr, __sigdefault)
end

function posix_spawnattr_getsigmask(__attr, __sigmask)
    ccall(:posix_spawnattr_getsigmask, Cint, (Ptr{posix_spawnattr_t}, Ptr{sigset_t}), __attr, __sigmask)
end

function posix_spawnattr_setsigmask(__attr, __sigmask)
    ccall(:posix_spawnattr_setsigmask, Cint, (Ptr{posix_spawnattr_t}, Ptr{sigset_t}), __attr, __sigmask)
end

function posix_spawnattr_getflags(__attr, __flags)
    ccall(:posix_spawnattr_getflags, Cint, (Ptr{posix_spawnattr_t}, Ptr{Int16}), __attr, __flags)
end

function posix_spawnattr_setflags(_attr, __flags)
    ccall(:posix_spawnattr_setflags, Cint, (Ptr{posix_spawnattr_t}, Int16), _attr, __flags)
end

function posix_spawnattr_getpgroup(__attr, __pgroup)
    ccall(:posix_spawnattr_getpgroup, Cint, (Ptr{posix_spawnattr_t}, Ptr{pid_t}), __attr, __pgroup)
end

function posix_spawnattr_setpgroup(__attr, __pgroup)
    ccall(:posix_spawnattr_setpgroup, Cint, (Ptr{posix_spawnattr_t}, pid_t), __attr, __pgroup)
end

function posix_spawnattr_getschedpolicy(__attr, __schedpolicy)
    ccall(:posix_spawnattr_getschedpolicy, Cint, (Ptr{posix_spawnattr_t}, Ptr{Cint}), __attr, __schedpolicy)
end

function posix_spawnattr_setschedpolicy(__attr, __schedpolicy)
    ccall(:posix_spawnattr_setschedpolicy, Cint, (Ptr{posix_spawnattr_t}, Cint), __attr, __schedpolicy)
end

function posix_spawnattr_getschedparam(__attr, __schedparam)
    ccall(:posix_spawnattr_getschedparam, Cint, (Ptr{posix_spawnattr_t}, Ptr{sched_param}), __attr, __schedparam)
end

function posix_spawnattr_setschedparam(__attr, __schedparam)
    ccall(:posix_spawnattr_setschedparam, Cint, (Ptr{posix_spawnattr_t}, Ptr{sched_param}), __attr, __schedparam)
end

function posix_spawn_file_actions_init(__file_actions)
    ccall(:posix_spawn_file_actions_init, Cint, (Ptr{posix_spawn_file_actions_t},), __file_actions)
end

function posix_spawn_file_actions_destroy(__file_actions)
    ccall(:posix_spawn_file_actions_destroy, Cint, (Ptr{posix_spawn_file_actions_t},), __file_actions)
end

function posix_spawn_file_actions_addopen(__file_actions, __fd, __path, __oflag, __mode)
    ccall(:posix_spawn_file_actions_addopen, Cint, (Ptr{posix_spawn_file_actions_t}, Cint, Cstring, Cint, mode_t), __file_actions, __fd, __path, __oflag, __mode)
end

function posix_spawn_file_actions_addclose(__file_actions, __fd)
    ccall(:posix_spawn_file_actions_addclose, Cint, (Ptr{posix_spawn_file_actions_t}, Cint), __file_actions, __fd)
end

function posix_spawn_file_actions_adddup2(__file_actions, __fd, __newfd)
    ccall(:posix_spawn_file_actions_adddup2, Cint, (Ptr{posix_spawn_file_actions_t}, Cint, Cint), __file_actions, __fd, __newfd)
end

const EPERM = 1

const ENOENT = 2

const ESRCH = 3

const EINTR = 4

const EIO = 5

const ENXIO = 6

const E2BIG = 7

const ENOEXEC = 8

const EBADF = 9

const ECHILD = 10

const EAGAIN = 11

const ENOMEM = 12

const EACCES = 13

const EFAULT = 14

const ENOTBLK = 15

const EBUSY = 16

const EEXIST = 17

const EXDEV = 18

const ENODEV = 19

const ENOTDIR = 20

const EISDIR = 21

const EINVAL = 22

const ENFILE = 23

const EMFILE = 24

const ENOTTY = 25

const ETXTBSY = 26

const EFBIG = 27

const ENOSPC = 28

const ESPIPE = 29

const EROFS = 30

const EMLINK = 31

const EPIPE = 32

const EDOM = 33

const ERANGE = 34

const EDEADLK = 35

const ENAMETOOLONG = 36

const ENOLCK = 37

const ENOSYS = 38

const ENOTEMPTY = 39

const ELOOP = 40

const EWOULDBLOCK = 11

const ENOMSG = 42

const EIDRM = 43

const ECHRNG = 44

const EL2NSYNC = 45

const EL3HLT = 46

const EL3RST = 47

const ELNRNG = 48

const EUNATCH = 49

const ENOCSI = 50

const EL2HLT = 51

const EBADE = 52

const EBADR = 53

const EXFULL = 54

const ENOANO = 55

const EBADRQC = 56

const EBADSLT = 57

const EDEADLOCK = 35

const EBFONT = 59

const ENOSTR = 60

const ENODATA = 61

const ETIME = 62

const ENOSR = 63

const ENONET = 64

const ENOPKG = 65

const EREMOTE = 66

const ENOLINK = 67

const EADV = 68

const ESRMNT = 69

const ECOMM = 70

const EPROTO = 71

const EMULTIHOP = 72

const EDOTDOT = 73

const EBADMSG = 74

const EOVERFLOW = 75

const ENOTUNIQ = 76

const EBADFD = 77

const EREMCHG = 78

const ELIBACC = 79

const ELIBBAD = 80

const ELIBSCN = 81

const ELIBMAX = 82

const ELIBEXEC = 83

const EILSEQ = 84

const ERESTART = 85

const ESTRPIPE = 86

const EUSERS = 87

const ENOTSOCK = 88

const EDESTADDRREQ = 89

const EMSGSIZE = 90

const EPROTOTYPE = 91

const ENOPROTOOPT = 92

const EPROTONOSUPPORT = 93

const ESOCKTNOSUPPORT = 94

const EOPNOTSUPP = 95

const EPFNOSUPPORT = 96

const EAFNOSUPPORT = 97

const EADDRINUSE = 98

const EADDRNOTAVAIL = 99

const ENETDOWN = 100

const ENETUNREACH = 101

const ENETRESET = 102

const ECONNABORTED = 103

const ECONNRESET = 104

const ENOBUFS = 105

const EISCONN = 106

const ENOTCONN = 107

const ESHUTDOWN = 108

const ETOOMANYREFS = 109

const ETIMEDOUT = 110

const ECONNREFUSED = 111

const EHOSTDOWN = 112

const EHOSTUNREACH = 113

const EALREADY = 114

const EINPROGRESS = 115

const ESTALE = 116

const EUCLEAN = 117

const ENOTNAM = 118

const ENAVAIL = 119

const EISNAM = 120

const EREMOTEIO = 121

const EDQUOT = 122

const ENOMEDIUM = 123

const EMEDIUMTYPE = 124

const ECANCELED = 125

const ENOKEY = 126

const EKEYEXPIRED = 127

const EKEYREVOKED = 128

const EKEYREJECTED = 129

const EOWNERDEAD = 130

const ENOTRECOVERABLE = 131

const ERFKILL = 132

const EHWPOISON = 133

const ENOTSUP = 95

const MB_LEN_MAX = 16

const CHAR_BIT = 8

const SCHAR_MAX = 127

const CHAR_MIN = 0

const CHAR_MAX = 255

const SHRT_MAX = 32767

const INT_MAX = 2147483647

const LONG_MAX = 2147483647

const LLONG_MAX = 9223372036854775807

const LONG_LONG_MAX = 9223372036854775807

const CHAR_WIDTH = 8

const SCHAR_WIDTH = 8

const UCHAR_WIDTH = 8

const SHRT_WIDTH = 16

const USHRT_WIDTH = 16

const INT_WIDTH = 32

const UINT_WIDTH = 32

const LONG_WIDTH = 32

const ULONG_WIDTH = 32

const LLONG_WIDTH = 64

const ULLONG_WIDTH = 64

const NGROUPS_MAX = 65536

const MAX_CANON = 255

const MAX_INPUT = 255

const NAME_MAX = 255

const PATH_MAX = 4096

const PIPE_BUF = 4096

const XATTR_NAME_MAX = 255

const XATTR_SIZE_MAX = 65536

const XATTR_LIST_MAX = 65536

const RTSIG_MAX = 32

const PTHREAD_KEYS_MAX = 1024

const PTHREAD_DESTRUCTOR_ITERATIONS = 4

const AIO_PRIO_DELTA_MAX = 20

const PTHREAD_STACK_MIN = 16384

const DELAYTIMER_MAX = 2147483647

const TTY_NAME_MAX = 32

const LOGIN_NAME_MAX = 256

const HOST_NAME_MAX = 64

const MQ_PRIO_MAX = 32768

const SSIZE_MAX = 2147483647

const BC_BASE_MAX = 99

const BC_DIM_MAX = 2048

const BC_SCALE_MAX = 99

const BC_STRING_MAX = 1000

const COLL_WEIGHTS_MAX = 255

const EXPR_NEST_MAX = 32

const LINE_MAX = 2048

const CHARCLASS_NAME_MAX = 2048

const IOV_MAX = 1024

const NL_ARGMAX = 4096

const NL_LANGMAX = 2048

const NL_MSGMAX = 2147483647

const NL_NMAX = 2147483647

const NL_SETMAX = 2147483647

const NL_TEXTMAX = 2147483647

const NZERO = 20

const WORD_BIT = 32

const LONG_BIT = 32

const WNOHANG = 1

const WUNTRACED = 2

const WSTOPPED = 2

const WEXITED = 4

const WCONTINUED = 8

const WNOWAIT = 16777216

const RAND_MAX = 2147483647

const EXIT_FAILURE = 1

const EXIT_SUCCESS = 0

const LITTLE_ENDIAN = 1234

const BIG_ENDIAN = 4321

const PDP_ENDIAN = 3412

const BYTE_ORDER = 1234

const FD_SETSIZE = 1024

const NFDBITS = 32

const SCHED_OTHER = 0

const SCHED_FIFO = 1

const SCHED_RR = 2

const SCHED_BATCH = 3

const SCHED_ISO = 4

const SCHED_IDLE = 5

const SCHED_DEADLINE = 6

const SCHED_RESET_ON_FORK = 1073741824

const CSIGNAL = 255

const CLONE_VM = 256

const CLONE_FS = 512

const CLONE_FILES = 1024

const CLONE_SIGHAND = 2048

const CLONE_PTRACE = 8192

const CLONE_VFORK = 16384

const CLONE_PARENT = 32768

const CLONE_THREAD = 65536

const CLONE_NEWNS = 131072

const CLONE_SYSVSEM = 262144

const CLONE_SETTLS = 524288

const CLONE_PARENT_SETTID = 1048576

const CLONE_CHILD_CLEARTID = 2097152

const CLONE_DETACHED = 4194304

const CLONE_UNTRACED = 8388608

const CLONE_CHILD_SETTID = 16777216

const CLONE_NEWCGROUP = 33554432

const CLONE_NEWUTS = 67108864

const CLONE_NEWIPC = 134217728

const CLONE_NEWUSER = 268435456

const CLONE_NEWPID = 536870912

const CLONE_NEWNET = 1073741824

const CLONE_IO = 2147483648

const CPU_SETSIZE = 1024

const CLOCK_REALTIME = 0

const CLOCK_MONOTONIC = 1

const CLOCK_PROCESS_CPUTIME_ID = 2

const CLOCK_THREAD_CPUTIME_ID = 3

const CLOCK_MONOTONIC_RAW = 4

const CLOCK_REALTIME_COARSE = 5

const CLOCK_MONOTONIC_COARSE = 6

const CLOCK_BOOTTIME = 7

const CLOCK_REALTIME_ALARM = 8

const CLOCK_BOOTTIME_ALARM = 9

const CLOCK_TAI = 11

const TIMER_ABSTIME = 1

const ADJ_OFFSET = 1

const ADJ_FREQUENCY = 2

const ADJ_MAXERROR = 4

const ADJ_ESTERROR = 8

const ADJ_STATUS = 16

const ADJ_TIMECONST = 32

const ADJ_TAI = 128

const ADJ_SETOFFSET = 256

const ADJ_MICRO = 4096

const ADJ_NANO = 8192

const ADJ_TICK = 16384

const ADJ_OFFSET_SINGLESHOT = 32769

const ADJ_OFFSET_SS_READ = 40961

const MOD_OFFSET = 1

const MOD_FREQUENCY = 2

const MOD_MAXERROR = 4

const MOD_ESTERROR = 8

const MOD_STATUS = 16

const MOD_TIMECONST = 32

const MOD_CLKB = 16384

const MOD_CLKA = 32769

const MOD_TAI = 128

const MOD_MICRO = 4096

const MOD_NANO = 8192

const STA_PLL = 1

const STA_PPSFREQ = 2

const STA_PPSTIME = 4

const STA_FLL = 8

const STA_INS = 16

const STA_DEL = 32

const STA_UNSYNC = 64

const STA_FREQHOLD = 128

const STA_PPSSIGNAL = 256

const STA_PPSJITTER = 512

const STA_PPSWANDER = 1024

const STA_PPSERROR = 2048

const STA_CLOCKERR = 4096

const STA_NANO = 8192

const STA_MODE = 16384

const STA_CLK = 32768

const TIME_UTC = 1

const PTHREAD_ONCE_INIT = 0

const PTHREAD_BARRIER_SERIAL_THREAD = -1

const FIOQSIZE = 21598

const TCGETS = 21505

const TCSETS = 21506

const TCSETSW = 21507

const TCSETSF = 21508

const TCGETA = 21509

const TCSETA = 21510

const TCSETAW = 21511

const TCSETAF = 21512

const TCSBRK = 21513

const TCXONC = 21514

const TCFLSH = 21515

const TIOCEXCL = 21516

const TIOCNXCL = 21517

const TIOCSCTTY = 21518

const TIOCGPGRP = 21519

const TIOCSPGRP = 21520

const TIOCOUTQ = 21521

const TIOCSTI = 21522

const TIOCGWINSZ = 21523

const TIOCSWINSZ = 21524

const TIOCMGET = 21525

const TIOCMBIS = 21526

const TIOCMBIC = 21527

const TIOCMSET = 21528

const TIOCGSOFTCAR = 21529

const TIOCSSOFTCAR = 21530

const FIONREAD = 21531

const TIOCINQ = 21531

const TIOCLINUX = 21532

const TIOCCONS = 21533

const TIOCGSERIAL = 21534

const TIOCSSERIAL = 21535

const TIOCPKT = 21536

const FIONBIO = 21537

const TIOCNOTTY = 21538

const TIOCSETD = 21539

const TIOCGETD = 21540

const TCSBRKP = 21541

const TIOCSBRK = 21543

const TIOCCBRK = 21544

const TIOCGSID = 21545

const TIOCGRS485 = 21550

const TIOCSRS485 = 21551

const TIOCGPTN = 2147767344

const TIOCSPTLCK = 1074025521

const TIOCGDEV = 2147767346

const TCGETX = 21554

const TCSETX = 21555

const TCSETXF = 21556

const TCSETXW = 21557

const TIOCSIG = 1074025526

const TIOCVHANGUP = 21559

const TIOCGPKT = 2147767352

const TIOCGPTLCK = 2147767353

const TIOCGEXCL = 2147767360

const TIOCGPTPEER = 21569

const FIONCLEX = 21584

const FIOCLEX = 21585

const FIOASYNC = 21586

const TIOCSERCONFIG = 21587

const TIOCSERGWILD = 21588

const TIOCSERSWILD = 21589

const TIOCGLCKTRMIOS = 21590

const TIOCSLCKTRMIOS = 21591

const TIOCSERGSTRUCT = 21592

const TIOCSERGETLSR = 21593

const TIOCSERGETMULTI = 21594

const TIOCSERSETMULTI = 21595

const TIOCMIWAIT = 21596

const TIOCGICOUNT = 21597

const TIOCPKT_DATA = 0

const TIOCPKT_FLUSHREAD = 1

const TIOCPKT_FLUSHWRITE = 2

const TIOCPKT_STOP = 4

const TIOCPKT_START = 8

const TIOCPKT_NOSTOP = 16

const TIOCPKT_DOSTOP = 32

const TIOCPKT_IOCTL = 64

const TIOCSER_TEMT = 1

const SIOGIFINDEX = 35123

const NCC = 8

const TIOCM_LE = 1

const TIOCM_DTR = 2

const TIOCM_RTS = 4

const TIOCM_ST = 8

const TIOCM_SR = 16

const TIOCM_CTS = 32

const TIOCM_CAR = 64

const TIOCM_RNG = 128

const TIOCM_DSR = 256

const TIOCM_CD = 64

const TIOCM_RI = 128

const N_TTY = 0

const N_SLIP = 1

const N_MOUSE = 2

const N_PPP = 3

const N_STRIP = 4

const N_AX25 = 5

const N_X25 = 6

const N_6PACK = 7

const N_MASC = 8

const N_R3964 = 9

const N_PROFIBUS_FDL = 10

const N_IRDA = 11

const N_SMSBLOCK = 12

const N_HDLC = 13

const N_SYNC_PPP = 14

const N_HCI = 15

const CEOF = 4

const CEOL = Char(0)

const CERASE = 127

const CINTR = 3

const CSTATUS = Char(0)

const CKILL = 21

const CMIN = 1

const CQUIT = 28

const CSUSP = 26

const CTIME = 0

const CDSUSP = 25

const CSTART = 17

const CSTOP = 19

const CLNEXT = 22

const CDISCARD = 15

const CWERASE = 23

const CREPRINT = 18

const CEOT = 4

const CBRK = Char(0)

const CRPRNT = 18

const CFLUSH = 15

const NCCS = 32

const VINTR = 0

const VQUIT = 1

const VERASE = 2

const VKILL = 3

const VEOF = 4

const VTIME = 5

const VMIN = 6

const VSWTC = 7

const VSTART = 8

const VSTOP = 9

const VSUSP = 10

const VEOL = 11

const VREPRINT = 12

const VDISCARD = 13

const VWERASE = 14

const VLNEXT = 15

const VEOL2 = 16

const IGNBRK = 1

const BRKINT = 2

const IGNPAR = 4

const PARMRK = 8

const INPCK = 16

const ISTRIP = 32

const INLCR = 64

const IGNCR = 128

const ICRNL = 256

const IUCLC = 512

const IXON = 1024

const IXANY = 2048

const IXOFF = 4096

const IMAXBEL = 8192

const IUTF8 = 16384

const OPOST = 1

const OLCUC = 2

const ONLCR = 4

const OCRNL = 8

const ONOCR = 16

const ONLRET = 32

const OFILL = 64

const OFDEL = 128

const NLDLY = 256

const NL0 = 0

const NL1 = 256

const CRDLY = 1536

const CR0 = 0

const CR1 = 512

const CR2 = 1024

const CR3 = 1536

const TABDLY = 6144

const TAB0 = 0

const TAB1 = 2048

const TAB2 = 4096

const TAB3 = 6144

const BSDLY = 8192

const BS0 = 0

const BS1 = 8192

const FFDLY = 32768

const FF0 = 0

const FF1 = 32768

const VTDLY = 16384

const VT0 = 0

const VT1 = 16384

const XTABS = 6144

const CBAUD = 4111

const B0 = 0

const B50 = 1

const B75 = 2

const B110 = 3

const B134 = 4

const B150 = 5

const B200 = 6

const B300 = 7

const B600 = 8

const B1200 = 9

const B1800 = 10

const B2400 = 11

const B4800 = 12

const B9600 = 13

const B19200 = 14

const B38400 = 15

const EXTA = 14

const EXTB = 15

const CSIZE = 48

const CS5 = 0

const CS6 = 16

const CS7 = 32

const CS8 = 48

const CSTOPB = 64

const CREAD = 128

const PARENB = 256

const PARODD = 512

const HUPCL = 1024

const CLOCAL = 2048

const CBAUDEX = 4096

const B57600 = 4097

const B115200 = 4098

const B230400 = 4099

const B460800 = 4100

const B500000 = 4101

const B576000 = 4102

const B921600 = 4103

const B1000000 = 4104

const B1152000 = 4105

const B1500000 = 4106

const B2000000 = 4107

const B2500000 = 4108

const B3000000 = 4109

const B3500000 = 4110

const B4000000 = 4111

const CIBAUD = 269418496

const CMSPAR = 1073741824

const CRTSCTS = 2147483648

const ISIG = 1

const ICANON = 2

const XCASE = 4

const ECHO = 8

const ECHOE = 16

const ECHOK = 32

const ECHONL = 64

const NOFLSH = 128

const TOSTOP = 256

const ECHOCTL = 512

const ECHOPRT = 1024

const ECHOKE = 2048

const FLUSHO = 4096

const PENDIN = 16384

const IEXTEN = 32768

const EXTPROC = 65536

const TCOOFF = 0

const TCOON = 1

const TCIOFF = 2

const TCION = 3

const TCIFLUSH = 0

const TCOFLUSH = 1

const TCIOFLUSH = 2

const TCSANOW = 0

const TCSADRAIN = 1

const TCSAFLUSH = 2

const O_ACCMODE = 3

const O_RDONLY = 0

const O_WRONLY = 1

const O_RDWR = 2

const O_CREAT = 64

const O_EXCL = 128

const O_NOCTTY = 256

const O_TRUNC = 512

const O_APPEND = 1024

const O_NONBLOCK = 2048

const O_NDELAY = 2048

const O_SYNC = 1052672

const O_FSYNC = 1052672

const O_ASYNC = 8192

const F_GETLK = 5

const F_SETLK = 6

const F_SETLKW = 7

const F_GETLK64 = 12

const F_SETLK64 = 13

const F_SETLKW64 = 14

const F_OFD_GETLK = 36

const F_OFD_SETLK = 37

const F_OFD_SETLKW = 38

const O_LARGEFILE = 131072

const O_DIRECTORY = 16384

const O_NOFOLLOW = 32768

const O_CLOEXEC = 524288

const O_DIRECT = 65536

const O_NOATIME = 262144

const O_PATH = 2097152

const O_TMPFILE = 4210688

const O_DSYNC = 4096

const O_RSYNC = 1052672

const F_DUPFD = 0

const F_GETFD = 1

const F_SETFD = 2

const F_GETFL = 3

const F_SETFL = 4

const F_SETOWN = 8

const F_GETOWN = 9

const F_SETSIG = 10

const F_GETSIG = 11

const F_SETOWN_EX = 15

const F_GETOWN_EX = 16

const F_SETLEASE = 1024

const F_GETLEASE = 1025

const F_NOTIFY = 1026

const F_SETPIPE_SZ = 1031

const F_GETPIPE_SZ = 1032

const F_ADD_SEALS = 1033

const F_GET_SEALS = 1034

const F_GET_RW_HINT = 1035

const F_SET_RW_HINT = 1036

const F_GET_FILE_RW_HINT = 1037

const F_SET_FILE_RW_HINT = 1038

const F_DUPFD_CLOEXEC = 1030

const FD_CLOEXEC = 1

const F_RDLCK = 0

const F_WRLCK = 1

const F_UNLCK = 2

const F_EXLCK = 4

const F_SHLCK = 8

const LOCK_SH = 1

const LOCK_EX = 2

const LOCK_NB = 4

const LOCK_UN = 8

const LOCK_MAND = 32

const LOCK_READ = 64

const LOCK_WRITE = 128

const LOCK_RW = 192

const DN_ACCESS = 1

const DN_MODIFY = 2

const DN_CREATE = 4

const DN_DELETE = 8

const DN_RENAME = 16

const DN_ATTRIB = 32

const DN_MULTISHOT = 2147483648

const F_SEAL_SEAL = 1

const F_SEAL_SHRINK = 2

const F_SEAL_GROW = 4

const F_SEAL_WRITE = 8

const RWF_WRITE_LIFE_NOT_SET = 0

const RWH_WRITE_LIFE_NONE = 1

const RWH_WRITE_LIFE_SHORT = 2

const RWH_WRITE_LIFE_MEDIUM = 3

const RWH_WRITE_LIFE_LONG = 4

const RWH_WRITE_LIFE_EXTREME = 5

const FAPPEND = 1024

const FFSYNC = 1052672

const FASYNC = 8192

const FNONBLOCK = 2048

const FNDELAY = 2048

const POSIX_FADV_NORMAL = 0

const POSIX_FADV_RANDOM = 1

const POSIX_FADV_SEQUENTIAL = 2

const POSIX_FADV_WILLNEED = 3

const POSIX_FADV_DONTNEED = 4

const POSIX_FADV_NOREUSE = 5

const SYNC_FILE_RANGE_WAIT_BEFORE = 1

const SYNC_FILE_RANGE_WRITE = 2

const SYNC_FILE_RANGE_WAIT_AFTER = 4

const SPLICE_F_MOVE = 1

const SPLICE_F_NONBLOCK = 2

const SPLICE_F_MORE = 4

const SPLICE_F_GIFT = 8

const FALLOC_FL_KEEP_SIZE = 1

const FALLOC_FL_PUNCH_HOLE = 2

const FALLOC_FL_NO_HIDE_STALE = 4

const FALLOC_FL_COLLAPSE_RANGE = 8

const FALLOC_FL_ZERO_RANGE = 16

const FALLOC_FL_INSERT_RANGE = 32

const FALLOC_FL_UNSHARE_RANGE = 64

const MAX_HANDLE_SZ = 128

const AT_FDCWD = -100

const AT_SYMLINK_NOFOLLOW = 256

const AT_REMOVEDIR = 512

const AT_SYMLINK_FOLLOW = 1024

const AT_NO_AUTOMOUNT = 2048

const AT_EMPTY_PATH = 4096

const AT_STATX_SYNC_TYPE = 24576

const AT_STATX_SYNC_AS_STAT = 0

const AT_STATX_FORCE_SYNC = 8192

const AT_STATX_DONT_SYNC = 16384

const AT_EACCESS = 512

const S_IFMT = 61440

const S_IFDIR = 16384

const S_IFCHR = 8192

const S_IFBLK = 24576

const S_IFREG = 32768

const S_IFIFO = 4096

const S_IFLNK = 40960

const S_IFSOCK = 49152

const S_ISUID = 2048

const S_ISGID = 1024

const S_ISVTX = 512

const S_IRUSR = 256

const S_IWUSR = 128

const S_IXUSR = 64

const R_OK = 4

const W_OK = 2

const X_OK = 1

const F_OK = 0

const SEEK_SET = 0

const SEEK_CUR = 1

const SEEK_END = 2

const F_ULOCK = 0

const F_LOCK = 1

const F_TLOCK = 2

const F_TEST = 3

const POLLIN = 1

const POLLPRI = 2

const POLLOUT = 4

const POLLRDNORM = 64

const POLLRDBAND = 128

const POLLWRNORM = 256

const POLLWRBAND = 512

const POLLMSG = 1024

const POLLREMOVE = 4096

const POLLRDHUP = 8192

const POLLERR = 8

const POLLHUP = 16

const POLLNVAL = 32

const WCHAR_MIN = 0

const WCHAR_MAX = 4294967295

const INT8_WIDTH = 8

const UINT8_WIDTH = 8

const INT16_WIDTH = 16

const UINT16_WIDTH = 16

const INT32_WIDTH = 32

const UINT32_WIDTH = 32

const INT64_WIDTH = 64

const UINT64_WIDTH = 64

const INT_LEAST8_WIDTH = 8

const UINT_LEAST8_WIDTH = 8

const INT_LEAST16_WIDTH = 16

const UINT_LEAST16_WIDTH = 16

const INT_LEAST32_WIDTH = 32

const UINT_LEAST32_WIDTH = 32

const INT_LEAST64_WIDTH = 64

const UINT_LEAST64_WIDTH = 64

const INT_FAST8_WIDTH = 8

const UINT_FAST8_WIDTH = 8

const INT_FAST16_WIDTH = 32

const UINT_FAST16_WIDTH = 32

const INT_FAST32_WIDTH = 32

const UINT_FAST32_WIDTH = 32

const INT_FAST64_WIDTH = 64

const UINT_FAST64_WIDTH = 64

const INTPTR_WIDTH = 32

const UINTPTR_WIDTH = 32

const INTMAX_WIDTH = 64

const UINTMAX_WIDTH = 64

const PTRDIFF_WIDTH = 32

const SIG_ATOMIC_WIDTH = 32

const SIZE_WIDTH = 32

const WCHAR_WIDTH = 32

const WINT_WIDTH = 32

const EPOLLIN = 1

const EPOLLPRI = 2

const EPOLLOUT = 4

const EPOLLRDNORM = 64

const EPOLLRDBAND = 128

const EPOLLWRNORM = 256

const EPOLLWRBAND = 512

const EPOLLMSG = 1024

const EPOLLERR = 8

const EPOLLHUP = 16

const EPOLLRDHUP = 8192

const EPOLLEXCLUSIVE = 268435456

const EPOLLWAKEUP = 536870912

const EPOLLONESHOT = 1073741824

const EPOLLET = 2147483648

const EPOLL_CTL_ADD = 1

const EPOLL_CTL_DEL = 2

const EPOLL_CTL_MOD = 3

const STDIN_FILENO = 0

const STDOUT_FILENO = 1

const STDERR_FILENO = 2

const SEEK_DATA = 3

const SEEK_HOLE = 4

const L_SET = 0

const L_INCR = 1

const L_XTND = 2

const S_IREAD = 256

const S_IWRITE = 128

const S_IEXEC = 64

const S_BLKSIZE = 512

const STATX_TYPE = 1

const STATX_MODE = 2

const STATX_NLINK = 4

const STATX_UID = 8

const STATX_GID = 16

const STATX_ATIME = 32

const STATX_MTIME = 64

const STATX_CTIME = 128

const STATX_INO = 256

const STATX_SIZE = 512

const STATX_BLOCKS = 1024

const STATX_BASIC_STATS = 2047

const STATX_ALL = 4095

const STATX_BTIME = 2048

const STATX__RESERVED = 2147483648

const STATX_ATTR_COMPRESSED = 4

const STATX_ATTR_IMMUTABLE = 16

const STATX_ATTR_APPEND = 32

const STATX_ATTR_NODUMP = 64

const STATX_ATTR_ENCRYPTED = 2048

const STATX_ATTR_AUTOMOUNT = 4096

const PF_UNSPEC = 0

const PF_LOCAL = 1

const PF_UNIX = 1

const PF_FILE = 1

const PF_INET = 2

const PF_AX25 = 3

const PF_IPX = 4

const PF_APPLETALK = 5

const PF_NETROM = 6

const PF_BRIDGE = 7

const PF_ATMPVC = 8

const PF_X25 = 9

const PF_INET6 = 10

const PF_ROSE = 11

const PF_DECnet = 12

const PF_NETBEUI = 13

const PF_SECURITY = 14

const PF_KEY = 15

const PF_NETLINK = 16

const PF_ROUTE = 16

const PF_PACKET = 17

const PF_ASH = 18

const PF_ECONET = 19

const PF_ATMSVC = 20

const PF_RDS = 21

const PF_SNA = 22

const PF_IRDA = 23

const PF_PPPOX = 24

const PF_WANPIPE = 25

const PF_LLC = 26

const PF_IB = 27

const PF_MPLS = 28

const PF_CAN = 29

const PF_TIPC = 30

const PF_BLUETOOTH = 31

const PF_IUCV = 32

const PF_RXRPC = 33

const PF_ISDN = 34

const PF_PHONET = 35

const PF_IEEE802154 = 36

const PF_CAIF = 37

const PF_ALG = 38

const PF_NFC = 39

const PF_VSOCK = 40

const PF_KCM = 41

const PF_QIPCRTR = 42

const PF_SMC = 43

const PF_MAX = 44

const AF_UNSPEC = 0

const AF_LOCAL = 1

const AF_UNIX = 1

const AF_FILE = 1

const AF_INET = 2

const AF_AX25 = 3

const AF_IPX = 4

const AF_APPLETALK = 5

const AF_NETROM = 6

const AF_BRIDGE = 7

const AF_ATMPVC = 8

const AF_X25 = 9

const AF_INET6 = 10

const AF_ROSE = 11

const AF_DECnet = 12

const AF_NETBEUI = 13

const AF_SECURITY = 14

const AF_KEY = 15

const AF_NETLINK = 16

const AF_ROUTE = 16

const AF_PACKET = 17

const AF_ASH = 18

const AF_ECONET = 19

const AF_ATMSVC = 20

const AF_RDS = 21

const AF_SNA = 22

const AF_IRDA = 23

const AF_PPPOX = 24

const AF_WANPIPE = 25

const AF_LLC = 26

const AF_IB = 27

const AF_MPLS = 28

const AF_CAN = 29

const AF_TIPC = 30

const AF_BLUETOOTH = 31

const AF_IUCV = 32

const AF_RXRPC = 33

const AF_ISDN = 34

const AF_PHONET = 35

const AF_IEEE802154 = 36

const AF_CAIF = 37

const AF_ALG = 38

const AF_NFC = 39

const AF_VSOCK = 40

const AF_KCM = 41

const AF_QIPCRTR = 42

const AF_SMC = 43

const AF_MAX = 44

const SOL_RAW = 255

const SOL_DECNET = 261

const SOL_X25 = 262

const SOL_PACKET = 263

const SOL_ATM = 264

const SOL_AAL = 265

const SOL_IRDA = 266

const SOL_NETBEUI = 267

const SOL_LLC = 268

const SOL_DCCP = 269

const SOL_NETLINK = 270

const SOL_TIPC = 271

const SOL_RXRPC = 272

const SOL_PPPOL2TP = 273

const SOL_BLUETOOTH = 274

const SOL_PNPIPE = 275

const SOL_RDS = 276

const SOL_IUCV = 277

const SOL_CAIF = 278

const SOL_ALG = 279

const SOL_NFC = 280

const SOL_KCM = 281

const SOL_TLS = 282

const SOMAXCONN = 128

const FIOSETOWN = 35073

const FIOGETOWN = 35075

const SOL_SOCKET = 1

const SO_DEBUG = 1

const SO_REUSEADDR = 2

const SO_TYPE = 3

const SO_ERROR = 4

const SO_DONTROUTE = 5

const SO_BROADCAST = 6

const SO_SNDBUF = 7

const SO_RCVBUF = 8

const SO_SNDBUFFORCE = 32

const SO_RCVBUFFORCE = 33

const SO_KEEPALIVE = 9

const SO_OOBINLINE = 10

const SO_NO_CHECK = 11

const SO_PRIORITY = 12

const SO_LINGER = 13

const SO_BSDCOMPAT = 14

const SO_REUSEPORT = 15

const SO_PASSCRED = 16

const SO_PEERCRED = 17

const SO_RCVLOWAT = 18

const SO_SNDLOWAT = 19

const SO_RCVTIMEO = 20

const SO_SNDTIMEO = 21

const SO_SECURITY_AUTHENTICATION = 22

const SO_SECURITY_ENCRYPTION_TRANSPORT = 23

const SO_SECURITY_ENCRYPTION_NETWORK = 24

const SO_BINDTODEVICE = 25

const SO_ATTACH_FILTER = 26

const SO_DETACH_FILTER = 27

const SO_GET_FILTER = 26

const SO_PEERNAME = 28

const SO_TIMESTAMP = 29

const SCM_TIMESTAMP = 29

const SO_ACCEPTCONN = 30

const SO_PEERSEC = 31

const SO_PASSSEC = 34

const SO_TIMESTAMPNS = 35

const SCM_TIMESTAMPNS = 35

const SO_MARK = 36

const SO_TIMESTAMPING = 37

const SCM_TIMESTAMPING = 37

const SO_PROTOCOL = 38

const SO_DOMAIN = 39

const SO_RXQ_OVFL = 40

const SO_WIFI_STATUS = 41

const SCM_WIFI_STATUS = 41

const SO_PEEK_OFF = 42

const SO_NOFCS = 43

const SO_LOCK_FILTER = 44

const SO_SELECT_ERR_QUEUE = 45

const SO_BUSY_POLL = 46

const SO_MAX_PACING_RATE = 47

const SO_BPF_EXTENSIONS = 48

const SO_INCOMING_CPU = 49

const SO_ATTACH_BPF = 50

const SO_DETACH_BPF = 27

const SO_ATTACH_REUSEPORT_CBPF = 51

const SO_ATTACH_REUSEPORT_EBPF = 52

const SO_CNX_ADVICE = 53

const SCM_TIMESTAMPING_OPT_STATS = 54

const SO_MEMINFO = 55

const SO_INCOMING_NAPI_ID = 56

const SO_COOKIE = 57

const SCM_TIMESTAMPING_PKTINFO = 58

const SO_PEERGROUPS = 59

const SO_ZEROCOPY = 60

const SIGINT = 2

const SIGILL = 4

const SIGABRT = 6

const SIGFPE = 8

const SIGSEGV = 11

const SIGTERM = 15

const SIGHUP = 1

const SIGQUIT = 3

const SIGTRAP = 5

const SIGKILL = 9

const SIGBUS = 7

const SIGSYS = 31

const SIGPIPE = 13

const SIGALRM = 14

const SIGURG = 23

const SIGSTOP = 19

const SIGTSTP = 20

const SIGCONT = 18

const SIGCHLD = 17

const SIGTTIN = 21

const SIGTTOU = 22

const SIGPOLL = 29

const SIGXCPU = 24

const SIGXFSZ = 25

const SIGVTALRM = 26

const SIGPROF = 27

const SIGUSR1 = 10

const SIGUSR2 = 12

const SIGWINCH = 28

const SIGIO = 29

const SIGIOT = 6

const SIGCLD = 17

const SIGSTKFLT = 16

const SIGPWR = 30

const NSIG = 65

const SA_NOCLDSTOP = 1

const SA_NOCLDWAIT = 2

const SA_SIGINFO = 4

const SA_ONSTACK = 134217728

const SA_RESTART = 268435456

const SA_NODEFER = 1073741824

const SA_RESETHAND = 2147483648

const SA_INTERRUPT = 536870912

const SA_NOMASK = 1073741824

const SA_ONESHOT = 2147483648

const SA_STACK = 134217728

const SIG_BLOCK = 0

const SIG_UNBLOCK = 1

const SIG_SETMASK = 2

const NGREG = 18

const MINSIGSTKSZ = 2048

const SIGSTKSZ = 8192

const WCOREFLAG = 128

const WAIT_MYPGRP = 0

const SYS__llseek = 140

const SYS__newselect = 142

const SYS__sysctl = 149

const SYS_accept = 285

const SYS_accept4 = 366

const SYS_access = 33

const SYS_acct = 51

const SYS_add_key = 309

const SYS_adjtimex = 124

const SYS_arm_fadvise64_64 = 270

const SYS_arm_sync_file_range = 341

const SYS_bdflush = 134

const SYS_bind = 282

const SYS_bpf = 386

const SYS_brk = 45

const SYS_capget = 184

const SYS_capset = 185

const SYS_chdir = 12

const SYS_chmod = 15

const SYS_chown = 182

const SYS_chown32 = 212

const SYS_chroot = 61

const SYS_clock_adjtime = 372

const SYS_clock_getres = 264

const SYS_clock_gettime = 263

const SYS_clock_nanosleep = 265

const SYS_clock_settime = 262

const SYS_clone = 120

const SYS_close = 6

const SYS_connect = 283

const SYS_copy_file_range = 391

const SYS_creat = 8

const SYS_delete_module = 129

const SYS_dup = 41

const SYS_dup2 = 63

const SYS_dup3 = 358

const SYS_epoll_create = 250

const SYS_epoll_create1 = 357

const SYS_epoll_ctl = 251

const SYS_epoll_pwait = 346

const SYS_epoll_wait = 252

const SYS_eventfd = 351

const SYS_eventfd2 = 356

const SYS_execve = 11

const SYS_execveat = 387

const SYS_exit = 1

const SYS_exit_group = 248

const SYS_faccessat = 334

const SYS_fallocate = 352

const SYS_fanotify_init = 367

const SYS_fanotify_mark = 368

const SYS_fchdir = 133

const SYS_fchmod = 94

const SYS_fchmodat = 333

const SYS_fchown = 95

const SYS_fchown32 = 207

const SYS_fchownat = 325

const SYS_fcntl = 55

const SYS_fcntl64 = 221

const SYS_fdatasync = 148

const SYS_fgetxattr = 231

const SYS_finit_module = 379

const SYS_flistxattr = 234

const SYS_flock = 143

const SYS_fork = 2

const SYS_fremovexattr = 237

const SYS_fsetxattr = 228

const SYS_fstat = 108

const SYS_fstat64 = 197

const SYS_fstatat64 = 327

const SYS_fstatfs = 100

const SYS_fstatfs64 = 267

const SYS_fsync = 118

const SYS_ftruncate = 93

const SYS_ftruncate64 = 194

const SYS_futex = 240

const SYS_futimesat = 326

const SYS_get_mempolicy = 320

const SYS_get_robust_list = 339

const SYS_getcpu = 345

const SYS_getcwd = 183

const SYS_getdents = 141

const SYS_getdents64 = 217

const SYS_getegid = 50

const SYS_getegid32 = 202

const SYS_geteuid = 49

const SYS_geteuid32 = 201

const SYS_getgid = 47

const SYS_getgid32 = 200

const SYS_getgroups = 80

const SYS_getgroups32 = 205

const SYS_getitimer = 105

const SYS_getpeername = 287

const SYS_getpgid = 132

const SYS_getpgrp = 65

const SYS_getpid = 20

const SYS_getppid = 64

const SYS_getpriority = 96

const SYS_getrandom = 384

const SYS_getresgid = 171

const SYS_getresgid32 = 211

const SYS_getresuid = 165

const SYS_getresuid32 = 209

const SYS_getrusage = 77

const SYS_getsid = 147

const SYS_getsockname = 286

const SYS_getsockopt = 295

const SYS_gettid = 224

const SYS_gettimeofday = 78

const SYS_getuid = 24

const SYS_getuid32 = 199

const SYS_getxattr = 229

const SYS_init_module = 128

const SYS_inotify_add_watch = 317

const SYS_inotify_init = 316

const SYS_inotify_init1 = 360

const SYS_inotify_rm_watch = 318

const SYS_io_cancel = 247

const SYS_io_destroy = 244

const SYS_io_getevents = 245

const SYS_io_setup = 243

const SYS_io_submit = 246

const SYS_ioctl = 54

const SYS_ioprio_get = 315

const SYS_ioprio_set = 314

const SYS_kcmp = 378

const SYS_kexec_load = 347

const SYS_keyctl = 311

const SYS_kill = 37

const SYS_lchown = 16

const SYS_lchown32 = 198

const SYS_lgetxattr = 230

const SYS_link = 9

const SYS_linkat = 330

const SYS_listen = 284

const SYS_listxattr = 232

const SYS_llistxattr = 233

const SYS_lookup_dcookie = 249

const SYS_lremovexattr = 236

const SYS_lseek = 19

const SYS_lsetxattr = 227

const SYS_lstat = 107

const SYS_lstat64 = 196

const SYS_madvise = 220

const SYS_mbind = 319

const SYS_membarrier = 389

const SYS_memfd_create = 385

const SYS_mincore = 219

const SYS_mkdir = 39

const SYS_mkdirat = 323

const SYS_mknod = 14

const SYS_mknodat = 324

const SYS_mlock = 150

const SYS_mlock2 = 390

const SYS_mlockall = 152

const SYS_mmap2 = 192

const SYS_mount = 21

const SYS_move_pages = 344

const SYS_mprotect = 125

const SYS_mq_getsetattr = 279

const SYS_mq_notify = 278

const SYS_mq_open = 274

const SYS_mq_timedreceive = 277

const SYS_mq_timedsend = 276

const SYS_mq_unlink = 275

const SYS_mremap = 163

const SYS_msgctl = 304

const SYS_msgget = 303

const SYS_msgrcv = 302

const SYS_msgsnd = 301

const SYS_msync = 144

const SYS_munlock = 151

const SYS_munlockall = 153

const SYS_munmap = 91

const SYS_name_to_handle_at = 370

const SYS_nanosleep = 162

const SYS_nfsservctl = 169

const SYS_nice = 34

const SYS_open = 5

const SYS_open_by_handle_at = 371

const SYS_openat = 322

const SYS_pause = 29

const SYS_pciconfig_iobase = 271

const SYS_pciconfig_read = 272

const SYS_pciconfig_write = 273

const SYS_perf_event_open = 364

const SYS_personality = 136

const SYS_pipe = 42

const SYS_pipe2 = 359

const SYS_pivot_root = 218

const SYS_pkey_alloc = 395

const SYS_pkey_free = 396

const SYS_pkey_mprotect = 394

const SYS_poll = 168

const SYS_ppoll = 336

const SYS_prctl = 172

const SYS_pread64 = 180

const SYS_preadv = 361

const SYS_preadv2 = 392

const SYS_prlimit64 = 369

const SYS_process_vm_readv = 376

const SYS_process_vm_writev = 377

const SYS_pselect6 = 335

const SYS_ptrace = 26

const SYS_pwrite64 = 181

const SYS_pwritev = 362

const SYS_pwritev2 = 393

const SYS_quotactl = 131

const SYS_read = 3

const SYS_readahead = 225

const SYS_readlink = 85

const SYS_readlinkat = 332

const SYS_readv = 145

const SYS_reboot = 88

const SYS_recv = 291

const SYS_recvfrom = 292

const SYS_recvmmsg = 365

const SYS_recvmsg = 297

const SYS_remap_file_pages = 253

const SYS_removexattr = 235

const SYS_rename = 38

const SYS_renameat = 329

const SYS_renameat2 = 382

const SYS_request_key = 310

const SYS_restart_syscall = 0

const SYS_rmdir = 40

const SYS_rseq = 398

const SYS_rt_sigaction = 174

const SYS_rt_sigpending = 176

const SYS_rt_sigprocmask = 175

const SYS_rt_sigqueueinfo = 178

const SYS_rt_sigreturn = 173

const SYS_rt_sigsuspend = 179

const SYS_rt_sigtimedwait = 177

const SYS_rt_tgsigqueueinfo = 363

const SYS_sched_get_priority_max = 159

const SYS_sched_get_priority_min = 160

const SYS_sched_getaffinity = 242

const SYS_sched_getattr = 381

const SYS_sched_getparam = 155

const SYS_sched_getscheduler = 157

const SYS_sched_rr_get_interval = 161

const SYS_sched_setaffinity = 241

const SYS_sched_setattr = 380

const SYS_sched_setparam = 154

const SYS_sched_setscheduler = 156

const SYS_sched_yield = 158

const SYS_seccomp = 383

const SYS_semctl = 300

const SYS_semget = 299

const SYS_semop = 298

const SYS_semtimedop = 312

const SYS_send = 289

const SYS_sendfile = 187

const SYS_sendfile64 = 239

const SYS_sendmmsg = 374

const SYS_sendmsg = 296

const SYS_sendto = 290

const SYS_set_mempolicy = 321

const SYS_set_robust_list = 338

const SYS_set_tid_address = 256

const SYS_setdomainname = 121

const SYS_setfsgid = 139

const SYS_setfsgid32 = 216

const SYS_setfsuid = 138

const SYS_setfsuid32 = 215

const SYS_setgid = 46

const SYS_setgid32 = 214

const SYS_setgroups = 81

const SYS_setgroups32 = 206

const SYS_sethostname = 74

const SYS_setitimer = 104

const SYS_setns = 375

const SYS_setpgid = 57

const SYS_setpriority = 97

const SYS_setregid = 71

const SYS_setregid32 = 204

const SYS_setresgid = 170

const SYS_setresgid32 = 210

const SYS_setresuid = 164

const SYS_setresuid32 = 208

const SYS_setreuid = 70

const SYS_setreuid32 = 203

const SYS_setrlimit = 75

const SYS_setsid = 66

const SYS_setsockopt = 294

const SYS_settimeofday = 79

const SYS_setuid = 23

const SYS_setuid32 = 213

const SYS_setxattr = 226

const SYS_shmat = 305

const SYS_shmctl = 308

const SYS_shmdt = 306

const SYS_shmget = 307

const SYS_shutdown = 293

const SYS_sigaction = 67

const SYS_sigaltstack = 186

const SYS_signalfd = 349

const SYS_signalfd4 = 355

const SYS_sigpending = 73

const SYS_sigprocmask = 126

const SYS_sigreturn = 119

const SYS_sigsuspend = 72

const SYS_socket = 281

const SYS_socketpair = 288

const SYS_splice = 340

const SYS_stat = 106

const SYS_stat64 = 195

const SYS_statfs = 99

const SYS_statfs64 = 266

const SYS_statx = 397

const SYS_swapoff = 115

const SYS_swapon = 87

const SYS_symlink = 83

const SYS_symlinkat = 331

const SYS_sync = 36

const SYS_sync_file_range2 = 341

const SYS_syncfs = 373

const SYS_sysfs = 135

const SYS_sysinfo = 116

const SYS_syslog = 103

const SYS_tee = 342

const SYS_tgkill = 268

const SYS_timer_create = 257

const SYS_timer_delete = 261

const SYS_timer_getoverrun = 260

const SYS_timer_gettime = 259

const SYS_timer_settime = 258

const SYS_timerfd_create = 350

const SYS_timerfd_gettime = 354

const SYS_timerfd_settime = 353

const SYS_times = 43

const SYS_tkill = 238

const SYS_truncate = 92

const SYS_truncate64 = 193

const SYS_ugetrlimit = 191

const SYS_umask = 60

const SYS_umount2 = 52

const SYS_uname = 122

const SYS_unlink = 10

const SYS_unlinkat = 328

const SYS_unshare = 337

const SYS_uselib = 86

const SYS_userfaultfd = 388

const SYS_ustat = 62

const SYS_utimensat = 348

const SYS_utimes = 269

const SYS_vfork = 190

const SYS_vhangup = 111

const SYS_vmsplice = 343

const SYS_vserver = 313

const SYS_wait4 = 114

const SYS_waitid = 280

const SYS_write = 4

const SYS_writev = 146

const POSIX_SPAWN_RESETIDS = 1

const POSIX_SPAWN_SETPGROUP = 2

const POSIX_SPAWN_SETSIGDEF = 4

const POSIX_SPAWN_SETSIGMASK = 8

const POSIX_SPAWN_SETSCHEDPARAM = 16

const POSIX_SPAWN_SETSCHEDULER = 32

const POSIX_SPAWN_USEVFORK = 64

const POSIX_SPAWN_SETSID = 128



function __locale_struct_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __locale_struct_m(czeros(__locale_struct_m)...)
end

function div_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    div_t(czeros(div_t)...)
end

function div_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    div_t_m(czeros(div_t_m)...)
end

function ldiv_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ldiv_t(czeros(ldiv_t)...)
end

function ldiv_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ldiv_t_m(czeros(ldiv_t_m)...)
end

function lldiv_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    lldiv_t(czeros(lldiv_t)...)
end

function lldiv_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    lldiv_t_m(czeros(lldiv_t_m)...)
end

function __fsid_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __fsid_t(czeros(__fsid_t)...)
end

function __fsid_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __fsid_t_m(czeros(__fsid_t_m)...)
end

function __sigset_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __sigset_t(czeros(__sigset_t)...)
end

function __sigset_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __sigset_t_m(czeros(__sigset_t_m)...)
end

function timeval()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    timeval(czeros(timeval)...)
end

function timeval_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    timeval_m(czeros(timeval_m)...)
end

function timespec()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    timespec(czeros(timespec)...)
end

function timespec_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    timespec_m(czeros(timespec_m)...)
end

function fd_set()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    fd_set(czeros(fd_set)...)
end

function fd_set_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    fd_set_m(czeros(fd_set_m)...)
end

function __pthread_rwlock_arch_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_rwlock_arch_t(czeros(__pthread_rwlock_arch_t)...)
end

function __pthread_rwlock_arch_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_rwlock_arch_t_m(czeros(__pthread_rwlock_arch_t_m)...)
end

function __pthread_internal_slist()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_internal_slist(czeros(__pthread_internal_slist)...)
end

function __pthread_internal_slist_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_internal_slist_m(czeros(__pthread_internal_slist_m)...)
end

function __pthread_mutex_s()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_mutex_s(czeros(__pthread_mutex_s)...)
end

function __pthread_mutex_s_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_mutex_s_m(czeros(__pthread_mutex_s_m)...)
end

function __pthread_cond_s()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_cond_s(czeros(__pthread_cond_s)...)
end

function __pthread_cond_s_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_cond_s_m(czeros(__pthread_cond_s_m)...)
end

function pthread_mutexattr_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_mutexattr_t(czeros(pthread_mutexattr_t)...)
end

function pthread_mutexattr_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_mutexattr_t_m(czeros(pthread_mutexattr_t_m)...)
end

function pthread_condattr_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_condattr_t(czeros(pthread_condattr_t)...)
end

function pthread_condattr_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_condattr_t_m(czeros(pthread_condattr_t_m)...)
end

function pthread_attr_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_attr_t(czeros(pthread_attr_t)...)
end

function pthread_attr_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_attr_t_m(czeros(pthread_attr_t_m)...)
end

function pthread_mutex_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_mutex_t(czeros(pthread_mutex_t)...)
end

function pthread_mutex_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_mutex_t_m(czeros(pthread_mutex_t_m)...)
end

function pthread_cond_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_cond_t(czeros(pthread_cond_t)...)
end

function pthread_cond_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_cond_t_m(czeros(pthread_cond_t_m)...)
end

function pthread_rwlock_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_rwlock_t(czeros(pthread_rwlock_t)...)
end

function pthread_rwlock_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_rwlock_t_m(czeros(pthread_rwlock_t_m)...)
end

function pthread_rwlockattr_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_rwlockattr_t(czeros(pthread_rwlockattr_t)...)
end

function pthread_rwlockattr_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_rwlockattr_t_m(czeros(pthread_rwlockattr_t_m)...)
end

function pthread_barrier_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_barrier_t(czeros(pthread_barrier_t)...)
end

function pthread_barrier_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_barrier_t_m(czeros(pthread_barrier_t_m)...)
end

function pthread_barrierattr_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_barrierattr_t(czeros(pthread_barrierattr_t)...)
end

function pthread_barrierattr_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pthread_barrierattr_t_m(czeros(pthread_barrierattr_t_m)...)
end

function random_data()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    random_data(czeros(random_data)...)
end

function random_data_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    random_data_m(czeros(random_data_m)...)
end

function drand48_data()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    drand48_data(czeros(drand48_data)...)
end

function drand48_data_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    drand48_data_m(czeros(drand48_data_m)...)
end

function sched_param()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sched_param(czeros(sched_param)...)
end

function sched_param_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sched_param_m(czeros(sched_param_m)...)
end

function cpu_set_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    cpu_set_t(czeros(cpu_set_t)...)
end

function cpu_set_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    cpu_set_t_m(czeros(cpu_set_t_m)...)
end

function tm()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    tm(czeros(tm)...)
end

function tm_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    tm_m(czeros(tm_m)...)
end

function itimerspec()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    itimerspec(czeros(itimerspec)...)
end

function itimerspec_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    itimerspec_m(czeros(itimerspec_m)...)
end

function sigval()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigval(czeros(sigval)...)
end

function sigval_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigval_m(czeros(sigval_m)...)
end

function ANONYMOUS29__sigev_un()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS29__sigev_un(czeros(ANONYMOUS29__sigev_un)...)
end

function ANONYMOUS29__sigev_un_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS29__sigev_un_m(czeros(ANONYMOUS29__sigev_un_m)...)
end

function sigevent()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigevent(czeros(sigevent)...)
end

function sigevent_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigevent_m(czeros(sigevent_m)...)
end

function _pthread_cleanup_buffer()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    _pthread_cleanup_buffer(czeros(_pthread_cleanup_buffer)...)
end

function _pthread_cleanup_buffer_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    _pthread_cleanup_buffer_m(czeros(_pthread_cleanup_buffer_m)...)
end

function ANONYMOUS12___cancel_jmp_buf()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS12___cancel_jmp_buf(czeros(ANONYMOUS12___cancel_jmp_buf)...)
end

function ANONYMOUS12___cancel_jmp_buf_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS12___cancel_jmp_buf_m(czeros(ANONYMOUS12___cancel_jmp_buf_m)...)
end

function __pthread_unwind_buf_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_unwind_buf_t(czeros(__pthread_unwind_buf_t)...)
end

function __pthread_unwind_buf_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_unwind_buf_t_m(czeros(__pthread_unwind_buf_t_m)...)
end

function __pthread_cleanup_frame()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_cleanup_frame(czeros(__pthread_cleanup_frame)...)
end

function __pthread_cleanup_frame_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __pthread_cleanup_frame_m(czeros(__pthread_cleanup_frame_m)...)
end

function winsize()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    winsize(czeros(winsize)...)
end

function winsize_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    winsize_m(czeros(winsize_m)...)
end

function termio()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    termio(czeros(termio)...)
end

function termio_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    termio_m(czeros(termio_m)...)
end

function termios()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    termios(czeros(termios)...)
end

function termios_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    termios_m(czeros(termios_m)...)
end

function flock()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    flock(czeros(flock)...)
end

function flock_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    flock_m(czeros(flock_m)...)
end

function flock64()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    flock64(czeros(flock64)...)
end

function flock64_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    flock64_m(czeros(flock64_m)...)
end

function iovec()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    iovec(czeros(iovec)...)
end

function iovec_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    iovec_m(czeros(iovec_m)...)
end

function f_owner_ex()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    f_owner_ex(czeros(f_owner_ex)...)
end

function f_owner_ex_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    f_owner_ex_m(czeros(f_owner_ex_m)...)
end

function file_handle()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    file_handle(czeros(file_handle)...)
end

function file_handle_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    file_handle_m(czeros(file_handle_m)...)
end

function stat()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    stat(czeros(stat)...)
end

function stat_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    stat_m(czeros(stat_m)...)
end

function stat64()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    stat64(czeros(stat64)...)
end

function stat64_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    stat64_m(czeros(stat64_m)...)
end

function pollfd()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pollfd(czeros(pollfd)...)
end

function pollfd_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    pollfd_m(czeros(pollfd_m)...)
end

function epoll_data()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    epoll_data(czeros(epoll_data)...)
end

function epoll_data_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    epoll_data_m(czeros(epoll_data_m)...)
end

function epoll_event()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    epoll_event(czeros(epoll_event)...)
end

function epoll_event_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    epoll_event_m(czeros(epoll_event_m)...)
end

function statx_timestamp()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    statx_timestamp(czeros(statx_timestamp)...)
end

function statx_timestamp_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    statx_timestamp_m(czeros(statx_timestamp_m)...)
end

function statx()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    statx(czeros(statx)...)
end

function statx_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    statx_m(czeros(statx_m)...)
end

function sockaddr()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sockaddr(czeros(sockaddr)...)
end

function sockaddr_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sockaddr_m(czeros(sockaddr_m)...)
end

function sockaddr_storage()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sockaddr_storage(czeros(sockaddr_storage)...)
end

function sockaddr_storage_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sockaddr_storage_m(czeros(sockaddr_storage_m)...)
end

function msghdr()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    msghdr(czeros(msghdr)...)
end

function msghdr_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    msghdr_m(czeros(msghdr_m)...)
end

function cmsghdr()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    cmsghdr(czeros(cmsghdr)...)
end

function cmsghdr_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    cmsghdr_m(czeros(cmsghdr_m)...)
end

function ucred()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ucred(czeros(ucred)...)
end

function ucred_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ucred_m(czeros(ucred_m)...)
end

function linger()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    linger(czeros(linger)...)
end

function linger_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    linger_m(czeros(linger_m)...)
end

function osockaddr()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    osockaddr(czeros(osockaddr)...)
end

function osockaddr_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    osockaddr_m(czeros(osockaddr_m)...)
end

function __SOCKADDR_ARG()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __SOCKADDR_ARG(czeros(__SOCKADDR_ARG)...)
end

function __SOCKADDR_ARG_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __SOCKADDR_ARG_m(czeros(__SOCKADDR_ARG_m)...)
end

function __CONST_SOCKADDR_ARG()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __CONST_SOCKADDR_ARG(czeros(__CONST_SOCKADDR_ARG)...)
end

function __CONST_SOCKADDR_ARG_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    __CONST_SOCKADDR_ARG_m(czeros(__CONST_SOCKADDR_ARG_m)...)
end

function mmsghdr()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    mmsghdr(czeros(mmsghdr)...)
end

function mmsghdr_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    mmsghdr_m(czeros(mmsghdr_m)...)
end

function ANONYMOUS20__sifields()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS20__sifields(czeros(ANONYMOUS20__sifields)...)
end

function ANONYMOUS20__sifields_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS20__sifields_m(czeros(ANONYMOUS20__sifields_m)...)
end

function siginfo_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    siginfo_t(czeros(siginfo_t)...)
end

function siginfo_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    siginfo_t_m(czeros(siginfo_t_m)...)
end

function ANONYMOUS31___sigaction_handler()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS31___sigaction_handler(czeros(ANONYMOUS31___sigaction_handler)...)
end

function ANONYMOUS31___sigaction_handler_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS31___sigaction_handler_m(czeros(ANONYMOUS31___sigaction_handler_m)...)
end

function sigaction()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigaction(czeros(sigaction)...)
end

function sigaction_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigaction_m(czeros(sigaction_m)...)
end

function sigcontext()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigcontext(czeros(sigcontext)...)
end

function sigcontext_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigcontext_m(czeros(sigcontext_m)...)
end

function stack_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    stack_t(czeros(stack_t)...)
end

function stack_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    stack_t_m(czeros(stack_t_m)...)
end

function ANONYMOUS33_fpregs()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS33_fpregs(czeros(ANONYMOUS33_fpregs)...)
end

function ANONYMOUS33_fpregs_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS33_fpregs_m(czeros(ANONYMOUS33_fpregs_m)...)
end

function _libc_fpstate()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    _libc_fpstate(czeros(_libc_fpstate)...)
end

function _libc_fpstate_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    _libc_fpstate_m(czeros(_libc_fpstate_m)...)
end

function mcontext_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    mcontext_t(czeros(mcontext_t)...)
end

function mcontext_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    mcontext_t_m(czeros(mcontext_t_m)...)
end

function ucontext_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ucontext_t(czeros(ucontext_t)...)
end

function ucontext_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ucontext_t_m(czeros(ucontext_t_m)...)
end

function sigstack()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigstack(czeros(sigstack)...)
end

function sigstack_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    sigstack_m(czeros(sigstack_m)...)
end

function ANONYMOUS35__sifields()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS35__sifields(czeros(ANONYMOUS35__sifields)...)
end

function ANONYMOUS35__sifields_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS35__sifields_m(czeros(ANONYMOUS35__sifields_m)...)
end

function ANONYMOUS44__sigev_un()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS44__sigev_un(czeros(ANONYMOUS44__sigev_un)...)
end

function ANONYMOUS44__sigev_un_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS44__sigev_un_m(czeros(ANONYMOUS44__sigev_un_m)...)
end

function ANONYMOUS46___sigaction_handler()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS46___sigaction_handler(czeros(ANONYMOUS46___sigaction_handler)...)
end

function ANONYMOUS46___sigaction_handler_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS46___sigaction_handler_m(czeros(ANONYMOUS46___sigaction_handler_m)...)
end

function ANONYMOUS48_fpregs()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS48_fpregs(czeros(ANONYMOUS48_fpregs)...)
end

function ANONYMOUS48_fpregs_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    ANONYMOUS48_fpregs_m(czeros(ANONYMOUS48_fpregs_m)...)
end

function posix_spawnattr_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    posix_spawnattr_t(czeros(posix_spawnattr_t)...)
end

function posix_spawnattr_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    posix_spawnattr_t_m(czeros(posix_spawnattr_t_m)...)
end

function posix_spawn_file_actions_t()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    posix_spawn_file_actions_t(czeros(posix_spawn_file_actions_t)...)
end

function posix_spawn_file_actions_t_m()
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:222 =#
    #= /home/sam/git/jlpi/CInclude/src/CInclude.jl:223 =#
    posix_spawn_file_actions_t_m(czeros(posix_spawn_file_actions_t_m)...)
end

const constants = Dict(308 => [:SYS_shmctl],165 => [:_SC_TYPED_MEMORY_OBJECTS, :SYS_getresuid],1140 => [:_CS_POSIX_V7_LP64_OFF64_CFLAGS],256 => [:MSG_WAITALL, :LOGIN_NAME_MAX, :CLONE_VM, :ADJ_SETOFFSET, :STA_PPSSIGNAL, :TIOCM_DSR, :ICRNL, :NLDLY, :NL1, :PARENB, :TOSTOP, :O_NOCTTY, :AT_SYMLINK_NOFOLLOW, :S_IRUSR, :POLLWRNORM, :EPOLLWRNORM, :S_IREAD, :STATX_INO, :MSG_WAITALL, :SYS_set_tid_address],1122 => [:_CS_POSIX_V6_ILP32_OFFBIG_LIBS],231 => [:SYS_fgetxattr],260 => [:SYS_timer_getoverrun],21516 => [:TIOCEXCL],65536 => [:MSG_WAITFORONE, :NGROUPS_MAX, :XATTR_SIZE_MAX, :XATTR_LIST_MAX, :CLONE_THREAD, :EXTPROC, :O_DIRECT, :MSG_WAITFORONE],1104 => [:_CS_XBS5_ILP32_OFFBIG_CFLAGS],130 => [:_SC_XOPEN_REALTIME, :EOWNERDEAD],209 => [:SYS_getresuid32],221 => [:SYS_fcntl64],321 => [:SYS_set_mempolicy],65535 => [:UINT16_MAX, :UINT_LEAST16_MAX],266 => [:SOL_IRDA, :SYS_statfs64],104 => [:_SC_INT_MAX, :ECONNRESET, :SYS_setitimer],174 => [:_SC_STREAMS, :SYS_rt_sigaction],-3 => [:SI_MESGQ, :SI_MESGQ, :SI_MESGQ],1137 => [:_CS_POSIX_V7_ILP32_OFFBIG_LDFLAGS],86 => [:_SC_AVPHYS_PAGES, :ESTRPIPE, :SYS_uselib],21521 => [:TIOCOUTQ],153 => [:_SC_READER_WRITER_LOCKS, :SYS_munlockall],296 => [:SYS_sendmsg],212 => [:SYS_chown32],28 => [:_SC_MQ_PRIO_MAX, :ENOSPC, :CQUIT, :PF_MPLS, :AF_MPLS, :SO_PEERNAME, :SIGWINCH],5 => [:_PC_PIPE_BUF, :_SC_STREAM_MAX, :_CS_V7_WIDTH_RESTRICTED_ENVS, :SOCK_SEQPACKET, :ILL_PRVOPC, :ILL_PRVOPC, :FPE_FLTUND, :FPE_FLTUND, :BUS_MCEERR_AO, :BUS_MCEERR_AO, :CLD_STOPPED, :CLD_STOPPED, :POLL_PRI, :POLL_PRI, :REG_R5, :REG_R5, :EIO, :SCHED_IDLE, :CLOCK_REALTIME_COARSE, :N_AX25, :VTIME, :B150, :F_GETLK, :RWH_WRITE_LIFE_EXTREME, :POSIX_FADV_NOREUSE, :SOCK_SEQPACKET, :PF_APPLETALK, :AF_APPLETALK, :SO_DONTROUTE, :SIGTRAP, :ILL_PRVOPC, :FPE_FLTUND, :BUS_MCEERR_AO, :CLD_STOPPED, :POLL_PRI, :REG_R5, :SYS_open],21507 => [:TCSETSW],262144 => [:MSG_BATCH, :CLONE_SYSVSEM, :O_NOATIME, :MSG_BATCH],298 => [:SYS_semop],21550 => [:TIOCGRS485],1138 => [:_CS_POSIX_V7_ILP32_OFFBIG_LIBS],387 => [:SYS_execveat],305 => [:SYS_shmat],21513 => [:TCSBRK],512 => [:MSG_FIN, :CLONE_FS, :STA_PPSJITTER, :IUCLC, :CR1, :PARODD, :ECHOCTL, :O_TRUNC, :AT_REMOVEDIR, :AT_EACCESS, :S_ISVTX, :POLLWRBAND, :EPOLLWRBAND, :S_BLKSIZE, :STATX_SIZE, :MSG_FIN],235 => [:_SC_IPV6, :SYS_removexattr],173 => [:_SC_SYMLOOP_MAX, :SYS_rt_sigreturn],281 => [:SOL_KCM, :SYS_socket],1116 => [:_CS_POSIX_V6_ILP32_OFF32_CFLAGS],1035 => [:F_GET_RW_HINT],22 => [:_SC_SHARED_MEMORY_OBJECTS, :EINVAL, :CLNEXT, :PF_SNA, :AF_SNA, :SO_SECURITY_AUTHENTICATION, :SIGTTOU],35075 => [:FIOGETOWN],1117 => [:_CS_POSIX_V6_ILP32_OFF32_LDFLAGS],272 => [:SOL_RXRPC, :SYS_pciconfig_read],1105 => [:_CS_XBS5_ILP32_OFFBIG_LDFLAGS],301 => [:SYS_msgsnd],315 => [:SYS_ioprio_get],366 => [:SYS_accept4],245 => [:_SC_TRACE_USER_EVENT_MAX, :SYS_io_getevents],147 => [:_SC_FILE_LOCKING, :SYS_getsid],92 => [:_SC_XOPEN_CRYPT, :ENOPROTOOPT, :SYS_truncate],138 => [:_SC_CPUTIME, :SYS_setfsuid],377 => [:SYS_process_vm_writev],536870912 => [:MSG_FASTOPEN, :CLONE_NEWPID, :EPOLLWAKEUP, :MSG_FASTOPEN, :SA_INTERRUPT],198 => [:_SC_LEVEL4_CACHE_ASSOC, :SYS_lchown32],336 => [:SYS_ppoll],1024 => [:MSG_SYN, :PTHREAD_KEYS_MAX, :IOV_MAX, :FD_SETSIZE, :CLONE_FILES, :CPU_SETSIZE, :STA_PPSWANDER, :IXON, :CR2, :HUPCL, :ECHOPRT, :O_APPEND, :F_SETLEASE, :FAPPEND, :AT_SYMLINK_FOLLOW, :S_ISGID, :POLLMSG, :EPOLLMSG, :STATX_BLOCKS, :MSG_SYN],197 => [:_SC_LEVEL4_CACHE_SIZE, :SYS_fstat64],4096 => [:MSG_RST, :PATH_MAX, :PIPE_BUF, :NL_ARGMAX, :ADJ_MICRO, :MOD_MICRO, :STA_CLOCKERR, :IXOFF, :TAB2, :CBAUDEX, :FLUSHO, :O_DSYNC, :AT_EMPTY_PATH, :S_IFIFO, :POLLREMOVE, :STATX_ATTR_AUTOMOUNT, :MSG_RST],1114 => [:_CS_XBS5_LPBIG_OFFBIG_LIBS],21510 => [:TCSETA],21543 => [:TIOCSBRK],1001 => [:_CS_LFS_LDFLAGS],62 => [:_SC_PII_INTERNET_DGRAM, :ETIME, :SYS_ustat],4101 => [:B500000],143 => [:_SC_FD_MGMT, :SYS_flock],21556 => [:TCSETXF],118 => [:_SC_USHRT_MAX, :ENOTNAM, :SYS_fsync],194 => [:_SC_LEVEL3_CACHE_SIZE, :SYS_ftruncate64],234 => [:SYS_flistxattr],220 => [:SYS_madvise],21588 => [:TIOCSERGWILD],269418496 => [:CIBAUD],21506 => [:TCSETS],335 => [:SYS_pselect6],64 => [:_SC_PII_OSI_CLTS, :MSG_DONTWAIT, :ENONET, :LLONG_WIDTH, :ULLONG_WIDTH, :HOST_NAME_MAX, :STA_UNSYNC, :TIOCPKT_IOCTL, :TIOCM_CAR, :TIOCM_CD, :INLCR, :OFILL, :CSTOPB, :ECHONL, :O_CREAT, :LOCK_READ, :FALLOC_FL_UNSHARE_RANGE, :S_IXUSR, :POLLRDNORM, :INT64_WIDTH, :UINT64_WIDTH, :INT_LEAST64_WIDTH, :UINT_LEAST64_WIDTH, :INT_FAST64_WIDTH, :UINT_FAST64_WIDTH, :INTMAX_WIDTH, :UINTMAX_WIDTH, :EPOLLRDNORM, :S_IEXEC, :STATX_MTIME, :STATX_ATTR_NODUMP, :MSG_DONTWAIT, :SYS_getppid, :POSIX_SPAWN_USEVFORK],58 => [:_SC_POLL, :SCM_TIMESTAMPING_PKTINFO],32 => [:_SC_SEM_NSEMS_MAX, :MSG_TRUNC, :EPIPE, :INT_WIDTH, :UINT_WIDTH, :LONG_WIDTH, :ULONG_WIDTH, :RTSIG_MAX, :TTY_NAME_MAX, :EXPR_NEST_MAX, :WORD_BIT, :LONG_BIT, :NFDBITS, :ADJ_TIMECONST, :MOD_TIMECONST, :STA_DEL, :TIOCPKT_DOSTOP, :TIOCM_CTS, :NCCS, :ISTRIP, :ONLRET, :CS7, :ECHOK, :LOCK_MAND, :DN_ATTRIB, :FALLOC_FL_INSERT_RANGE, :POLLNVAL, :INT32_WIDTH, :UINT32_WIDTH, :INT_LEAST32_WIDTH, :UINT_LEAST32_WIDTH, :INT_FAST16_WIDTH, :UINT_FAST16_WIDTH, :INT_FAST32_WIDTH, :UINT_FAST32_WIDTH, :INTPTR_WIDTH, :UINTPTR_WIDTH, :PTRDIFF_WIDTH, :SIG_ATOMIC_WIDTH, :SIZE_WIDTH, :WCHAR_WIDTH, :WINT_WIDTH, :STATX_ATIME, :STATX_ATTR_APPEND, :PF_IUCV, :AF_IUCV, :MSG_TRUNC, :SO_SNDBUFFORCE, :POSIX_SPAWN_SETSCHEDULER],-100 => [:AT_FDCWD],242 => [:_SC_TRACE_EVENT_NAME_MAX, :SYS_sched_getaffinity],215 => [:SYS_setfsuid32],262 => [:SOL_X25, :SYS_clock_settime],21511 => [:TCSETAW],21594 => [:TIOCSERGETMULTI],206 => [:SYS_setgroups32],204 => [:SYS_setregid32],280 => [:SOL_NFC, :SYS_waitid],201 => [:SYS_geteuid32],396 => [:SYS_pkey_free],63 => [:_SC_PII_OSI_COTS, :ENOSR, :SYS_dup2],101 => [:_SC_CHAR_BIT, :ENETUNREACH],1124 => [:_CS_POSIX_V6_LP64_OFF64_CFLAGS],195 => [:_SC_LEVEL3_CACHE_ASSOC, :SYS_stat64],0 => [:C_NULL, :P_ALL, :P_ALL, :PTHREAD_CREATE_JOINABLE, :PTHREAD_MUTEX_TIMED_NP, :PTHREAD_MUTEX_STALLED, :PTHREAD_PRIO_NONE, :PTHREAD_RWLOCK_PREFER_READER_NP, :PTHREAD_INHERIT_SCHED, :PTHREAD_SCOPE_SYSTEM, :PTHREAD_PROCESS_PRIVATE, :PTHREAD_CANCEL_ENABLE, :PTHREAD_CANCEL_DEFERRED, :F_OWNER_TID, :WINT_MIN, :_PC_LINK_MAX, :_SC_ARG_MAX, :_CS_PATH, :SHUT_RD, :SI_USER, :SI_USER, :SIGEV_SIGNAL, :SIGEV_SIGNAL, :REG_R0, :REG_R0, :CHAR_MIN, :EXIT_SUCCESS, :SCHED_OTHER, :CLOCK_REALTIME, :PTHREAD_CREATE_JOINABLE, :PTHREAD_INHERIT_SCHED, :PTHREAD_SCOPE_SYSTEM, :PTHREAD_PROCESS_PRIVATE, :PTHREAD_CANCEL_ENABLE, :PTHREAD_CANCEL_DEFERRED, :PTHREAD_ONCE_INIT, :TIOCPKT_DATA, :N_TTY, :CEOL, :CSTATUS, :CTIME, :CBRK, :VINTR, :NL0, :CR0, :TAB0, :BS0, :FF0, :VT0, :B0, :CS5, :TCOOFF, :TCIFLUSH, :TCSANOW, :O_RDONLY, :F_DUPFD, :F_RDLCK, :RWF_WRITE_LIFE_NOT_SET, :POSIX_FADV_NORMAL, :AT_STATX_SYNC_AS_STAT, :F_OK, :SEEK_SET, :F_ULOCK, :WCHAR_MIN, :STDIN_FILENO, :L_SET, :PF_UNSPEC, :AF_UNSPEC, :SHUT_RD, :SI_USER, :SIGEV_SIGNAL, :SIG_BLOCK, :REG_R0, :WAIT_MYPGRP, :SYS_restart_syscall],60 => [:_SC_UIO_MAXIOV, :ENOSTR, :SO_ZEROCOPY, :SYS_umask],196 => [:_SC_LEVEL3_CACHE_LINESIZE, :SYS_lstat64],85 => [:_SC_PHYS_PAGES, :ERESTART, :SYS_readlink],159 => [:_SC_SPAWN, :SYS_sched_get_priority_max],66 => [:_SC_T_IOV_MAX, :EREMOTE, :SYS_setsid],10 => [:_PC_ASYNC_IO, :_SC_PRIORITY_SCHEDULING, :SOCK_PACKET, :REG_R10, :REG_R10, :ECHILD, :N_PROFIBUS_FDL, :VSUSP, :B1800, :F_SETSIG, :SOCK_PACKET, :PF_INET6, :AF_INET6, :SO_OOBINLINE, :SIGUSR1, :REG_R10, :SYS_unlink],41 => [:_SC_EQUIV_CLASS_MAX, :PF_KCM, :AF_KCM, :SO_WIFI_STATUS, :SCM_WIFI_STATUS, :SYS_dup],32767 => [:INT16_MAX, :INT_LEAST16_MAX, :SHRT_MAX],1133 => [:_CS_POSIX_V7_ILP32_OFF32_LDFLAGS],117 => [:_SC_ULONG_MAX, :EUCLEAN],21539 => [:TIOCSETD],114 => [:_SC_SHRT_MIN, :EALREADY, :SYS_wait4],152 => [:_SC_NETWORKING, :SYS_mlockall],1126 => [:_CS_POSIX_V6_LP64_OFF64_LIBS],4105 => [:B1152000],1139 => [:_CS_POSIX_V7_ILP32_OFFBIG_LINTFLAGS],202 => [:SYS_getegid32],129 => [:_SC_XOPEN_LEGACY, :EKEYREJECTED, :SYS_delete_module],131072 => [:CLONE_NEWNS, :O_LARGEFILE],102 => [:_SC_CHAR_MAX, :ENETRESET],93 => [:_SC_XOPEN_ENH_I18N, :EPROTONOSUPPORT, :SYS_ftruncate],9 => [:_PC_SYNC_IO, :_SC_REALTIME_SIGNALS, :REG_R9, :REG_R9, :EBADF, :CLOCK_BOOTTIME_ALARM, :N_R3964, :VSTOP, :B1200, :F_GETOWN, :PF_X25, :AF_X25, :SO_KEEPALIVE, :SIGKILL, :REG_R9, :SYS_link],21517 => [:TIOCNXCL],82 => [:_SC_THREAD_PROCESS_SHARED, :ELIBMAX],122 => [:_SC_NL_NMAX, :EDQUOT, :SYS_uname],53 => [:_SC_PII, :EBADR, :SO_CNX_ADVICE],21524 => [:TIOCSWINSZ],347 => [:SYS_kexec_load],1074025521 => [:TIOCSPTLCK],1002 => [:_CS_LFS_LIBS],155 => [:_SC_REGEXP, :SYS_sched_getparam],32769 => [:ADJ_OFFSET_SINGLESHOT, :MOD_CLKA],274 => [:SOL_BLUETOOTH, :SYS_mq_open],21555 => [:TCSETX],312 => [:SYS_semtimedop],1003 => [:_CS_LFS_LINTFLAGS],275 => [:SOL_PNPIPE, :SYS_mq_unlink],295 => [:SYS_getsockopt],188 => [:_SC_LEVEL1_DCACHE_SIZE],1125 => [:_CS_POSIX_V6_LP64_OFF64_LDFLAGS],255 => [:UINT8_MAX, :UINT_LEAST8_MAX, :UINT_FAST8_MAX, :CHAR_MAX, :MAX_CANON, :MAX_INPUT, :NAME_MAX, :XATTR_NAME_MAX, :COLL_WEIGHTS_MAX, :CSIGNAL, :SOL_RAW],1113 => [:_CS_XBS5_LPBIG_OFFBIG_LDFLAGS],370 => [:SYS_name_to_handle_at],4102 => [:B576000],21531 => [:FIONREAD, :TIOCINQ],2047 => [:RE_DUP_MAX, :STATX_BASIC_STATS],4098 => [:B115200],61 => [:_SC_PII_INTERNET_STREAM, :ENODATA, :SYS_chroot],339 => [:SYS_get_robust_list],128 => [:_SC_XBS5_LPBIG_OFFBIG, :MSG_EOR, :SI_KERNEL, :SI_KERNEL, :EKEYREVOKED, :ADJ_TAI, :MOD_TAI, :STA_FREQHOLD, :TIOCM_RNG, :TIOCM_RI, :IGNCR, :OFDEL, :CREAD, :NOFLSH, :O_EXCL, :LOCK_WRITE, :MAX_HANDLE_SZ, :S_IWUSR, :POLLRDBAND, :EPOLLRDBAND, :S_IWRITE, :STATX_CTIME, :SOMAXCONN, :MSG_EOR, :SI_KERNEL, :WCOREFLAG, :SYS_init_module, :POSIX_SPAWN_SETSID],136 => [:_SC_C_LANG_SUPPORT_R, :SYS_personality],1141 => [:_CS_POSIX_V7_LP64_OFF64_LDFLAGS],4106 => [:B1500000],56 => [:_SC_PII_INTERNET, :EBADRQC, :SO_INCOMING_NAPI_ID],21545 => [:TIOCGSID],-128 => [:INT8_MIN, :INT_LEAST8_MIN, :INT_FAST8_MIN],-6 => [:SI_TKILL, :SI_TKILL, :SI_TKILL],100 => [:_SC_XOPEN_XPG4, :ENETDOWN, :SYS_fstatfs],125 => [:_SC_XBS5_ILP32_OFF32, :ECANCELED, :SYS_mprotect],-4 => [:SI_ASYNCIO, :SI_ASYNCIO, :SI_ASYNCIO],373 => [:SYS_syncfs],364 => [:SYS_perf_event_open],229 => [:SYS_getxattr],113 => [:_SC_SHRT_MAX, :EHOSTUNREACH],67 => [:_SC_THREADS, :ENOLINK, :SYS_sigaction],286 => [:SYS_getsockname],76 => [:_SC_THREAD_THREADS_MAX, :ENOTUNIQ],1123 => [:_CS_POSIX_V6_ILP32_OFFBIG_LINTFLAGS],4104 => [:B1000000],4321 => [:BIG_ENDIAN],40961 => [:ADJ_OFFSET_SS_READ],116 => [:_SC_UINT_MAX, :ESTALE, :SYS_sysinfo],228 => [:SYS_fsetxattr],300 => [:SYS_semctl],4108 => [:B2500000],325 => [:SYS_fchownat],1135 => [:_CS_POSIX_V7_ILP32_OFF32_LINTFLAGS],1134 => [:_CS_POSIX_V7_ILP32_OFF32_LIBS],224 => [:SYS_gettid],21598 => [:FIOQSIZE],25 => [:_SC_AIO_PRIO_DELTA_MAX, :ENOTTY, :CDSUSP, :PF_WANPIPE, :AF_WANPIPE, :SO_BINDTODEVICE, :SIGXFSZ],307 => [:SYS_shmget],21505 => [:TCGETS],179 => [:_SC_V6_LPBIG_OFFBIG, :SYS_rt_sigsuspend],304 => [:SYS_msgctl],372 => [:SYS_clock_adjtime],148 => [:_SC_FILE_SYSTEM, :SYS_fdatasync],181 => [:_SC_TRACE, :SYS_pwrite64],331 => [:SYS_symlinkat],3412 => [:PDP_ENDIAN],20 => [:_PC_2_SYMLINKS, :_SC_MESSAGE_PASSING, :ENOTDIR, :AIO_PRIO_DELTA_MAX, :NZERO, :PF_ATMSVC, :AF_ATMSVC, :SO_RCVTIMEO, :SIGTSTP, :SYS_getpid],149 => [:_SC_MONOTONIC_CLOCK, :SYS__sysctl],16 => [:_PC_REC_MIN_XFER_SIZE, :_SC_MAPPED_FILES, :MSG_PROXY, :EBUSY, :MB_LEN_MAX, :SHRT_WIDTH, :USHRT_WIDTH, :ADJ_STATUS, :MOD_STATUS, :STA_INS, :TIOCPKT_NOSTOP, :TIOCM_SR, :VEOL2, :INPCK, :ONOCR, :CS6, :ECHOE, :F_GETOWN_EX, :DN_RENAME, :FALLOC_FL_ZERO_RANGE, :POLLHUP, :INT16_WIDTH, :UINT16_WIDTH, :INT_LEAST16_WIDTH, :UINT_LEAST16_WIDTH, :EPOLLHUP, :STATX_GID, :STATX_ATTR_IMMUTABLE, :PF_NETLINK, :PF_ROUTE, :AF_NETLINK, :AF_ROUTE, :MSG_PROXY, :SO_PASSCRED, :SIGSTKFLT, :SYS_lchown, :POSIX_SPAWN_SETSCHEDPARAM],1119 => [:_CS_POSIX_V6_ILP32_OFF32_LINTFLAGS],328 => [:SYS_unlinkat],341 => [:SYS_arm_sync_file_range, :SYS_sync_file_range2],1145 => [:_CS_POSIX_V7_LPBIG_OFFBIG_LDFLAGS],21597 => [:TIOCGICOUNT],98 => [:_SC_XOPEN_XPG2, :EADDRINUSE],4097 => [:B57600],1100 => [:_CS_XBS5_ILP32_OFF32_CFLAGS],1149 => [:_CS_V7_ENV],17 => [:_PC_REC_XFER_ALIGN, :_SC_MEMLOCK, :EEXIST, :CSTART, :PF_PACKET, :AF_PACKET, :SO_PEERCRED, :SIGCHLD, :SIGCLD],1136 => [:_CS_POSIX_V7_ILP32_OFFBIG_CFLAGS],81 => [:_SC_THREAD_PRIO_PROTECT, :ELIBSCN, :SYS_setgroups],75 => [:_SC_THREAD_STACK_MIN, :EOVERFLOW, :SYS_setrlimit],30 => [:_SC_PAGESIZE, :EROFS, :PF_TIPC, :AF_TIPC, :SO_ACCEPTCONN, :SIGPWR],156 => [:_SC_REGEX_VERSION, :SYS_sched_setscheduler],1128 => [:_CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS],24576 => [:AT_STATX_SYNC_TYPE, :S_IFBLK],284 => [:SYS_listen],346 => [:SYS_epoll_pwait],36 => [:_SC_BC_BASE_MAX, :ENAMETOOLONG, :F_OFD_GETLK, :PF_IEEE802154, :AF_IEEE802154, :SO_MARK, :SYS_sync],1127 => [:_CS_POSIX_V6_LP64_OFF64_LINTFLAGS],21537 => [:FIONBIO],21532 => [:TIOCLINUX],230 => [:SYS_lgetxattr],375 => [:SYS_setns],21569 => [:TIOCGPTPEER],79 => [:_SC_THREAD_PRIORITY_SCHEDULING, :ELIBACC, :SYS_settimeofday],29 => [:_SC_VERSION, :ESPIPE, :PF_CAN, :AF_CAN, :SO_TIMESTAMP, :SCM_TIMESTAMP, :SIGPOLL, :SIGIO, :SYS_pause],381 => [:SYS_sched_getattr],71 => [:_SC_LOGIN_NAME_MAX, :EPROTO, :SYS_setregid],109 => [:_SC_NZERO, :ETOOMANYREFS],111 => [:_SC_SCHAR_MAX, :ECONNREFUSED, :SYS_vhangup],1038 => [:F_SET_FILE_RW_HINT],306 => [:SYS_shmdt],57 => [:_SC_PII_OSI, :EBADSLT, :SO_COOKIE, :SYS_setpgid],288 => [:SYS_socketpair],84 => [:_SC_NPROCESSORS_ONLN, :EILSEQ],1074025526 => [:TIOCSIG],2 => [:P_PGID, :P_PGID, :PTHREAD_MUTEX_ERRORCHECK_NP, :PTHREAD_PRIO_PROTECT, :PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP, :F_OWNER_PGRP, :_PC_MAX_INPUT, :_SC_CLK_TCK, :_CS_GNU_LIBC_VERSION, :SOCK_DGRAM, :MSG_PEEK, :SCM_CREDENTIALS, :SHUT_RDWR, :ILL_ILLOPN, :ILL_ILLOPN, :FPE_INTOVF, :FPE_INTOVF, :SEGV_ACCERR, :SEGV_ACCERR, :BUS_ADRERR, :BUS_ADRERR, :TRAP_TRACE, :TRAP_TRACE, :CLD_KILLED, :CLD_KILLED, :POLL_OUT, :POLL_OUT, :SIGEV_THREAD, :SIGEV_THREAD, :REG_R2, :REG_R2, :SS_DISABLE, :SS_DISABLE, :ENOENT, :WUNTRACED, :WSTOPPED, :SCHED_RR, :CLOCK_PROCESS_CPUTIME_ID, :ADJ_FREQUENCY, :MOD_FREQUENCY, :STA_PPSFREQ, :TIOCPKT_FLUSHWRITE, :TIOCM_DTR, :N_MOUSE, :VERASE, :BRKINT, :OLCUC, :B75, :ICANON, :TCIOFF, :TCIOFLUSH, :TCSAFLUSH, :O_RDWR, :F_SETFD, :F_UNLCK, :LOCK_EX, :DN_MODIFY, :F_SEAL_SHRINK, :RWH_WRITE_LIFE_SHORT, :POSIX_FADV_SEQUENTIAL, :SYNC_FILE_RANGE_WRITE, :SPLICE_F_NONBLOCK, :FALLOC_FL_PUNCH_HOLE, :W_OK, :SEEK_END, :F_TLOCK, :POLLPRI, :EPOLLPRI, :EPOLL_CTL_DEL, :STDERR_FILENO, :L_XTND, :STATX_MODE, :SOCK_DGRAM, :PF_INET, :AF_INET, :MSG_PEEK, :SCM_CREDENTIALS, :SO_REUSEADDR, :SHUT_RDWR, :SIGINT, :ILL_ILLOPN, :FPE_INTOVF, :SEGV_ACCERR, :BUS_ADRERR, :TRAP_TRACE, :CLD_KILLED, :POLL_OUT, :SIGEV_THREAD, :SA_NOCLDWAIT, :SIG_SETMASK, :REG_R2, :SS_DISABLE, :SYS_fork, :POSIX_SPAWN_SETPGROUP],119 => [:_SC_NL_ARGMAX, :ENAVAIL, :SYS_sigreturn],345 => [:SYS_getcpu],1129 => [:_CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS],1110 => [:_CS_XBS5_LP64_OFF64_LIBS],21559 => [:TIOCVHANGUP],1037 => [:F_GET_FILE_RW_HINT],191 => [:_SC_LEVEL2_CACHE_SIZE, :SYS_ugetrlimit],96 => [:_SC_2_C_VERSION, :EPFNOSUPPORT, :SYS_getpriority],294 => [:SYS_setsockopt],134 => [:_SC_BASE, :SYS_bdflush],6 => [:_PC_CHOWN_RESTRICTED, :_SC_TZNAME_MAX, :SOCK_DCCP, :ILL_PRVREG, :ILL_PRVREG, :FPE_FLTRES, :FPE_FLTRES, :CLD_CONTINUED, :CLD_CONTINUED, :POLL_HUP, :POLL_HUP, :REG_R6, :REG_R6, :ENXIO, :SCHED_DEADLINE, :CLOCK_MONOTONIC_COARSE, :N_X25, :VMIN, :B200, :F_SETLK, :SOCK_DCCP, :PF_NETROM, :AF_NETROM, :SO_BROADCAST, :SIGABRT, :SIGIOT, :ILL_PRVREG, :FPE_FLTRES, :CLD_CONTINUED, :POLL_HUP, :REG_R6, :SYS_close],1000 => [:_CS_LFS_CFLAGS, :BC_STRING_MAX],21508 => [:TCSETSF],4111 => [:CBAUD, :B4000000],318 => [:SYS_inotify_rm_watch],1007 => [:_CS_LFS64_LINTFLAGS],192 => [:_SC_LEVEL2_CACHE_ASSOC, :LOCK_RW, :SYS_mmap2],236 => [:_SC_RAW_SOCKETS, :SYS_lremovexattr],127 => [:INT8_MAX, :INT_LEAST8_MAX, :INT_FAST8_MAX, :_SC_XBS5_LP64_OFF64, :EKEYEXPIRED, :SCHAR_MAX, :CERASE],1036 => [:F_SET_RW_HINT],67108864 => [:MSG_ZEROCOPY, :CLONE_NEWUTS, :MSG_ZEROCOPY],21515 => [:TCFLSH],217 => [:SYS_getdents64],327 => [:SYS_fstatat64],21551 => [:TIOCSRS485],124 => [:_SC_NL_TEXTMAX, :EMEDIUMTYPE, :SYS_adjtimex],4107 => [:B2000000],34 => [:_SC_SIGQUEUE_MAX, :ERANGE, :PF_ISDN, :AF_ISDN, :SO_PASSSEC, :SYS_nice],1121 => [:_CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS],333 => [:SYS_fchmodat],1102 => [:_CS_XBS5_ILP32_OFF32_LIBS],268 => [:SOL_LLC, :SYS_tgkill],89 => [:_SC_XOPEN_VERSION, :EDESTADDRREQ],21584 => [:FIONCLEX],21520 => [:TIOCSPGRP],239 => [:_SC_V7_LP64_OFF64, :SYS_sendfile64],50 => [:_SC_2_FORT_RUN, :ENOCSI, :SO_ATTACH_BPF, :SYS_getegid],21591 => [:TIOCSLCKTRMIOS],99 => [:_SC_XOPEN_XPG3, :EADDRNOTAVAIL, :BC_BASE_MAX, :BC_SCALE_MAX, :SYS_statfs],290 => [:SYS_sendto],103 => [:_SC_CHAR_MIN, :ECONNABORTED, :SYS_syslog],4100 => [:B460800],226 => [:SYS_setxattr],69 => [:_SC_GETGR_R_SIZE_MAX, :ESRMNT],87 => [:_SC_ATEXIT_MAX, :EUSERS, :SYS_swapon],26 => [:_SC_DELAYTIMER_MAX, :ETXTBSY, :CSUSP, :PF_LLC, :AF_LLC, :SO_ATTACH_FILTER, :SO_GET_FILTER, :SIGVTALRM, :SYS_ptrace],292 => [:SYS_recvfrom],31 => [:_SC_RTSIG_MAX, :EMLINK, :PF_BLUETOOTH, :AF_BLUETOOTH, :SO_PEERSEC, :SIGSYS],371 => [:SYS_open_by_handle_at],200 => [:SYS_getgid32],21589 => [:TIOCSERSWILD],233 => [:SYS_llistxattr],1142 => [:_CS_POSIX_V7_LP64_OFF64_LIBS],21538 => [:TIOCNOTTY],4110 => [:B3500000],40 => [:_SC_COLL_WEIGHTS_MAX, :ELOOP, :PF_VSOCK, :AF_VSOCK, :SO_RXQ_OVFL, :SYS_rmdir],303 => [:SYS_msgget],35123 => [:SIOGIFINDEX],329 => [:SYS_renameat],355 => [:SYS_signalfd4],80 => [:_SC_THREAD_PRIO_INHERIT, :ELIBBAD, :SYS_getgroups],190 => [:_SC_LEVEL1_DCACHE_LINESIZE, :SYS_vfork],314 => [:SYS_ioprio_set],1109 => [:_CS_XBS5_LP64_OFF64_LDFLAGS],65 => [:_SC_PII_OSI_M, :ENOPKG, :NSIG, :SYS_getpgrp],363 => [:SYS_rt_tgsigqueueinfo],237 => [:_SC_V7_ILP32_OFF32, :SYS_fremovexattr],49 => [:_SC_2_FORT_DEV, :EUNATCH, :SO_INCOMING_CPU, :SYS_geteuid],247 => [:_SC_THREAD_ROBUST_PRIO_INHERIT, :SYS_io_cancel],342 => [:SYS_tee],243 => [:_SC_TRACE_NAME_MAX, :SYS_io_setup],241 => [:_SC_SS_REPL_MAX, :SYS_sched_setaffinity],1147 => [:_CS_POSIX_V7_LPBIG_OFFBIG_LINTFLAGS],186 => [:_SC_LEVEL1_ICACHE_ASSOC, :SYS_sigaltstack],88 => [:_SC_PASS_MAX, :ENOTSOCK, :SYS_reboot],46 => [:_SC_2_VERSION, :EL3HLT, :SO_BUSY_POLL, :SYS_setgid],32768 => [:MSG_MORE, :MQ_PRIO_MAX, :CLONE_PARENT, :STA_CLK, :FFDLY, :FF1, :IEXTEN, :O_NOFOLLOW, :S_IFREG, :MSG_MORE],140 => [:_SC_DEVICE_IO, :SYS__llseek],392 => [:SYS_preadv2],4095 => [:STATX_ALL],289 => [:SYS_send],157 => [:_SC_SHELL, :SYS_sched_getscheduler],349 => [:SYS_signalfd],244 => [:_SC_TRACE_SYS_MAX, :SYS_io_destroy],11 => [:_PC_PRIO_IO, :_SC_TIMERS, :REG_R11, :REG_R11, :EAGAIN, :EWOULDBLOCK, :CLOCK_TAI, :N_IRDA, :VEOL, :B2400, :F_GETSIG, :PF_ROSE, :AF_ROSE, :SO_NO_CHECK, :SIGSEGV, :REG_R11, :SYS_execve],73 => [:_SC_THREAD_DESTRUCTOR_ITERATIONS, :EDOTDOT, :SYS_sigpending],1048576 => [:CLONE_PARENT_SETTID],330 => [:SYS_linkat],362 => [:SYS_pwritev],21554 => [:TCGETX],21596 => [:TIOCMIWAIT],388 => [:SYS_userfaultfd],1148 => [:_CS_V6_ENV],397 => [:SYS_statx],282 => [:SOL_TLS, :SYS_bind],21523 => [:TIOCGWINSZ],334 => [:SYS_faccessat],219 => [:SYS_mincore],261 => [:SOL_DECNET, :SYS_timer_delete],251 => [:SYS_epoll_ctl],232 => [:SYS_listxattr],21595 => [:TIOCSERSETMULTI],91 => [:_SC_XOPEN_UNIX, :EPROTOTYPE, :SYS_munmap],15 => [:_PC_REC_MAX_XFER_SIZE, :_SC_FSYNC, :REG_R15, :REG_R15, :ENOTBLK, :N_HCI, :CDISCARD, :CFLUSH, :VLNEXT, :B38400, :EXTB, :F_SETOWN_EX, :PF_KEY, :AF_KEY, :SO_REUSEPORT, :SIGTERM, :REG_R15, :SYS_chmod],285 => [:SYS_accept],1130 => [:_CS_POSIX_V6_LPBIG_OFFBIG_LIBS],8 => [:_PC_VDISABLE, :_SC_SAVED_IDS, :MSG_CTRUNC, :ILL_BADSTK, :ILL_BADSTK, :FPE_FLTSUB, :FPE_FLTSUB, :REG_R8, :REG_R8, :ENOEXEC, :CHAR_BIT, :CHAR_WIDTH, :SCHAR_WIDTH, :UCHAR_WIDTH, :WCONTINUED, :CLOCK_REALTIME_ALARM, :ADJ_ESTERROR, :MOD_ESTERROR, :STA_FLL, :TIOCPKT_START, :NCC, :TIOCM_ST, :N_MASC, :VSTART, :PARMRK, :OCRNL, :B600, :ECHO, :F_SETOWN, :F_SHLCK, :LOCK_UN, :DN_DELETE, :F_SEAL_WRITE, :SPLICE_F_GIFT, :FALLOC_FL_COLLAPSE_RANGE, :POLLERR, :INT8_WIDTH, :UINT8_WIDTH, :INT_LEAST8_WIDTH, :UINT_LEAST8_WIDTH, :INT_FAST8_WIDTH, :UINT_FAST8_WIDTH, :EPOLLERR, :STATX_UID, :PF_ATMPVC, :AF_ATMPVC, :MSG_CTRUNC, :SO_RCVBUF, :SIGFPE, :ILL_BADSTK, :FPE_FLTSUB, :REG_R8, :SYS_creat, :POSIX_SPAWN_SETSIGMASK],238 => [:_SC_V7_ILP32_OFFBIG, :SYS_tkill],322 => [:SYS_openat],95 => [:_SC_2_CHAR_TERM, :EOPNOTSUPP, :ENOTSUP, :SYS_fchown],352 => [:SYS_fallocate],332 => [:SYS_readlinkat],4099 => [:B230400],121 => [:_SC_NL_MSGMAX, :EREMOTEIO, :SYS_setdomainname],21528 => [:TIOCMSET],299 => [:SYS_semget],94 => [:_SC_XOPEN_SHM, :ESOCKTNOSUPPORT, :SYS_fchmod],43 => [:_SC_LINE_MAX, :EIDRM, :PF_SMC, :AF_SMC, :SO_NOFCS, :SYS_times],21544 => [:TIOCCBRK],4109 => [:B3000000],1144 => [:_CS_POSIX_V7_LPBIG_OFFBIG_CFLAGS],1026 => [:F_NOTIFY],293 => [:SYS_shutdown],250 => [:SYS_epoll_create],316 => [:SYS_inotify_init],205 => [:SYS_getgroups32],132 => [:_SC_ADVISORY_INFO, :ERFKILL, :SYS_getpgid],164 => [:_SC_TIMEOUTS, :SYS_setresuid],297 => [:SYS_recvmsg],160 => [:_SC_SPORADIC_SERVER, :SYS_sched_get_priority_min],240 => [:_SC_V7_LPBIG_OFFBIG, :SYS_futex],154 => [:_SC_SPIN_LOCKS, :SYS_sched_setparam],144 => [:_SC_FIFO, :SYS_msync],70 => [:_SC_GETPW_R_SIZE_MAX, :ECOMM, :SYS_setreuid],1033 => [:F_ADD_SEALS],291 => [:SYS_recv],106 => [:_SC_LONG_BIT, :EISCONN, :SYS_stat],135 => [:_SC_C_LANG_SUPPORT, :SYS_sysfs],21592 => [:TIOCSERGSTRUCT],343 => [:SYS_vmsplice],213 => [:SYS_setuid32],3 => [:PTHREAD_MUTEX_ADAPTIVE_NP, :_PC_NAME_MAX, :_SC_NGROUPS_MAX, :_CS_GNU_LIBPTHREAD_VERSION, :SOCK_RAW, :ILL_ILLADR, :ILL_ILLADR, :FPE_FLTDIV, :FPE_FLTDIV, :SEGV_BNDERR, :SEGV_BNDERR, :BUS_OBJERR, :BUS_OBJERR, :CLD_DUMPED, :CLD_DUMPED, :POLL_MSG, :POLL_MSG, :REG_R3, :REG_R3, :ESRCH, :SCHED_BATCH, :CLOCK_THREAD_CPUTIME_ID, :N_PPP, :CINTR, :VKILL, :B110, :TCION, :O_ACCMODE, :F_GETFL, :RWH_WRITE_LIFE_MEDIUM, :POSIX_FADV_WILLNEED, :F_TEST, :EPOLL_CTL_MOD, :SEEK_DATA, :SOCK_RAW, :PF_AX25, :AF_AX25, :SO_TYPE, :SIGQUIT, :ILL_ILLADR, :FPE_FLTDIV, :SEGV_BNDERR, :BUS_OBJERR, :CLD_DUMPED, :POLL_MSG, :REG_R3, :SYS_read],13 => [:_PC_FILESIZEBITS, :_SC_PRIORITIZED_IO, :REG_R13, :REG_R13, :EACCES, :N_HDLC, :VDISCARD, :B9600, :F_SETLK64, :PF_NETBEUI, :AF_NETBEUI, :SO_LINGER, :SIGPIPE, :REG_R13],1032 => [:F_GETPIPE_SZ],131 => [:_SC_XOPEN_REALTIME_THREADS, :ENOTRECOVERABLE, :SYS_quotactl],21527 => [:TIOCMBIC],1132 => [:_CS_POSIX_V7_ILP32_OFF32_CFLAGS],313 => [:SYS_vserver],151 => [:_SC_SINGLE_PROCESS, :SYS_munlock],21526 => [:TIOCMBIS],21522 => [:TIOCSTI],193 => [:_SC_LEVEL2_CACHE_LINESIZE, :SYS_truncate64],177 => [:_SC_V6_ILP32_OFFBIG, :SYS_rt_sigtimedwait],14 => [:_PC_REC_INCR_XFER_SIZE, :_SC_SYNCHRONIZED_IO, :REG_R14, :REG_R14, :EFAULT, :N_SYNC_PPP, :VWERASE, :B19200, :EXTA, :F_SETLKW64, :PF_SECURITY, :AF_SECURITY, :SO_BSDCOMPAT, :SIGALRM, :REG_R14, :SYS_mknod],21590 => [:TIOCGLCKTRMIOS],-5 => [:SI_SIGIO, :SI_SIGIO, :SI_SIGIO],1106 => [:_CS_XBS5_ILP32_OFFBIG_LIBS],338 => [:SYS_set_robust_list],21541 => [:TCSBRKP],27 => [:_SC_MQ_OPEN_MAX, :EFBIG, :PF_IB, :AF_IB, :SO_DETACH_FILTER, :SO_DETACH_BPF, :SIGPROF],1101 => [:_CS_XBS5_ILP32_OFF32_LDFLAGS],365 => [:SYS_recvmmsg],385 => [:SYS_memfd_create],21529 => [:TIOCGSOFTCAR],51 => [:_SC_2_SW_DEV, :EL2HLT, :SO_ATTACH_REUSEPORT_CBPF, :SYS_acct],49152 => [:S_IFSOCK],21586 => [:FIOASYNC],78 => [:_SC_THREAD_ATTR_STACKSIZE, :EREMCHG, :SYS_gettimeofday],358 => [:SYS_dup3],1006 => [:_CS_LFS64_LIBS],1073741824 => [:MSG_CMSG_CLOEXEC, :SCHED_RESET_ON_FORK, :CLONE_NEWNET, :CMSPAR, :EPOLLONESHOT, :MSG_CMSG_CLOEXEC, :SA_NODEFER, :SA_NOMASK],68 => [:_SC_THREAD_SAFE_FUNCTIONS, :EADV],337 => [:SYS_unshare],1031 => [:F_SETPIPE_SZ],21585 => [:FIOCLEX],367 => [:SYS_fanotify_init],269 => [:SOL_DCCP, :SYS_utimes],21530 => [:TIOCSSOFTCAR],146 => [:_SC_FILE_ATTRIBUTES, :SYS_writev],383 => [:SYS_seccomp],348 => [:SYS_utimensat],175 => [:_SC_2_PBS_CHECKPOINT, :SYS_rt_sigprocmask],376 => [:SYS_process_vm_readv],382 => [:SYS_renameat2],225 => [:SYS_readahead],35 => [:_SC_TIMER_MAX, :EDEADLK, :EDEADLOCK, :PF_PHONET, :AF_PHONET, :SO_TIMESTAMPNS, :SCM_TIMESTAMPNS],77 => [:_SC_THREAD_ATTR_STACKADDR, :EBADFD, :SYS_getrusage],356 => [:SYS_eventfd2],158 => [:_SC_SIGNALS, :SYS_sched_yield],268435456 => [:CLONE_NEWUSER, :EPOLLEXCLUSIVE, :SA_RESTART],126 => [:_SC_XBS5_ILP32_OFFBIG, :ENOKEY, :SYS_sigprocmask],7 => [:_PC_NO_TRUNC, :_SC_JOB_CONTROL, :ILL_COPROC, :ILL_COPROC, :FPE_FLTINV, :FPE_FLTINV, :REG_R7, :REG_R7, :E2BIG, :CLOCK_BOOTTIME, :N_6PACK, :VSWTC, :B300, :F_SETLKW, :PF_BRIDGE, :AF_BRIDGE, :SO_SNDBUF, :SIGBUS, :ILL_COPROC, :FPE_FLTINV, :REG_R7],207 => [:SYS_fchown32],2147483647 => [:SEM_VALUE_MAX, :INT32_MAX, :INT_LEAST32_MAX, :INT_FAST16_MAX, :INT_FAST32_MAX, :INTPTR_MAX, :PTRDIFF_MAX, :SIG_ATOMIC_MAX, :INT_MAX, :LONG_MAX, :DELAYTIMER_MAX, :SSIZE_MAX, :NL_MSGMAX, :NL_NMAX, :NL_SETMAX, :NL_TEXTMAX, :RAND_MAX],1131 => [:_CS_POSIX_V6_LPBIG_OFFBIG_LINTFLAGS],353 => [:SYS_timerfd_settime],21525 => [:TIOCMGET],368 => [:SYS_fanotify_mark],210 => [:SYS_setresgid32],141 => [:_SC_DEVICE_SPECIFIC, :SYS_getdents],21557 => [:TCSETXW],394 => [:SYS_pkey_mprotect],351 => [:SYS_eventfd],1108 => [:_CS_XBS5_LP64_OFF64_CFLAGS],278 => [:SOL_CAIF, :SYS_mq_notify],1118 => [:_CS_POSIX_V6_ILP32_OFF32_LIBS],145 => [:_SC_PIPE, :SYS_readv],133 => [:_SC_BARRIERS, :EHWPOISON, :SYS_fchdir],42 => [:_SC_EXPR_NEST_MAX, :ENOMSG, :PF_QIPCRTR, :AF_QIPCRTR, :SO_PEEK_OFF, :SYS_pipe],72 => [:_SC_TTY_NAME_MAX, :EMULTIHOP, :SYS_sigsuspend],1030 => [:F_DUPFD_CLOEXEC],1107 => [:_CS_XBS5_ILP32_OFFBIG_LINTFLAGS],21512 => [:TCSETAF],21535 => [:TIOCSSERIAL],21536 => [:TIOCPKT],107 => [:_SC_WORD_BIT, :ENOTCONN, :SYS_lstat],38 => [:_SC_BC_SCALE_MAX, :ENOSYS, :F_OFD_SETLKW, :PF_ALG, :AF_ALG, :SO_PROTOCOL, :SYS_rename],386 => [:SYS_bpf],169 => [:_SC_2_PBS_ACCOUNTING, :SYS_nfsservctl],369 => [:SYS_prlimit64],39 => [:_SC_BC_STRING_MAX, :ENOTEMPTY, :PF_NFC, :AF_NFC, :SO_DOMAIN, :SYS_mkdir],1234 => [:LITTLE_ENDIAN, :BYTE_ORDER],264 => [:SOL_ATM, :SYS_clock_getres],37 => [:_SC_BC_DIM_MAX, :ENOLCK, :F_OFD_SETLK, :PF_CAIF, :AF_CAIF, :SO_TIMESTAMPING, :SCM_TIMESTAMPING, :SYS_kill],163 => [:_SC_SYSTEM_DATABASE_R, :SYS_mremap],18 => [:_PC_ALLOC_SIZE_MIN, :_SC_MEMLOCK_RANGE, :EXDEV, :CREPRINT, :CRPRNT, :PF_ASH, :AF_ASH, :SO_RCVLOWAT, :SIGCONT, :NGREG],320 => [:SYS_get_mempolicy],279 => [:SOL_ALG, :SYS_mq_getsetattr],4103 => [:B921600],112 => [:_SC_SCHAR_MIN, :EHOSTDOWN],263 => [:SOL_PACKET, :SYS_clock_gettime],253 => [:SYS_remap_file_pages],374 => [:SYS_sendmmsg],390 => [:SYS_mlock2],162 => [:_SC_SYSTEM_DATABASE, :SYS_nanosleep],180 => [:_SC_HOST_NAME_MAX, :SYS_pread64],21540 => [:TIOCGETD],1536 => [:CRDLY, :CR3],340 => [:SYS_splice],55 => [:_SC_PII_SOCKET, :ENOANO, :SO_MEMINFO, :SYS_fcntl],378 => [:SYS_kcmp],309 => [:SYS_add_key],271 => [:SOL_TIPC, :SYS_pciconfig_iobase],12 => [:_PC_SOCK_MAXBUF, :_SC_ASYNCHRONOUS_IO, :REG_R12, :REG_R12, :ENOMEM, :N_SMSBLOCK, :VREPRINT, :B4800, :F_GETLK64, :PF_DECnet, :AF_DECnet, :SO_PRIORITY, :SIGUSR2, :REG_R12, :SYS_chdir],74 => [:_SC_THREAD_KEYS_MAX, :EBADMSG, :SYS_sethostname],357 => [:SYS_epoll_create1],-2 => [:SI_TIMER, :SI_TIMER, :SI_TIMER],216 => [:SYS_setfsgid32],361 => [:SYS_preadv],265 => [:SOL_AAL, :SYS_clock_nanosleep],252 => [:SYS_epoll_wait],21518 => [:TIOCSCTTY],323 => [:SYS_mkdirat],54 => [:_SC_PII_XTI, :EXFULL, :SCM_TIMESTAMPING_OPT_STATS, :SYS_ioctl],267 => [:SOL_NETBEUI, :SYS_fstatfs64],359 => [:SYS_pipe2],393 => [:SYS_pwritev2],35073 => [:FIOSETOWN],302 => [:SYS_msgrcv],21533 => [:TIOCCONS],105 => [:_SC_INT_MIN, :ENOBUFS, :SYS_getitimer],33554432 => [:CLONE_NEWCGROUP],258 => [:SYS_timer_settime],-1 => [:SI_QUEUE, :SI_QUEUE, :WAIT_ANY, :PTHREAD_BARRIER_SERIAL_THREAD, :SI_QUEUE],2048 => [:SOCK_NONBLOCK, :MSG_CONFIRM, :BC_DIM_MAX, :LINE_MAX, :CHARCLASS_NAME_MAX, :NL_LANGMAX, :CLONE_SIGHAND, :STA_PPSERROR, :IXANY, :TAB1, :CLOCAL, :ECHOKE, :O_NONBLOCK, :O_NDELAY, :FNONBLOCK, :FNDELAY, :AT_NO_AUTOMOUNT, :S_ISUID, :STATX_BTIME, :STATX_ATTR_ENCRYPTED, :SOCK_NONBLOCK, :MSG_CONFIRM, :MINSIGSTKSZ],1005 => [:_CS_LFS64_LDFLAGS],24 => [:_SC_AIO_MAX, :EMFILE, :PF_PPPOX, :AF_PPPOX, :SO_SECURITY_ENCRYPTION_NETWORK, :SIGXCPU, :SYS_getuid],203 => [:SYS_setreuid32],21514 => [:TCXONC],227 => [:SYS_lsetxattr],134217728 => [:CLONE_NEWIPC, :SA_ONSTACK, :SA_STACK],270 => [:SOL_NETLINK, :SYS_arm_fadvise64_64],2097152 => [:CLONE_CHILD_CLEARTID, :O_PATH],115 => [:_SC_UCHAR_MAX, :EINPROGRESS, :SYS_swapoff],277 => [:SOL_IUCV, :SYS_mq_timedreceive],380 => [:SYS_sched_setattr],1146 => [:_CS_POSIX_V7_LPBIG_OFFBIG_LIBS],97 => [:_SC_2_UPE, :EAFNOSUPPORT, :SYS_setpriority],344 => [:SYS_move_pages],259 => [:SYS_timer_gettime],6144 => [:TABDLY, :TAB3, :XTABS],172 => [:_SC_2_PBS_TRACK, :SYS_prctl],248 => [:_SC_THREAD_ROBUST_PRIO_PROTECT, :SYS_exit_group],21519 => [:TIOCGPGRP],178 => [:_SC_V6_LP64_OFF64, :SYS_rt_sigqueueinfo],208 => [:SYS_setresuid32],1025 => [:F_GETLEASE],273 => [:SOL_PPPOL2TP, :SYS_pciconfig_write],184 => [:_SC_TRACE_LOG, :SYS_capget],189 => [:_SC_LEVEL1_DCACHE_ASSOC],319 => [:SYS_mbind],108 => [:_SC_MB_LEN_MAX, :ESHUTDOWN, :SYS_fstat],1120 => [:_CS_POSIX_V6_ILP32_OFFBIG_CFLAGS],110 => [:_SC_SSIZE_MAX, :ETIMEDOUT],21587 => [:TIOCSERCONFIG],185 => [:_SC_LEVEL1_ICACHE_SIZE, :SYS_capset],249 => [:SYS_lookup_dcookie],8388608 => [:CLONE_UNTRACED],199 => [:_SC_LEVEL4_CACHE_LINESIZE, :SYS_getuid32],257 => [:SYS_timer_create],166 => [:_SC_USER_GROUPS],47 => [:_SC_2_C_BIND, :EL3RST, :SO_MAX_PACING_RATE, :SYS_getgid],61440 => [:S_IFMT],389 => [:SYS_membarrier],171 => [:_SC_2_PBS_MESSAGE, :SYS_getresgid],83 => [:_SC_NPROCESSORS_CONF, :ELIBEXEC, :SYS_symlink],354 => [:SYS_timerfd_gettime],276 => [:SOL_RDS, :SYS_mq_timedsend],317 => [:SYS_inotify_add_watch],4210688 => [:O_TMPFILE],167 => [:_SC_USER_GROUPS_R],48 => [:_SC_2_C_DEV, :ELNRNG, :CSIZE, :CS8, :SO_BPF_EXTENSIONS],52 => [:_SC_2_LOCALEDEF, :EBADE, :SO_ATTACH_REUSEPORT_EBPF, :SYS_umount2],283 => [:SYS_connect],23 => [:_SC_AIO_LISTIO_MAX, :ENFILE, :CWERASE, :PF_IRDA, :AF_IRDA, :SO_SECURITY_ENCRYPTION_TRANSPORT, :SIGURG, :SYS_setuid],4194304 => [:CLONE_DETACHED],168 => [:_SC_2_PBS, :SYS_poll],21509 => [:TCGETA],311 => [:SYS_keyctl],384 => [:SYS_getrandom],379 => [:SYS_finit_module],120 => [:_SC_NL_LANGMAX, :EISNAM, :SYS_clone],524288 => [:EPOLL_CLOEXEC, :SOCK_CLOEXEC, :CLONE_SETTLS, :O_CLOEXEC, :EPOLL_CLOEXEC, :SOCK_CLOEXEC],150 => [:_SC_MULTI_PROCESS, :SYS_mlock],183 => [:_SC_TRACE_INHERIT, :SYS_getcwd],310 => [:SYS_request_key],16777216 => [:WNOWAIT, :CLONE_CHILD_SETTID],8192 => [:MSG_ERRQUEUE, :CLONE_PTRACE, :ADJ_NANO, :MOD_NANO, :STA_NANO, :IMAXBEL, :BSDLY, :BS1, :O_ASYNC, :FASYNC, :AT_STATX_FORCE_SYNC, :S_IFCHR, :POLLRDHUP, :EPOLLRDHUP, :MSG_ERRQUEUE, :SIGSTKSZ],33 => [:_SC_SEM_VALUE_MAX, :EDOM, :PF_RXRPC, :AF_RXRPC, :SO_RCVBUFFORCE, :SYS_access],1111 => [:_CS_XBS5_LP64_OFF64_LINTFLAGS],187 => [:_SC_LEVEL1_ICACHE_LINESIZE, :SYS_sendfile],1004 => [:_CS_LFS64_CFLAGS],324 => [:SYS_mknodat],4 => [:_PC_PATH_MAX, :_SC_OPEN_MAX, :_CS_V5_WIDTH_RESTRICTED_ENVS, :SOCK_RDM, :MSG_DONTROUTE, :ILL_ILLTRP, :ILL_ILLTRP, :FPE_FLTOVF, :FPE_FLTOVF, :SEGV_PKUERR, :SEGV_PKUERR, :BUS_MCEERR_AR, :BUS_MCEERR_AR, :CLD_TRAPPED, :CLD_TRAPPED, :POLL_ERR, :POLL_ERR, :SIGEV_THREAD_ID, :SIGEV_THREAD_ID, :REG_R4, :REG_R4, :EINTR, :PTHREAD_DESTRUCTOR_ITERATIONS, :WEXITED, :SCHED_ISO, :CLOCK_MONOTONIC_RAW, :ADJ_MAXERROR, :MOD_MAXERROR, :STA_PPSTIME, :TIOCPKT_STOP, :TIOCM_RTS, :N_STRIP, :CEOF, :CEOT, :VEOF, :IGNPAR, :ONLCR, :B134, :XCASE, :F_SETFL, :F_EXLCK, :LOCK_NB, :DN_CREATE, :F_SEAL_GROW, :RWH_WRITE_LIFE_LONG, :POSIX_FADV_DONTNEED, :SYNC_FILE_RANGE_WAIT_AFTER, :SPLICE_F_MORE, :FALLOC_FL_NO_HIDE_STALE, :R_OK, :POLLOUT, :EPOLLOUT, :SEEK_HOLE, :STATX_NLINK, :STATX_ATTR_COMPRESSED, :SOCK_RDM, :PF_IPX, :AF_IPX, :MSG_DONTROUTE, :MSG_TRYHARD, :SO_ERROR, :SIGILL, :ILL_ILLTRP, :FPE_FLTOVF, :SEGV_PKUERR, :BUS_MCEERR_AR, :CLD_TRAPPED, :POLL_ERR, :SIGEV_THREAD_ID, :SA_SIGINFO, :REG_R4, :SYS_write, :POSIX_SPAWN_SETSIGDEF],211 => [:SYS_getresgid32],350 => [:SYS_timerfd_create],1034 => [:F_GET_SEALS],398 => [:SYS_rseq],176 => [:_SC_V6_ILP32_OFF32, :SYS_rt_sigpending],395 => [:SYS_pkey_alloc],-60 => [:SI_ASYNCNL, :SI_ASYNCNL, :SI_ASYNCNL],16384 => [:MSG_NOSIGNAL, :PTHREAD_STACK_MIN, :CLONE_VFORK, :ADJ_TICK, :MOD_CLKB, :STA_MODE, :IUTF8, :VTDLY, :VT1, :PENDIN, :O_DIRECTORY, :AT_STATX_DONT_SYNC, :S_IFDIR, :MSG_NOSIGNAL],137 => [:_SC_CLOCK_SELECTION],1112 => [:_CS_XBS5_LPBIG_OFFBIG_CFLAGS],1052672 => [:O_SYNC, :O_FSYNC, :O_RSYNC, :FFSYNC],1115 => [:_CS_XBS5_LPBIG_OFFBIG_LINTFLAGS],1103 => [:_CS_XBS5_ILP32_OFF32_LINTFLAGS],44 => [:_SC_RE_DUP_MAX, :ECHRNG, :PF_MAX, :AF_MAX, :SO_LOCK_FILTER],142 => [:_SC_DEVICE_SPECIFIC_R, :SYS__newselect],45 => [:_SC_CHARCLASS_NAME_MAX, :EL2NSYNC, :SO_SELECT_ERR_QUEUE, :SYS_brk],21534 => [:TIOCGSERIAL],1143 => [:_CS_POSIX_V7_LP64_OFF64_LINTFLAGS],123 => [:_SC_NL_SETMAX, :ENOMEDIUM],40960 => [:S_IFLNK],21593 => [:TIOCSERGETLSR],182 => [:_SC_TRACE_EVENT_FILTER, :SYS_chown],19 => [:_PC_SYMLINK_MAX, :_SC_MEMORY_PROTECTION, :ENODEV, :CSTOP, :PF_ECONET, :AF_ECONET, :SO_SNDLOWAT, :SIGSTOP, :SYS_lseek],391 => [:SYS_copy_file_range],59 => [:_SC_SELECT, :EBFONT, :SO_PEERGROUPS],360 => [:SYS_inotify_init1],246 => [:_SC_XOPEN_STREAMS, :SYS_io_submit],326 => [:SYS_futimesat],90 => [:_SC_XOPEN_XCU_VERSION, :EMSGSIZE],161 => [:_SC_THREAD_SPORADIC_SERVER, :SYS_sched_rr_get_interval],214 => [:SYS_setgid32],139 => [:_SC_THREAD_CPUTIME, :SYS_setfsgid],170 => [:_SC_2_PBS_LOCATE, :SYS_setresgid],21 => [:_SC_SEMAPHORES, :EISDIR, :CKILL, :PF_RDS, :AF_RDS, :SO_SNDTIMEO, :SIGTTIN, :SYS_mount],218 => [:SYS_pivot_root],1 => [:P_PID, :P_PID, :PTHREAD_CREATE_DETACHED, :PTHREAD_MUTEX_RECURSIVE_NP, :PTHREAD_MUTEX_ROBUST, :PTHREAD_PRIO_INHERIT, :PTHREAD_RWLOCK_PREFER_WRITER_NP, :PTHREAD_EXPLICIT_SCHED, :PTHREAD_SCOPE_PROCESS, :PTHREAD_PROCESS_SHARED, :PTHREAD_CANCEL_DISABLE, :PTHREAD_CANCEL_ASYNCHRONOUS, :F_OWNER_PID, :_PC_MAX_CANON, :_SC_CHILD_MAX, :_CS_V6_WIDTH_RESTRICTED_ENVS, :SOCK_STREAM, :MSG_OOB, :SCM_RIGHTS, :SHUT_WR, :ILL_ILLOPC, :ILL_ILLOPC, :FPE_INTDIV, :FPE_INTDIV, :SEGV_MAPERR, :SEGV_MAPERR, :BUS_ADRALN, :BUS_ADRALN, :TRAP_BRKPT, :TRAP_BRKPT, :CLD_EXITED, :CLD_EXITED, :POLL_IN, :POLL_IN, :SIGEV_NONE, :SIGEV_NONE, :REG_R1, :REG_R1, :SS_ONSTACK, :SS_ONSTACK, :EPERM, :WNOHANG, :EXIT_FAILURE, :SCHED_FIFO, :CLOCK_MONOTONIC, :TIMER_ABSTIME, :ADJ_OFFSET, :MOD_OFFSET, :STA_PLL, :TIME_UTC, :PTHREAD_CREATE_DETACHED, :PTHREAD_EXPLICIT_SCHED, :PTHREAD_SCOPE_PROCESS, :PTHREAD_PROCESS_SHARED, :PTHREAD_CANCEL_DISABLE, :PTHREAD_CANCEL_ASYNCHRONOUS, :TIOCPKT_FLUSHREAD, :TIOCSER_TEMT, :TIOCM_LE, :N_SLIP, :CMIN, :VQUIT, :IGNBRK, :OPOST, :B50, :ISIG, :TCOON, :TCOFLUSH, :TCSADRAIN, :O_WRONLY, :F_GETFD, :FD_CLOEXEC, :F_WRLCK, :LOCK_SH, :DN_ACCESS, :F_SEAL_SEAL, :RWH_WRITE_LIFE_NONE, :POSIX_FADV_RANDOM, :SYNC_FILE_RANGE_WAIT_BEFORE, :SPLICE_F_MOVE, :FALLOC_FL_KEEP_SIZE, :X_OK, :SEEK_CUR, :F_LOCK, :POLLIN, :EPOLLIN, :EPOLL_CTL_ADD, :STDOUT_FILENO, :L_INCR, :STATX_TYPE, :SOCK_STREAM, :PF_LOCAL, :PF_UNIX, :PF_FILE, :AF_LOCAL, :AF_UNIX, :AF_FILE, :MSG_OOB, :SCM_RIGHTS, :SOL_SOCKET, :SO_DEBUG, :SHUT_WR, :SIGHUP, :ILL_ILLOPC, :FPE_INTDIV, :SEGV_MAPERR, :BUS_ADRALN, :TRAP_BRKPT, :CLD_EXITED, :POLL_IN, :SIGEV_NONE, :SA_NOCLDSTOP, :SIG_UNBLOCK, :REG_R1, :SS_ONSTACK, :SYS_exit, :POSIX_SPAWN_RESETIDS],287 => [:SYS_getpeername])
