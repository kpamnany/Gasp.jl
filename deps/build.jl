target = "gasp/libgasp.$(Libdl.dlext)"
vers = "0.0.1"

if !isfile(target)
    @static if is_linux()
        repo = LibGit2.clone("https://github.com/kpamnany/gasp", "gasp")
        LibGit2.branch!(repo, "v0.2")
        println("Compiling libgasp...")
        run(`make -C gasp`)
    else
	error("gasp is Linux-only right now")
    end
end

