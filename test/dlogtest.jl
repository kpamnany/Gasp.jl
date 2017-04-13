#!/usr/bin/env julia

# run with 5 ranks

using Gasp

dl = Dlog("./dlog"; ranks_per=2, space_per=128)

if grank() == 1
    for i = 1:3
        run(`cat dlog/messages-$i.dlog`)
    end
end

sync()

message(dl, "foobar")

dl = nothing
gc()

if grank() == 1
    for i = 1:3
        run(`cat ./dlog/messages-$i.dlog`)
    end
end
