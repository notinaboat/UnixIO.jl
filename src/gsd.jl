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


function dispatch_read_source(fd, buf, length, result, err, queue, notify, complete)
    @ccall libdispatch.jl_dispatch_read_source(fd::C.dispatch_fd_t, 
                                               buf::Ptr{UInt8},
                                               length::C.size_t ,
                                               result::Ptr{Cint},
                                               err::Ptr{Cint},
                                               queue::C.dispatch_queue_t,
                                               notify::Ptr{Cvoid},
                                               complete::Ptr{Cvoid}
                                               )::Cvoid
end

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


function raw_transfer(fd, ::GSDTransfer, ::Out, buf, count)
    # FIXME
    C.write(fd, buf, count)
end


gsd_notify(handle) = ccall(:uv_async_send, Cvoid, (Ptr{Cvoid},), handle)

@db 1 function raw_transfer(fd, ::GSDTransfer, ::In,  buf, count)

    result = Ref(Cint(0))
    err = Ref(Cint(0))

    cond = Base.AsyncCondition()
    GC.@preserve cond begin
        dispatch_read_source(fd, buf, count, result, err,
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
