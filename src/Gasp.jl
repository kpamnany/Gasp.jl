module Gasp

using Base.Threads
enter_gc_safepoint() = ccall(:jl_gc_safe_enter, Int8, ())
leave_gc_safepoint(gs) = ccall(:jl_gc_safe_leave, Void, (Int8,), gs)

import Base.ndims, Base.length, Base.size, Base.get, Base.put!, Base.flush
export Garray, GarrayMemoryHandle, Dtree, ngranks, grank,
       sync, distribution, access,
       initwork, getwork, runtree

const libgasp = joinpath(dirname(@__FILE__), "..", "deps", "gasp",
        "libgasp.$(Libdl.dlext)")

function __init__()
    global const ghandle = [C_NULL]
    ccall((:gasp_init, libgasp), Int64, (Cint, Ptr{Ptr{UInt8}}, Ptr{Void}),
          length(ARGS), ARGS, pointer(ghandle, 1))
    global const ngranks = ccall((:gasp_nranks, libgasp), Int64, ())
    global const grank = ccall((:gasp_rank, libgasp), Int64, ())+1
    global num_garrays = 0
    global exiting = false
    atexit() do
        global exiting
        exiting = true
    end
end

function __shutdown__()
    ccall((:gasp_shutdown, libgasp), Void, (Ptr{Void},), ghandle[1])
end

@inline sync() = ccall((:gasp_sync, libgasp), Void, ())
@inline cpu_pause() = ccall((:cpu_pause, libgasp), Void, ())
@inline rdtsc() = ccall((:rdtsc, libgasp), Culonglong, ())
@inline start_sde_tracing() = ccall((:start_sde_tracing, libgasp), Void, ())
@inline stop_sde_tracing() = ccall((:stop_sde_tracing, libgasp), Void, ())

function affinitize(rpn::Int; show::Bool=false)
    function set_thread_affinity()
        tid = threadid()
        cpu = (((grank - 1) % rpn) * nthreads())
        show && ccall(:puts, Cint, (Cstring,), string("[$grank]<$tid> bound to $(cpu + tid)"))
        mask = zeros(UInt8, 4096)
        mask[cpu + tid] = 1
        uvtid = ccall(:uv_thread_self, UInt64, ())
        ccall(:uv_thread_setaffinity, Int, (Ptr{Void}, Ptr{Void}, Ptr{Void}, Int64),
              pointer_from_objref(uvtid), mask, C_NULL, 4096)
    end
    ccall(:jl_threading_run, Void, (Any,), Core.svec(set_thread_affinity))
end

include("Garray.jl")
include("Dtree.jl")

end # module

