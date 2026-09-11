#include "environment.h"
#include "path.h"
#include <cf/cf.h>
#include <regexp/format_string.h>
#include <regexp/glob.h>
#include <text/parse.h>
#include <oak/oak.h>
#include <crt_externs.h>

namespace oak
{
	static std::string& application_ruby ()
	{
		static std::string* directory = new std::string(NULL_STR);
		return *directory;
	}

	std::string const& application_ruby_directory ()
	{
		return application_ruby();
	}

	void set_application_ruby_directory (std::string const& directory)
	{
		application_ruby() = path::is_executable(path::join(directory, "bin/ruby")) ? directory : NULL_STR;
	}

	static std::string& application_python_interpreter ()
	{
		static std::string* interpreter = new std::string(NULL_STR);
		return *interpreter;
	}

	std::string const& application_python ()
	{
		return application_python_interpreter();
	}

	void set_application_python (std::string const& interpreter)
	{
		application_python_interpreter() = path::is_executable(interpreter) ? interpreter : NULL_STR;
	}

	std::map<std::string, std::string> setup_basic_environment ()
	{
		std::string whitelistStr = "Apple_*:COMMAND_MODE:DIALOG*:SHELL:SHLVL:SSH_AUTH_SOCK:__CF_USER_TEXT_ENCODING";
		if(CFStringRef userWhitelist = (CFStringRef)CFPreferencesCopyAppValue(CFSTR("environmentWhitelist"), kCFPreferencesCurrentApplication))
		{
			if(CFGetTypeID(userWhitelist) == CFStringGetTypeID())
				whitelistStr = format_string::expand(cf::to_s(userWhitelist), std::map<std::string, std::string>{ { "default", whitelistStr } });
			CFRelease(userWhitelist);
		}

		std::set<std::string> whitelistSet;
		std::vector<path::glob_t> whitelistGlobs;
		for(auto str : text::split(whitelistStr, ":"))
		{
			if(str.find("*") != std::string::npos)
					whitelistGlobs.push_back(str);
			else	whitelistSet.insert(str);
		}

		std::map<std::string, std::string> res;

		char*** envPtr = _NSGetEnviron();
		for(char** pair = *envPtr; pair && *pair; ++pair)
		{
			char* value = strchr(*pair, '=');
			if(value && *value == '=')
			{
				std::string const key = std::string(*pair, value);
				if(whitelistSet.find(key) != whitelistSet.end() || std::any_of(whitelistGlobs.begin(), whitelistGlobs.end(), [&key](path::glob_t const& glob){ return glob.does_match(key); }))
					res[key] = value + 1;
			}
		}

		passwd* entry = path::passwd_entry();

		int mib[2] = { CTL_USER, USER_CS_PATH };
		size_t len = 0;
		sysctl(mib, 2, nullptr, &len, nullptr, 0);
		std::string path(len, '\0');
		sysctl(mib, 2, &path[0], &len, nullptr, 0);
		path.pop_back();

		// The Ruby bundle commands run on goes first on PATH, so
		// `/usr/bin/env ruby` in a support script finds it, and it is TM_RUBY,
		// so a command's shebang is rewritten to it. The system Ruby is never
		// reached for either. A TM_RUBY the person sets, in the Variables
		// preferences or a .tm_properties, still wins, since those layers
		// come after this one, which is why the application's own answer is
		// kept a second time as TM_APPLICATION_RUBY: it is what a command runs
		// on when the person's TM_RUBY is refused.
		std::string const applicationRuby = application_ruby_directory();
		if(applicationRuby != NULL_STR)
		{
			path = path::join(applicationRuby, "bin") + ":" + path;
			res.emplace("TM_RUBY",             path::join(applicationRuby, "bin/ruby"));
			res.emplace("TM_APPLICATION_RUBY", path::join(applicationRuby, "bin/ruby"));
		}

		// The same for Python, and for the same reasons. The interpreter's own
		// directory goes on PATH after Ruby's, since uv answers with the
		// interpreter rather than a directory to join a bin onto.
		std::string const applicationPython = application_python();
		if(applicationPython != NULL_STR)
		{
			path = path::parent(applicationPython) + ":" + path;
			res.emplace("TM_PYTHON",             applicationPython);
			res.emplace("TM_APPLICATION_PYTHON", applicationPython);
		}

		res.emplace("HOME",    entry->pw_dir);
		res.emplace("PATH",    path);
		res.emplace("TMPDIR",  path::temp());
		res.emplace("LOGNAME", entry->pw_name);
		res.emplace("USER",    entry->pw_name);

		res.emplace("TM_APP_IDENTIFIER", cf::to_s(CFBundleGetIdentifier(CFBundleGetMainBundle())));
		res.emplace("TM_FULLNAME",       entry->pw_gecos ?: "John Doe");
		res.emplace("TM_PID",            std::to_string(getpid()));

		return res;
	}

	std::map<std::string, std::string>& rw_environment ()
	{
		static std::map<std::string, std::string>* environment = new std::map<std::string, std::string>(setup_basic_environment());
		return *environment;
	}

	std::map<std::string, std::string> const& basic_environment ()
	{
		return rw_environment();
	}

	void set_basic_environment (std::map<std::string, std::string> const& newEnvironment)
	{
		rw_environment() = newEnvironment;
	}

} /* io */
