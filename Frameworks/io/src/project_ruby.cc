#include "project_ruby.h"
#include "exec.h"
#include "path.h"
#include <text/parse.h>
#include <text/trim.h>
#include <oak/oak.h>
#include <sys/stat.h>

namespace project_ruby
{
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
				res.ruby = rest;
			else if(word == "missing")
				res.missing = rest;
			else if(word == "none")
				res.none = true;
			else if(word == "error")
				res.error = rest;
		}

		if(res.ruby != NULL_STR && res.ruby.empty())
			res.ruby = NULL_STR;
		if(res.ruby == NULL_STR && res.missing == NULL_STR && !res.none && res.error == NULL_STR)
			res.error = "The Runtimes Ruby bundle's project_ruby gave no answer.";
		return res;
	}

	answer_t resolve (std::string const& resolverPath, std::string const& directory)
	{
		if(!path::is_executable(resolverPath))
		{
			answer_t res;
			res.error = "The Runtimes Ruby bundle is not installed, so there is no resolver at " + resolverPath;
			return res;
		}

		std::map<std::string, std::string> const environment = { { "HOME", path::home() }, { "PATH", "/usr/bin:/bin" } };
		io::process_t process = io::spawn({ resolverPath, directory }, environment);
		if(!process)
		{
			answer_t res;
			res.error = "The Runtimes Ruby bundle's project_ruby could not be started.";
			return res;
		}

		close(process.in);
		std::string output, errors;
		io::exhaust_fd(process.out, &output);
		io::exhaust_fd(process.err, &errors);
		int status = 0;
		waitpid(process.pid, &status, 0);
		if(!errors.empty())
			fprintf(stderr, "project_ruby: %s\n", text::trim(errors).c_str());

		return parse(output);
	}

	// The modification time of a path, or a dash when there is none, so a file that appears or goes changes the fingerprint too.
	static std::string stamp (std::string const& path)
	{
		struct stat buf;
		if(stat(path.c_str(), &buf) != 0)
			return "-";
		return std::to_string(buf.st_mtimespec.tv_sec) + "." + std::to_string(buf.st_mtimespec.tv_nsec);
	}

	std::string fingerprint (std::string const& directory)
	{
		std::string res;

		// The pin files rv reads: in the directory and every one above it, then the home directory's as the last word.
		std::string const home = path::home();
		for(std::string cwd = directory; true; cwd = path::parent(cwd))
		{
			res += stamp(path::join(cwd, ".ruby-version")) + ":" + stamp(path::join(cwd, ".tool-versions")) + ";";
			if(cwd == "/" || cwd == path::parent(cwd))
				break;
		}
		res += stamp(path::join(home, ".ruby-version")) + ":" + stamp(path::join(home, ".tool-versions")) + ";";

		// The directories the resolver hands rv, whose modification time moves when a Ruby is installed or removed.
		for(std::string const& rubies : { path::join(home, ".local/share/rv/rubies"), path::join(home, ".rubies"), std::string("/opt/rubies"), path::join(home, ".rbenv/versions"), path::join(home, ".asdf/installs/ruby"), path::join(home, ".local/share/mise/installs/ruby") })
			res += stamp(rubies) + ";";

		return res;
	}

	answer_t cached_resolve (std::string const& resolverPath, std::string const& directory)
	{
		struct entry_t
		{
			std::string fingerprint;
			answer_t answer;
		};

		static std::map<std::string, entry_t> cache;
		static std::mutex mutex;

		std::string const current = fingerprint(directory);

		std::lock_guard<std::mutex> lock(mutex);
		auto it = cache.find(directory);
		if(it != cache.end() && it->second.fingerprint == current)
			return it->second.answer;

		answer_t const answer = resolve(resolverPath, directory);
		cache[directory] = { current, answer };
		return answer;
	}

} /* project_ruby */
