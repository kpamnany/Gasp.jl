const fan_out = 512
const drain_rate = 0.5

type Dtree
    handle::Array{Ptr{Void}}

    function Dtree(fan_out::Int, num_work_items::Int64,
            can_parent::Bool, rank_mul::Float64,
            first::Float64, rest::Float64, min_dist::Int)
        parents_work = nthreads()>1 ? 1 : 0
        cthrid = cfunction(threadid, Int64, ())
        d = new([0])
        p = [ 0 ]
        r = ccall((:dtree_create, libgasp), Cint,
                (Ptr{Void}, Cint, Cint, Cint, Cint, Cdouble, Cint, Ptr{Void},
                Cdouble, Cdouble, Cshort, Ptr{Void}, Ptr{Int64}),
                ghandle[1], fan_out, num_work_items, can_parent, parents_work,
                rank_mul, nthreads(), cthrid, first, rest, min_dist,
                pointer(d.handle), pointer(p, 1))
        if r != 0
            error("construction failure")
        end
        finalizer(d, (x -> ccall((:dtree_destroy, libgasp),
                                 Void, (Ptr{Void},), d.handle[1])))
        d, Bool(p[1])
    end
end

Dtree(num_work_items::Int64, first::Float64) =
    Dtree(fan_out, num_work_items, true, 1.0, first, drain_rate, 1)
Dtree(num_work_items::Int64, first::Float64, min_distrib::Int) =
    Dtree(fan_out, num_work_items, true, 1.0, first, drain_rate, min_distrib)
Dtree(num_work_items::Int64, first::Float64, rest::Float64, min_distrib::Int) =
    Dtree(fan_out, num_work_items, true, 1.0, first, rest, min_distrib)

function initwork(dt::Dtree)
    w = [ 1, 1 ]::Array{Int64}
    wp1 = pointer(w, 1)
    wp2 = pointer(w, 2)
    gs = enter_gc_safepoint()
    r = ccall((:dtree_initwork, libgasp), Cint,
            (Ptr{Void}, Ptr{Int64}, Ptr{Int64}), dt.handle[1], wp1, wp2)
    leave_gc_safepoint(gs)
    return r, (w[1]+1, w[2])
end

function getwork(dt::Dtree)
    w = [ 1, 1 ]::Array{Int64}
    wp1 = pointer(w, 1)
    wp2 = pointer(w, 2)
    gs = enter_gc_safepoint()
    r = ccall((:dtree_getwork, libgasp), Cint,
            (Ptr{Void}, Ptr{Int64}, Ptr{Int64}), dt.handle[1], wp1, wp2)
    leave_gc_safepoint(gs)
    return r, (w[1]+1, w[2])
end

function runtree(dt::Dtree)
    r = 0
    gs = enter_gc_safepoint()
    r = ccall((:dtree_run, libgasp), Cint, (Ptr{Void},), dt.handle[1])
    leave_gc_safepoint(gs)
    Bool(r > 0)
end

