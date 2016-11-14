target = "gasp/libgasp.$(Libdl.dlext)"
vers = "0.0.1"

if !isfile(target)
    @static if is_linux()
        LibGit2.clone("https://github.com/kpamnany/gasp", "gasp")
        println("Compiling libgasp...")
        run(`make -C gasp`)
    else
	error("gasp is Linux-only right now")
    end
end

