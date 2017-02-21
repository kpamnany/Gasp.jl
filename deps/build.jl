target = "gasp/libgasp.$(Libdl.dlext)"

if !isfile(target)
    @static if is_linux()
        repo = LibGit2.clone("https://github.com/kpamnany/gasp", "gasp")
        LibGit2.branch!(repo, "v0.3")
        println("Compiling libgasp...")
        run(`make -C gasp`)
    else
	error("gasp is Linux-only right now")
    end
end

