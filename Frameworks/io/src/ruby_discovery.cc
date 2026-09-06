#include "ruby_discovery.h"
#include "entries.h"
#include "path.h"
#include <text/parse.h>
#include <text/trim.h>
#include <oak/oak.h>

namespace ruby
{
	static std::vector<size_t> components (std::string const& version)
	{
		std::vector<size_t> res;
		for(auto const& part : text::split(version, "."))
			res.push_back(strtoul(part.c_str(), nullptr, 10));
		return res;
	}

	bool newer_than (std::string const& lhs, std::string const& rhs)
	{
		std::vector<size_t> const left = components(lhs), right = components(rhs);
		for(size_t i = 0; i < std::max(left.size(), right.size()); ++i)
		{
			size_t const l = i < left.size() ? left[i] : 0;
			size_t const r = i < right.size() ? right[i] : 0;
			if(l != r)
				return l > r;
		}
		return false;
	}

	// A version is digits and dots, which is what a manager names its directory
	// after, sometimes behind a ruby- prefix.
	static std::string version_from_name (std::string const& name)
	{
		std::string version = name;
		if(version.compare(0, 5, "ruby-") == 0)
			version.erase(0, 5);
		else if(version.compare(0, 5, "ruby@") == 0)
			version.erase(0, 5);
		return version.empty() || version.find_first_not_of("0123456789.") != std::string::npos ? NULL_STR : version;
	}

	// The directories under a root whose name is a version and which hold a bin/ruby.
	static void add_installs (std::vector<install_t>& res, std::string const& root, std::string const& source)
	{
		for(auto const& entry : path::entries(root))
		{
			std::string const directory = path::join(root, entry->d_name);
			std::string const version   = version_from_name(entry->d_name);
			if(version != NULL_STR && path::is_executable(path::join(directory, "bin/ruby")))
				res.push_back({ version, directory, source });
		}
	}

	std::vector<install_t> installs (std::string const& home, std::vector<std::string> const& systemRoots)
	{
		std::vector<install_t> res;
		add_installs(res, path::join(home, ".rubies"),                    "chruby");
		add_installs(res, path::join(home, ".rbenv/versions"),            "rbenv");
		add_installs(res, path::join(home, ".asdf/installs/ruby"),        "asdf");
		add_installs(res, path::join(home, ".local/share/mise/installs/ruby"), "mise");
		for(auto const& root : systemRoots)
		{
			if(root == "/opt/homebrew/opt")
			{
				// Homebrew keeps one ruby and any number of ruby@x.y, each a
				// directory of its own, and the version is in the executable's
				// answer rather than the name, so the name is the best that can
				// be had without running it: ruby@3.4 is 3.4.
				for(auto const& entry : path::entries(root))
				{
					std::string const name = entry->d_name;
					if(name != "ruby" && name.compare(0, 5, "ruby@") != 0)
						continue;
					std::string const directory = path::join(root, name);
					if(!path::is_executable(path::join(directory, "bin/ruby")))
						continue;
					res.push_back({ name == "ruby" ? std::string("homebrew") : version_from_name(name), path::resolve(directory), "homebrew" });
				}
			}
			else
			{
				add_installs(res, root, "chruby");
			}
		}

		std::stable_sort(res.begin(), res.end(), [](install_t const& lhs, install_t const& rhs){ return newer_than(lhs.version, rhs.version); });
		return res;
	}

	static std::string version_in_file (std::string const& file, bool toolVersions)
	{
		std::string const contents = path::content(file);
		if(contents == NULL_STR)
			return NULL_STR;

		for(auto const& line : text::split(contents, "\n"))
		{
			std::string const trimmed = text::trim(line);
			if(trimmed.empty() || trimmed[0] == '#')
				continue;
			if(!toolVersions)
				return version_from_name(trimmed);
			std::vector<std::string> const words = text::split(trimmed, " ");
			if(words.size() >= 2 && words[0] == "ruby")
				return version_from_name(words[1]);
		}
		return NULL_STR;
	}

	std::string requested_version (std::string const& directory)
	{
		for(std::string current = directory; current != NULL_STR && !current.empty(); current = current == "/" ? NULL_STR : path::parent(current))
		{
			std::string version = version_in_file(path::join(current, ".ruby-version"), false);
			if(version == NULL_STR)
				version = version_in_file(path::join(current, ".tool-versions"), true);
			if(version != NULL_STR)
				return version;
		}
		return NULL_STR;
	}

	install_t install_for_version (std::string const& version, std::vector<install_t> const& installs)
	{
		for(auto const& install : installs)
		{
			if(install.version == version || install.version.compare(0, version.size() + 1, version + ".") == 0)
				return install;
		}
		return { version, NULL_STR, NULL_STR };
	}

	install_t install_for_directory (std::string const& directory, std::vector<install_t> const& installs)
	{
		std::string const requested = requested_version(directory);
		if(requested != NULL_STR)
			return install_for_version(requested, installs);

		for(auto const& install : installs)
		{
			if(!newer_than("4", install.version))
				return install;
		}
		return { NULL_STR, NULL_STR, NULL_STR };
	}

} /* ruby */
