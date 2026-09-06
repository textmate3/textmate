#include "rv.h"
#include "exec.h"
#include "path.h"
#include <text/trim.h>
#include <oak/oak.h>

namespace rv
{
	std::string const kApplicationRubySeries = "4.0";

	// The application's own rv, beside its executable.
	static std::string bundled_executable ()
	{
		CFURLRef bundleURL = CFBundleCopyBundleURL(CFBundleGetMainBundle());
		if(!bundleURL)
			return NULL_STR;

		char buffer[PATH_MAX];
		bool hasPath = CFURLGetFileSystemRepresentation(bundleURL, true, (UInt8*)buffer, sizeof(buffer));
		CFRelease(bundleURL);
		return hasPath ? path::join(buffer, "Contents/MacOS/rv") : NULL_STR;
	}

	std::string executable ()
	{
		std::string const home = path::home();
		return executable({
			"/opt/homebrew/bin/rv",
			path::join(home, ".local/bin/rv"),
			path::join(home, ".cargo/bin/rv"),
			"/usr/local/bin/rv",
			bundled_executable(),
		});
	}

	std::string executable (std::vector<std::string> const& candidates)
	{
		for(auto const& candidate : candidates)
		{
			if(candidate != NULL_STR && path::is_executable(candidate))
				return candidate;
		}
		return NULL_STR;
	}

	// rv answers on standard output and complains on standard error, and
	// its exit status says which.
	static std::string run (std::vector<std::string> args, std::string const& directory, bool* succeeded)
	{
		std::string const rv = executable();
		*succeeded = false;
		if(rv == NULL_STR)
			return NULL_STR;

		args.insert(args.begin(), rv);
		// rv reads a project's pin from the working directory, and spawn
		// has no working directory of its own, so a shell steps into it first.
		if(directory != NULL_STR)
			args.insert(args.begin(), { "/bin/sh", "-c", "cd \"$0\" && exec \"$@\"", directory });

		std::map<std::string, std::string> const environment = { { "HOME", path::home() }, { "PATH", "/usr/bin:/bin" }, { "RV_COLOR", "never" } };
		io::process_t process = io::spawn(args, environment);
		if(!process)
			return NULL_STR;

		close(process.in);
		std::string output, errors;
		io::exhaust_fd(process.out, &output);
		io::exhaust_fd(process.err, &errors);

		int status = 0;
		waitpid(process.pid, &status, 0);
		*succeeded = WIFEXITED(status) && WEXITSTATUS(status) == 0;
		if(!*succeeded)
			fprintf(stderr, "rv: %s\n", text::trim(errors).c_str());
		return text::trim(output);
	}

	std::string find (std::string const& version, std::string const& directory)
	{
		bool succeeded = false;
		std::string const ruby = run({ "ruby", "find", version }, directory, &succeeded);
		if(!succeeded || ruby.empty() || ruby == NULL_STR)
			return NULL_STR;
		// rv gives the executable; the caller wants the directory it belongs to.
		return path::parent(path::parent(ruby));
	}

	bool install (std::string const& version)
	{
		bool succeeded = false;
		run({ "ruby", "install", version }, NULL_STR, &succeeded);
		return succeeded;
	}

	std::string application_ruby ()
	{
		std::string ruby = find(kApplicationRubySeries, NULL_STR);
		if(ruby == NULL_STR && install(kApplicationRubySeries))
			ruby = find(kApplicationRubySeries, NULL_STR);
		return ruby;
	}

} /* rv */
