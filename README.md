Gasp.jl
=======

[![Build Status](https://travis-ci.org/kpamnany/Gasp.jl.svg?branch=master)](https://travis-ci.org/kpamnany/Gasp.jl)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/kpamnany/Gasp.jl/blob/master/LICENSE)

Global Address SPace toolbox -- Julia wrapper for [gasp](https://github.com/kpamnany/gasp).

## Description

The [Dtree](http://dx.doi.org/10.1007/978-3-319-20119-1_10) distributed dynamic scheduler, and a fast minimal implementation global
arrays implementation with an interface based on [GA](http://hpc.pnl.gov/globalarrays/index.shtml).

+ MPI-2 asynchronous communication and MPI-3 one-sided RMA
+ C11/Linux; tested on Cray machines and Intel clusters

## Usage

#### Dtree:

See the paper linked above for details on Dtree parameters. See `test/dtreebench.jl` for a more detailed example.
```julia
using Gasp

# required scheduler parameters
num_work_items = 50000
first = 0.5
min_distrib = 1

# create the scheduler
dt, is_parent = Dtree(num_work_items, first, min_distrib)

# get the initial work allocation
num_items, (cur_item, last_item) = initwork(dt)

# run the tree once (to see if we need to keep running it)
run_dt = runtree(dt)

if is_parent && run_dt
    while runtree(dt)
        Gasp.cpu_pause()
    end
else
    # work loop
    while num_items > 0
        if last_item == 0
            break
        end
        if cur_item == last_item
            num_items, (cur_item, last_item) = getwork(dt)
            continue
        end
        item = ci
        ci = ci + 1

        # process `item`
    end
end
```

#### Global arrays:

See Global Arrays documentation for PGAS model and concepts. See `test/garraytest.jl` for a more detailed example.
```julia
using Gasp

# global array types must be immutable (or have serialize/deserialize functions)
immutable Aelem
    a::Int64
    b::Int64
end

# create the array
nelems = ngranks * 100
ga = Garray(Aelem, sizeof(Aelem)+8, nelems)

# misc array functions
@assert length(ga) == ngranks * 100
@assert elemsize(ga) == sizeof(Aelem)+8

# get the local part on this rank
lo, hi = distribution(ga, grank)
@assert lo == ((grank - 1) * 100) + 1
@assert hi == lo + 99

# write into the local part (lo - hi inclusive)
p = access(ga, lo, hi)
for i = 1:length(p)
    p[i] = Aelem(lo + i - 1, grank)
end

# p is no longer valid after flush
flush(ga)

# let all ranks complete writing
sync()

# put/get
ti = (hi + 1) % nelems
put!(ga, ti, ti, [Aelem(100 + grank, grank)])
sync()

ti = (ti + 100) % nelems
q = get(ga, ti, ti)
println(q[1])

# clean up
finalize(ga)
```

