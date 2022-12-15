using GrandCentralDispatch_jll

const libdisatch = GrandCentralDispatch_jll.libdispatch


#=
function dispatch_read(fd, length, queue, data, error, notify, complete)
    @ccall libdispatch.jl_dispatch_read(fd::C.dispatch_fd_t, 
                                        length::C.size_t ,
                                        queue::C.dispatch_queue_t,
                                        data::Ptr{C.dispatch_data_t},
                                        error::Ptr{Cint},
                                        notify::Ptr{Cvoid},
                                        complete::Ptr{Cvoid}
                                        )::Cvoid
end
=#


dispatch_source(::In, fd, buf, length, offset, result, err, queue, notify, complete) =
    @ccall libdispatch.jl_dispatch_read_source(fd::C.dispatch_fd_t, 
                                               buf::Ptr{UInt8},
                                               length::C.size_t,
                                               offset::C.off_t,
                                               result::Ptr{Cint},
                                               err::Ptr{Cint},
                                               queue::C.dispatch_queue_t,
                                               notify::Ptr{Cvoid},
                                               complete::Ptr{Cvoid}
                                               )::Cvoid


dispatch_source(::Out, fd, buf, length, offset, result, err, queue, notify, complete) =
    @ccall libdispatch.jl_dispatch_write_source(fd::C.dispatch_fd_t, 
                                                buf::Ptr{UInt8},
                                                length::C.size_t,
                                                offset::C.off_t,
                                                result::Ptr{Cint},
                                                err::Ptr{Cint},
                                                queue::C.dispatch_queue_t,
                                                notify::Ptr{Cvoid},
                                                complete::Ptr{Cvoid}
                                                )::Cvoid


#=

function dispatch_write(fd, data, queue, handler, context)
    @ccall libdispatch.jl_dispatch_read(fd::C.dispatch_fd_t, 
                                        data::C.dispatch_data_t,
                                        queue::C.dispatch_queue_t,
                                        handler::Ptr{Cvoid},
                                        context::Ptr{Cvoid}
                                        )::Cvoid
end

=#


mutable struct GSDQueue
    queue::C.dispatch_queue_t
end


const gsd_queue = GSDQueue(C_NULL)

@db function gsd_queue_init()
    gsd_queue.queue = 
        C.dispatch_get_global_queue(C.DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
end


gsd_notify(handle) = ccall(:uv_async_send, Cvoid, (Ptr{Cvoid},), handle)

@db 1 function raw_transfer(fd, ::TransferAPI{:GSD}, dir::AnyDirection,  buf,
                            fd_offset, count)

    result = Ref(Cint(0))
    err = Ref(Cint(0))

    if ismissing(fd_offset)
        fd_offset = -1
    end

    cond = Base.AsyncCondition()
    GC.@preserve cond begin
        dispatch_source(dir, fd, buf, count, fd_offset, result, err,
                        gsd_queue.queue,
                        @cfunction(gsd_notify, Cvoid, (Ptr{Cvoid},)),
                        cond.handle)
        if result[] == 0
            wait(cond)
        end

        errno(err[])
        return result[]
    end
    

    #=
    data = Ref(C.dispatch_data_t(0))
    err = Ref(Cint(0))
    cond = Base.AsyncCondition()
    GC.@preserve cond begin
        dispatch_read(fd.fd, count, gsd_queue.queue,
                      data, err,
                      @cfunction(gsd_notify, Cvoid, (Ptr{Cvoid},)),
                      cond.handle)
        wait(cond)
    end

    if err[] != 0
        @error "dispatch_read() error" err
        @assert false
    end

    map_buf = Ref(Ptr{Cvoid}(0))
    map_size = Ref(C.size_t(0))
    tmp = C.dispatch_data_create_map(data[], map_buf, map_size)
    unsafe_copyto!(buf,
                   convert(Ptr{UInt8}, map_buf[]),
                   map_size[])

    @ccall dispatch_release(tmp::C.dispatch_data_t)::Cvoid
    @ccall dispatch_release(data[]::C.dispatch_data_t)::Cvoid
    
    map_size[]
    =#
end
