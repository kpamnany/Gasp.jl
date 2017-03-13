#!/usr/bin/env julia

using Gasp
using Base.Threads

cpu_hz = 0.0

@inline ntputs(tid, s...) = ccall(:puts, Cint, (Ptr{Int8},), string("[$(grank())]<$tid> ", s...))

function threadfun(dt, ni, ci, li, ilock, rundt, dura)
    tid = threadid()
    if rundt && tid == 1
        ntputs(tid, "running tree")
        while runtree(dt)
            Gasp.cpu_pause()
        end
    else
        ntputs(tid, string("begin, ", ni[], " items, ", length(dura), " available delays"))
        while ni[] > 0
            lock(ilock)
            if li[] == 0
                ntputs(tid, string("out of work"))
                unlock(ilock)
                break
            end
            if ci[] == li[]
                ntputs(tid, string("work consumed (last was ", li[], "); requesting more"))
                ni[], (ci[], li[]) = getwork(dt)
                ntputs(tid, string("got ", ni[], " work items (", ci[], " to ", li[], ")"))
                unlock(ilock)
                continue
            end
            item = ci[]
            ci[] = ci[] + 1
            unlock(ilock)

            # wait dura[item] seconds
            global cpu_hz
            ticks = dura[item] * cpu_hz
            #ntputs(tid, "item $item: $(dura[item]) secs, $ticks ticks")
            startts = Gasp.rdtsc()
            while Gasp.rdtsc() - startts < ticks
                Gasp.cpu_pause()
            end
        end
    end
end

function bench(nwi, meani, stddevi, first_distrib, rest_distrib, min_distrib, fan_out = 1024)
    # get CPU speed
    global cpu_hz
    t = Gasp.rdtsc()
    sleep(1)
    cpu_hz = Gasp.rdtsc() - t

    # create the tree
    dt, is_parent = Dtree(fan_out, nwi, true, 1.0, first_distrib, rest_distrib, min_distrib)

    # ---
    if grank() == 1
        println("dtreebench -- $(ngranks()) ranks")
        println("  system clock speed is $(cpu_hz/1e9) GHz")
    end

    # roughly how many work items will each rank will handle?
    each, r = divrem(nwi, ngranks())
    if r > 0
        each = each + 1
    end

    # ---
    if grank() == 1
        println("  ", nwi, " work items, ~", each, " per rank")
    end

    # generate random numbers for work item durations
    dura = Float64[]
    mn = repmat([meani-0.5*stddevi, meani+0.5*stddevi], ceil(Int, ngranks()/2))
    mt = MersenneTwister(7777777)
    for i = 1:ngranks()
        r = randn(mt)*stddevi*0.25+mn[i]
        append!(dura, max.(randn(mt, each)*stddevi+r, zero(Float64)))
    end

    # ---
    if grank() == 1
        println("  initializing...")
    end

    # get the initial allocation
    ilock = SpinLock()
    ni, (ci, li) = initwork(dt)

    # ---
    if grank() == 1
        println("  ...done.")
    end

    # start threads and run
    tfargs = Core.svec(threadfun, dt, Ref(ni), Ref(ci), Ref(li), ilock, runtree(dt), dura)
    ccall(:jl_threading_run, Void, (Any,), tfargs)

    # ---
    if grank() == 1
        println("complete")
    end
    tic()
    finalize(dt)
    wait_done = toq()
    ntputs(1, "wait for done: $wait_done secs")
end

bench(500, 0.5, 0.125, 0.5, 0.5, nthreads())

