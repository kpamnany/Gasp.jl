type Dlog
    fd::Cint
    started_at::UInt64
    start_ofs::Csize_t
    end_ofs::Csize_t
    cur_ofs::Csize_t
end

const RanksPerLog = 16384
const SpacePerRank = 200*1024

function Dlog(destpath::String;
              ranks_per::Int = RanksPerLog,
              space_per::Int = SpacePerRank)
    @assert space_per > 100

    mkpath(destpath)

    # which log and this rank's (0 based) index for that log
    gidx, fidx = divrem(grank(), ranks_per)
    if fidx > 0
        gidx += 1
    end
    fidx -= 1
    if fidx == -1
        fidx = ranks_per - 1
    end

    # how many logs and how many ranks in the only or last log
    ngroups, nlast = divrem(ngranks(), ranks_per)
    if nlast > 0
        ngroups += 1
    end

    # how many ranks in this rank's group
    ningroup = min(ngranks(), ranks_per)
    if gidx == ngroups && nlast > 0
        ningroup = nlast
    end

    # the first rank in the group `truncate`s the log file
    fullname = joinpath(destpath, "messages-$gidx.dlog")
    if fidx == 0
        cfd = ccall(:creat, Cint, (Ptr{UInt8}, Cint), fullname, 0o644)
        systemerror("creat()", cfd == -1)
        ccall(:close, Cint, (Cint,), cfd)
        r = ccall(:truncate, Cint, (Ptr{UInt8}, Csize_t),
                  fullname, ningroup * space_per)
        systemerror("truncate()", r == -1)
    end

    # wait till the log file is created
    sync()

    # open the log file and set up this rank's offsets into it
    fd = ccall(:open, Cint, (Ptr{UInt8}, Cint, Cint), fullname,
               Base.Filesystem.JL_O_WRONLY, 0)
    systemerror("Dlog.open()", fd == -1)

    start_ofs = fidx * space_per
    end_ofs = start_ofs + space_per

    dl = Dlog(fd, time_ns(), start_ofs, end_ofs, start_ofs)
    message(dl, "[$(grank())]")

    finalizer(dl, (x -> ccall(:close, Cint, (Cint,), dl.fd)))
    return dl
end

function message(dl::Dlog, msg...)
    msg_sec = (time_ns() - dl.started_at) / 1e9
    s = @sprintf("%.3f %s\n", msg_sec, string(msg...))
    sl = length(s)
    if dl.cur_ofs + sl >= dl.end_ofs
        dl.cur_ofs = dl.start_ofs
        message(dl, "wrap")
    end
    gc_state = ccall(:jl_gc_safe_enter, Int8, ())
    wrb = ccall(:pwrite, Cint, (Cint, Ptr{UInt8}, Csize_t, Csize_t),
                dl.fd, s, sl, dl.cur_ofs)
    ccall(:jl_gc_safe_leave, Void, (Int8,), gc_state)
    dl.cur_ofs += sl
    return
end

