#include "python_runtime.h"
#include "path.h"
#include <oak/oak.h>

namespace python_runtime
{
	std::string const kPinnedVersion = "3.14.7";

	answer_t parse (std::string const& output)
	{
		return runtime_resolver::parse(output, "python");
	}

	answer_t resolve (std::string const& resolverPath, std::string const& version)
	{
		return runtime_resolver::resolve(resolverPath, version, "python");
	}

	bool is_system_python (std::string const& executable)
	{
		if(executable == NULL_STR || executable.empty())
			return false;

		// Apple ships Python in more places than it ships Ruby, and the two
		// developer directories move with whichever Xcode is selected, so the
		// prefixes are matched rather than the full paths.
		static std::string const prefixes[] = {
			"/System/Library/Frameworks/Python.framework/",
			"/Applications/Xcode.app/",
			"/Library/Developer/CommandLineTools/",
		};

		std::string const resolved = path::resolve(executable);
		for(std::string const& candidate : { executable, resolved })
		{
			if(candidate == "/usr/bin/python3" || candidate == "/usr/bin/python")
				return true;

			for(std::string const& prefix : prefixes)
			{
				if(candidate.compare(0, prefix.size(), prefix) == 0)
					return true;
			}
		}
		return false;
	}

} /* python_runtime */
