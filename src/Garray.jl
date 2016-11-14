type Garray
    ahandle::Array{Ptr{Void}}
    atyp::DataType
    elem_size::Int64
    access_iob::IOBuffer
    access_arr::Array
end

typealias GarrayMemoryHandle IOBuffer

function Garray(T::DataType, elem_size::Int64, dims...)
    nd = length(dims)
    if nd < 1
        error("Garray must have at least one dimension")
    end
    adims = collect(dims)::Vector{Int64}
    a = Garray([C_NULL], T, elem_size, IOBuffer(), [])
    r = ccall((:garray_create, libgasp), Int64, (Ptr{Void}, Int64, Ptr{Int64},
            Int64, Ptr{Int64}, Ptr{Void}), ghandle[1], nd, adims, a.elem_size,
            C_NULL, pointer(a.ahandle, 1))
    if r != 0
        error("construction failure")
    end
    global num_garrays
    num_garrays = num_garrays+1
    finalizer(a, (function(a)
                    ccall((:garray_destroy, libgasp),
                            Void, (Ptr{Void},), a.ahandle[1])
                    global num_garrays
                    num_garrays = num_garrays-1
                    exiting && num_garrays == 0 && __shutdown__()
                  end))
    return a
end

function ndims(ga::Garray)
    ccall((:garray_ndims, libgasp), Int64, (Ptr{Void},), ga.ahandle[1])
end

function length(ga::Garray)
    ccall((:garray_length, libgasp), Int64, (Ptr{Void},), ga.ahandle[1])
end

function size(ga::Garray)
    dims = Array(Int64, ndims(ga))
    r = ccall((:garray_size, libgasp), Int64, (Ptr{Void}, Ptr{Int64}),
            ga.ahandle[1], dims)
    if r != 0
        error("could not get size")
    end
    return tuple(dims...)
end

function get(ga::Garray, lo::Vector{Int64}, hi::Vector{Int64})
    adjlo = lo - 1
    adjhi = hi - 1
    dims = hi - lo + 1
    cbufdims = dims * ga.elem_size
    cbuf = Array(UInt8, cbufdims...)
    r = ccall((:garray_get, libgasp), Int64, (Ptr{Void}, Ptr{Int64}, Ptr{Int64},
            Ptr{Void}), ga.ahandle[1], adjlo, adjhi, cbuf)
    if r != 0
        error("Garray get failed")
    end
    iob = IOBuffer(cbuf)
    buf = Array(ga.atyp, dims...)
    for i = 1:length(buf)
        try
            buf[i] = deserialize(iob)
        catch e
            break
        end
        seek(iob, i * ga.elem_size)
    end
    return buf, iob
end

function put!(ga::Garray, lo::Vector{Int64}, hi::Vector{Int64}, buf::Array)
    adjlo = lo - 1
    adjhi = hi - 1
    dims = hi - lo + 1
    cbufdims = dims * ga.elem_size
    cbuf = Array(UInt8, cbufdims...)
    iob = IOBuffer(cbuf, true, true)
    for i = 1:length(buf)
        serialize(iob, buf[i])
        seek(iob, i * ga.elem_size)
    end
    r = ccall((:garray_put, libgasp), Int64, (Ptr{Void}, Ptr{Int64}, Ptr{Int64},
            Ptr{Void}), ga.ahandle[1], adjlo, adjhi, cbuf)
    if r != 0
        error("Garray put failed")
    end
end

function distribution(ga::Garray, nid::Int64)
    nd = ndims(ga)
    lo = Array(Int64, nd)
    hi = Array(Int64, nd)
    r = ccall((:garray_distribution, libgasp), Int64, (Ptr{Void}, Int64,
            Ptr{Int64}, Ptr{Int64}), ga.ahandle[1], nid-1, lo, hi)
    if r != 0
        error("could not get distribution")
    end
    lo = lo+1
    hi = hi+1
    return lo, hi
end

function access(ga::Garray, lo::Vector{Int64}, hi::Vector{Int64})
    p = [C_NULL]
    r = ccall((:garray_access, libgasp), Int64, (Ptr{Void}, Ptr{Int64},
            Ptr{Int64}, Ptr{Ptr{Void}}), ga.ahandle[1], lo-1, hi-1,
            pointer(p, 1))
    if r != 0
        error("could not get access")
    end
    dims = hi - lo + 1
    buf = Array(ga.atyp, dims...)
    if length(buf) == 0
        return buf
    end
    cdims = dims * ga.elem_size
    iob = IOBuffer(unsafe_wrap(Array, convert(Ptr{UInt8}, p[1]), cdims...),
                   true, true)

    for i = 1:length(buf)
        try
            buf[i] = deserialize(iob)
        catch exc
            if !isa(exc, UndefRefError) && !isa(exc, BoundsError)
                rethrow()
            end
            # this is expected when an array element is uninitialized
        end
        seek(iob, i * ga.elem_size)
    end
    seek(iob, 0)
    ga.access_iob = iob
    ga.access_arr = buf
    return buf
end

function flush(ga::Garray)
    if ga.access_arr != []
        for i = 1:length(ga.access_arr)
            try serialize(ga.access_iob, ga.access_arr[i])
            catch exc
                if !isa(exc, UndefRefError)
                    rethrow()
                end
            end
            seek(ga.access_iob, i * ga.elem_size)
        end
        ga.access_arr = []
    end
    ccall((:garray_flush, libgasp), Void, (Ptr{Void},), ga.ahandle[1])
end

