target = "gasp/libgasp.$(Libdl.dlext)"

if !isfile(target)
    @static if is_linux() || is_apple()
        repo = LibGit2.clone("https://github.com/kpamnany/gasp", "gasp")
        LibGit2.branch!(repo, "v0.4")
        println("Compiling libgasp...")
        run(`make -C gasp`)
    else
	error("gasp is currently Linux/OS-X only")
    end
end

