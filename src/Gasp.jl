module Gasp

using Base.Threads
enter_gc_safepoint() = ccall(:jl_gc_safe_enter, Int8, ())
leave_gc_safepoint(gs) = ccall(:jl_gc_safe_leave, Void, (Int8,), gs)

import Base.ndims, Base.length, Base.size, Base.get, Base.put!, Base.flush
export Garray, GarrayMemoryHandle, Dtree, nnodes, nodeid,
       sync, distribution, access,
       initwork, getwork, runtree

const libgasp = joinpath(dirname(@__FILE__), "..", "deps", "gasp",
        "libgasp.$(Libdl.dlext)")

function __init__()
    global const ghandle = [C_NULL]
    ccall((:gasp_init, libgasp), Int64, (Cint, Ptr{Ptr{UInt8}}, Ptr{Void}),
          length(ARGS), ARGS, pointer(ghandle, 1))
    global const nnodes = ccall((:gasp_nnodes, libgasp), Int64, ())
    global const nodeid = ccall((:gasp_nodeid, libgasp), Int64, ())+1
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

include("Garray.jl")
include("Dtree.jl")

end # module

