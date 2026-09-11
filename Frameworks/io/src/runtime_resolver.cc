#include "runtime_resolver.h"
#include "exec.h"
#include "path.h"
#include <text/parse.h>
#include <text/trim.h>
#include <oak/oak.h>

namespace runtime_resolver
{
	answer_t parse (std::string const& output, std::string const& keyword)
	{
		answer_t res;
		for(auto const& rawLine : text::split(output, "\n"))
		{
			std::string const line = text::trim(rawLine);
			std::string::size_type const space = line.find(' ');
			std::string const word = line.substr(0, space);
			std::string const rest = space == std::string::npos ? "" : text::trim(line.substr(space + 1));

			if(word == keyword)
			{
				res.path = rest;
			}
			else if(word == "installed")
			{
				std::string::size_type const gap = rest.find(' ');
				res.installed = rest.substr(0, gap);
				if(gap != std::string::npos)
					res.path = text::trim(rest.substr(gap + 1));
			}
			else if(word == "fallback")
			{
				std::string::size_type const gap = rest.find(' ');
				res.path = rest.substr(0, gap);
				res.fallback = gap == std::string::npos ? "" : text::trim(rest.substr(gap + 1));
			}
			else if(word == "error")
			{
				res.error = rest;
			}
		}

		if(res.path != NULL_STR && res.path.empty())
			res.path = NULL_STR;
		if(res.path == NULL_STR && res.error == NULL_STR)
			res.error = "The Runtimes bundle's resolver gave no answer.";
		return res;
	}

	answer_t resolve (std::string const& resolverPath, std::string const& version, std::string const& keyword)
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
			fprintf(stderr, "%s_runtime: %s\n", keyword.c_str(), text::trim(errors).c_str());

		return parse(output, keyword);
	}

} /* runtime_resolver */
