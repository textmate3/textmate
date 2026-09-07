#include "ruby_runtime.h"
#include "exec.h"
#include "path.h"
#include <text/parse.h>
#include <text/trim.h>
#include <oak/oak.h>

namespace ruby_runtime
{
	std::string const kPinnedVersion = "4.0.6";

	answer_t parse (std::string const& output)
	{
		answer_t res;
		for(auto const& rawLine : text::split(output, "\n"))
		{
			std::string const line = text::trim(rawLine);
			std::string::size_type const space = line.find(' ');
			std::string const word = line.substr(0, space);
			std::string const rest = space == std::string::npos ? "" : text::trim(line.substr(space + 1));

			if(word == "ruby")
			{
				res.ruby = rest;
			}
			else if(word == "installed")
			{
				std::string::size_type const gap = rest.find(' ');
				res.installed = rest.substr(0, gap);
				if(gap != std::string::npos)
					res.ruby = text::trim(rest.substr(gap + 1));
			}
			else if(word == "fallback")
			{
				std::string::size_type const gap = rest.find(' ');
				res.ruby = rest.substr(0, gap);
				res.fallback = gap == std::string::npos ? "" : text::trim(rest.substr(gap + 1));
			}
			else if(word == "error")
			{
				res.error = rest;
			}
		}

		if(res.ruby != NULL_STR && res.ruby.empty())
			res.ruby = NULL_STR;
		if(res.ruby == NULL_STR && res.error == NULL_STR)
			res.error = "The Runtimes bundle's resolver gave no answer.";
		return res;
	}

	answer_t resolve (std::string const& resolverPath, std::string const& version)
	{
		if(!path::is_executable(resolverPath))
		{
			answer_t res;
			res.error = "The Runtimes bundle is not installed, so there is no resolver at " + resolverPath;
			return res;
		}

		std::map<std::string, std::string> const environment = { { "HOME", path::home() }, { "PATH", "/usr/bin:/bin" } };
		io::process_t process = io::spawn({ resolverPath, version }, environment);
		if(!process)
		{
			answer_t res;
			res.error = "The Runtimes bundle's resolver could not be started.";
			return res;
		}

		close(process.in);
		std::string output, errors;
		io::exhaust_fd(process.out, &output);
		io::exhaust_fd(process.err, &errors);
		int status = 0;
		waitpid(process.pid, &status, 0);
		if(!errors.empty())
			fprintf(stderr, "ruby_runtime: %s\n", text::trim(errors).c_str());

		return parse(output);
	}

	bool is_system_ruby (std::string const& executable)
	{
		if(executable == NULL_STR || executable.empty())
			return false;

		std::string const resolved = path::resolve(executable);
		for(std::string const& candidate : { executable, resolved })
		{
			if(candidate == "/usr/bin/ruby" || candidate.compare(0, 40, "/System/Library/Frameworks/Ruby.framework") == 0)
				return true;
		}
		return false;
	}

} /* ruby_runtime */
