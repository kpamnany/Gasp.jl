#!/usr/bin/env julia

using Gasp

immutable Aelem
    idx::Int64
    rank::Int64
end

@inline nputs(s...) = ccall(:puts, Cint, (Cstring,), string("[$grank] ", s...))

macro tst(ex)
    oex = Expr(:inert, ex)
    quote
        r = $ex
        nputs(r ? "passed: " : "failed: ", $oex)
    end
end

if rank == 1
    ccall(:puts, Cint, (Cstring,), string("garraytest -- $ngranks ranks\n"))
end

# even distribution
# ---
nelems = ngranks * 5

# create the array
ga = Garray(Aelem, sizeof(Aelem)+8, nelems)
@tst ndims(ga) == 1
@tst length(ga) == ngranks * 5
@tst size(ga) == tuple(ngranks * 5)

# get the local part
lo, hi = distribution(ga, grank)
@tst lo[1] == ((grank-1)*5)+1
@tst hi[1] == lo[1]+4

nputs(lo, "-", hi)

# write into the local part
p = access(ga, lo, hi)
nputs(hi[1]-lo[1]+1)
for i = 1:hi[1]-lo[1]+1
    p[i] = Aelem(lo[1]+i-1, grank)
end

# let all ranks complete writing
flush(ga)
sync()

# get the whole array on rank 1 and verify it
even_dist_garray = true
if grank == 1
    fa, fa_handle = get(ga, [1], [nelems])
    for i=1:nelems
        if fa[i].idx != i
            println(i, fa[i])
            even_dist_garray = false
            break
        end
    end
    @tst even_dist_garray
end

finalize(ga)


# uneven distribution
# ---
nelems = nelems + Int(ceil(ngranks/2))
ga = Garray(Aelem, sizeof(Aelem)+8, nelems)

# get the local part, write into it, and sync
lo, hi = distribution(ga, grank)
nputs(lo, "-", hi)
p = access(ga, lo, hi)
for i = 1:hi[1]-lo[1]+1
    p[i] = Aelem(lo[1]+i-1, grank)
end
flush(ga)
sync()

# get the whole array on rank 1 and verify it
uneven_dist_garray = true
if grank == 1
    fa, fa_handle = get(ga, [1], [nelems])
    for i=1:nelems
        if fa[i].idx != i
            uneven_dist_garray = false
            break
        end
    end
    @tst uneven_dist_garray
end

finalize(ga)

