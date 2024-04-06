require("lua.compiler")
require("lua.util")

function CheckSystemFamily()
	Check("Determining operating system family")
	local path = os.getenv("PATH")

	if not path then
		Error()
	end

	-- Try find part of a absolute drive path like 'C:\Windows\System32'
	dos = string.match(path, ":\\")

	if dos then
		local output = UniqueName()
		os.execute("ver > " .. output)
		handle = io.open(output)
		if handle then
		local output = handle:read("*a")
			handle:close()
			if string.find( string.lower(output), "windows" ) then
				r = "Windows"
			else
				r = "Dos"
			end
		end
		os.remove(output)
	else -- Assume Posix compliant
		r = "Unix"
	end

	Pass(r)
	return r
end

function CheckEnvVar(var)
	Check("Checking '" .. var .. "' enviroment variable")
	v = os.getenv(var)

	if not v then
		Pass("None")
	else
		Pass("'" .. v .. "'")
	end

	return v
end

function CheckCompiler(family, makefile)
	Compiler = {}
	local tmpName = UniqueName()

	if not CreateCTestFile(tmpName .. ".c") then Error() end

	local cc = CheckEnvVar("CC")
	if not cc then
		Check("Guessing compiler")

		if makefile == "cc" then Fail("None") -- Nothing was specified
		elseif makefile == "watcom" then
			Pass("Open Watcom")
			CheckWatcomCompiler(tmpName)
		else
			Pass("GNU Compiler Collection or compatible")
			if makefile == "clang" then
				cc = "clang"
			else
				cc = "gcc"
				CheckGccCompiler(cc, tmpName)
			end
		end
	else
		return CheckCustomCompiler(cc, tmpName)
	end

	os.remove(tmpName .. ".c")

	return cc, cflags
end

function CheckRemoveFileCmd(family, filename)
	local exec = family == "Unix" and "rm" or "DEL"
	Check("Checking '" .. exec .. "' works")

	local path = SanitizePath(family, filename .. "/2.txt")

	file = io.open(path, "a")

	if not file then Error() end

	io.close(file)

	local e = exec .. " " .. path
	RunCommand(e)

	file = io.open(path)
	if file then
		io.close(file)
		Fail("No")
	end

	Pass("Yes")
	return exec
end

function CheckRemoveDirCmd(family, filename)
	local exec = family == "Unix" and "rm -R" or "DELTREE /Y"
	Check("Checking '" .. exec .."' works")

	-- Ensure there's a file in the directory
	local path = SanitizePath(family, filename .. "/1.txt")
	local file = io.open(path)

	if not file then Error() end

	-- Delete the folder
	local e = exec .. " " .. filename
	RunCommand(e)

	io.close(file)

	-- The file shouldn't open since its folder has been deleted
	local file = io.open(path)
	if file then
		io.close(file)
		Fail("No")
	end

	Pass("Yes")
	return exec
end

function CheckCreateDirCmd(family, filename)
	local exec = family == "Unix" and "mkdir" or "MD"
	Check("Checking '" .. exec .. "' works")

	local e = exec .. " " .. filename
	RunCommand(e)

	file = io.open(filename .. "/1.txt", "a")

	if file then
		io.close(file)
		Pass("Yes")
	else Fail("No") end

	return exec
end

function CheckDirContains(family, dir, files)
	Check("Checking '" .. dir .. "' contains required files")

	for _, file in ipairs(files) do
		local path = SanitizePath(family, dir .. "/" .. file)

		if not FileExists(path) then Fail("Missing '" .. file .. "'") end
	end

	Pass("Yes")
	return true
end

function CheckMakefileRequestValid(makefile)
	-- TODO: Add Borland C and other antiques?
	local options = {
		"cc",
		"clang",
		"djgpp",
		"gcc",
		"mingw",
		"watcom",
	}

	for _, option in ipairs(options) do
		if makefile == option then return makefile end
	end

	if os.getenv('CC') then return "cc" end

	print(
		"Specify a makefile to generate, options are:\n" ..
		"\tcc\t- Handle everything yourself with CC,CFLAGS,LD enviroment variables\n" ..
		"\tclang\t- A GCC compatible alternative compiler\n" ..
		"\tdjggp\t- A port of GCC for 80386+ DOS systems\n" ..
		"\tgcc\t- GNU Compiler Collection intended for Posix systems\n" ..
		"\tmingw\t- A port of GCC for Win32 based systems\n" ..
		"\twatcom\t- A C/C++ toolchain that can build 16-bit DOS programs\n"
	)

	os.exit(1)
end
