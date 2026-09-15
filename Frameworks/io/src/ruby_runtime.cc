#include "ruby_runtime.h"
#include "runtime_resolver.h"
#include "exec.h"
#include "path.h"
#include <text/trim.h>
#include <oak/oak.h>

namespace ruby_runtime
{
	std::string const kPinnedVersion = "4.0.6";

	// Reading the answer is the same work for every language, so it lives in
	// runtime_resolver. What stays here is the word this resolver answers with
	// and the field callers have always read it from.
	static answer_t as_ruby_answer (runtime_resolver::answer_t const& answer)
	{
		return { answer.path, answer.installed, answer.fallback, answer.error };
	}

	answer_t parse (std::string const& output)
	{
		return as_ruby_answer(runtime_resolver::parse(output, "ruby"));
	}

	answer_t resolve (std::string const& resolverPath, std::string const& version)
	{
		return as_ruby_answer(runtime_resolver::resolve(resolverPath, version, "ruby"));
	}

	bool is_system_ruby (std::string const& executable)
	{
		if(executable == NULL_STR || executable.empty())
			return false;

		static std::string const systemFramework = "/System/Library/Frameworks/Ruby.framework/";
		std::string const resolved = path::resolve(executable);
		for(std::string const& candidate : { executable, resolved })
		{
			if(candidate == "/usr/bin/ruby" || candidate.compare(0, systemFramework.size(), systemFramework) == 0)
				return true;
		}
		return false;
	}

	std::string const kMinimumVersion = "4.0";

	std::string version_of (std::string const& executable)
	{
		if(executable == NULL_STR || access(executable.c_str(), X_OK) != 0)
			return NULL_STR;

		std::string const output = io::exec(executable, "-e", "print RUBY_VERSION", NULL);
		if(output == NULL_STR)
			return NULL_STR;

		std::string const version = text::trim(output);
		return version.empty() ? NULL_STR : version;
	}

	// The major and minor numbers at the front of a version, or false when there is no number there.
	static bool leading_numbers (std::string const& version, unsigned* major, unsigned* minor)
	{
		if(version == NULL_STR)
			return false;
		*major = *minor = 0;
		return sscanf(version.c_str(), "%u.%u", major, minor) >= 1;
	}

	bool is_below_minimum (std::string const& version)
	{
		unsigned major, minor, minimumMajor, minimumMinor;
		if(!leading_numbers(version, &major, &minor) || !leading_numbers(kMinimumVersion, &minimumMajor, &minimumMinor))
			return false;
		return major < minimumMajor || (major == minimumMajor && minor < minimumMinor);
	}

} /* ruby_runtime */
