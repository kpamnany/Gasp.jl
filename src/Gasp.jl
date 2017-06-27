__precompile__()

module Gasp

using Base.Threads
enter_gc_safepoint() = ccall(:jl_gc_safe_enter, Int8, ())
leave_gc_safepoint(gs) = ccall(:jl_gc_safe_leave, Void, (Int8,), gs)

import Base.length, Base.get, Base.put!, Base.flush
export Garray, GarrayMemoryHandle, Dtree, Dlog,
       ngranks, grank, affinitize, message,
       sync, distribution, access, elemsize,
       initwork, getwork, runtree

const libgasp = joinpath(dirname(@__FILE__), "..", "deps", "gasp",
        "libgasp.$(Libdl.dlext)")

const ghandle = [C_NULL]
num_garrays = 0
exiting = false

@noinline function init_gasp()
     global ghandle
     ccall((:gasp_init, libgasp), Int64, (Cint, Ptr{Ptr{UInt8}}, Ptr{Void}),
          length(ARGS), ARGS, pointer(ghandle, 1))
end

function __init__()
    # Work around openmpi not being loadable in a private namespace
    Libdl.dlopen(libgasp, Libdl.RTLD_GLOBAL)
    init_gasp()
    atexit() do
        global exiting
        exiting = true
    end
end

# uncomment for static builds
#__init__()

function __shutdown__()
    ccall((:gasp_shutdown, libgasp), Void, (Ptr{Void},), ghandle[1])
end

@inline ngranks() = ccall((:gasp_nranks, libgasp), Int64, ())
@inline grank() = ccall((:gasp_rank, libgasp), Int64, ())+1
@inline sync() = ccall((:gasp_sync, libgasp), Void, ())
@inline cpu_pause() = ccall((:cpu_pause, libgasp), Void, ())
@inline rdtsc() = ccall((:rdtsc, libgasp), Culonglong, ())
@inline start_sde_tracing() = ccall((:start_sde_tracing, libgasp), Void, ())
@inline stop_sde_tracing() = ccall((:stop_sde_tracing, libgasp), Void, ())

show_affinity() = ccall(:puts, Cint, (Cstring,), "<$(threadid())> => $(ccall(:sched_getcpu, Cint, ()))")
show_affinity_mask() = ccall((:show_affinity_mask, Gasp.libgasp), Void, (Cint,), threadid())

function affinitize(avail_cores::Int,
                    avail_threads_per_core::Int,
                    ranks_per_node::Int;
                    use_threads_per_core::Int=1,
                    show::Bool=false)
    function set_thread_affinity()
        start = (((grank() - 1) % ranks_per_node) * div(nthreads(), use_threads_per_core))
        tid = threadid()
        offset, ht = divrem(tid - 1, use_threads_per_core)
        for i = 1:ht
            offset = offset + avail_cores
        end
        target = start + offset
        ccall((:set_affinity, libgasp), Cint, (Cint,), target)
        show && show_affinity()
    end
    ccall(:jl_threading_run, Void, (Any,), Core.svec(set_thread_affinity))
end

include("Garray.jl")
include("Dtree.jl")
include("Dlog.jl")

end # module

