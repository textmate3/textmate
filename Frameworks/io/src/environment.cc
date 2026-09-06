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
	// Where the application's own Ruby lives, or NULL_STR when this copy carries none.
	std::string embedded_ruby_directory ()
	{
		CFURLRef bundleURL = CFBundleCopyBundleURL(CFBundleGetMainBundle());
		if(!bundleURL)
			return NULL_STR;

		char buffer[PATH_MAX];
		bool hasPath = CFURLGetFileSystemRepresentation(bundleURL, true, (UInt8*)buffer, sizeof(buffer));
		CFRelease(bundleURL);
		if(!hasPath)
			return NULL_STR;

		std::string const directory = path::join(buffer, "Contents/Resources/Ruby");
		return path::is_executable(path::join(directory, "bin/ruby")) ? directory : NULL_STR;
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

		// The Ruby the application ships, when it does, is what bundle commands
		// run on: it goes first on PATH, so `/usr/bin/env ruby` in a support
		// script finds it, and it is TM_RUBY, so a command's shebang is
		// rewritten to it. The system Ruby is never reached for either. A
		// TM_RUBY the person sets, in the Variables preferences or a
		// .tm_properties, still wins, since those layers come after this one.
		std::string const embeddedRuby = embedded_ruby_directory();
		if(embeddedRuby != NULL_STR)
		{
			path = path::join(embeddedRuby, "bin") + ":" + path;
			res.emplace("TM_RUBY", path::join(embeddedRuby, "bin/ruby"));
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
