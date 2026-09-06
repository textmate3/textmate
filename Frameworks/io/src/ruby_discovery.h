#ifndef IO_RUBY_DISCOVERY_H_2B7C4E11
#define IO_RUBY_DISCOVERY_H_2B7C4E11

// The Rubies a person has installed, and which one a project asks for. For
// running the person's own code: Cmd-R and the language tooling. Bundle
// commands run on the application's Ruby, which this knows nothing about.
//
// Installs are found where the version managers put them, by path, with no
// shell involved: chruby and ruby-install, rbenv, asdf, mise and Homebrew.
// A project asks for a version through a .ruby-version or a .tool-versions
// in the directory or one above it.
namespace ruby
{
	struct install_t
	{
		std::string version; // 4.0.6
		std::string path;    // The directory whose bin/ruby it is.
		std::string source;  // chruby, rbenv, asdf, mise, homebrew
	};

	// Every install under the home and the system roots, newest version first.
	std::vector<install_t> installs (std::string const& home, std::vector<std::string> const& systemRoots = { "/opt/rubies", "/opt/homebrew/opt" });

	// What a .ruby-version or a .tool-versions asks for, walking up from the
	// directory, with any ruby- prefix dropped. NULL_STR when nothing asks.
	std::string requested_version (std::string const& directory);

	// The install a request names: the one whose version equals it, or begins
	// with it and a dot, so 4.0 names the newest 4.0.x. NULL_STR path when none.
	install_t install_for_version (std::string const& version, std::vector<install_t> const& installs);

	// The install for a project: the requested one, or with no request the
	// newest that is 4 or later. NULL_STR path when nothing qualifies, which
	// the caller reports rather than falling back to the system Ruby.
	install_t install_for_directory (std::string const& directory, std::vector<install_t> const& installs);

	// Newer first, numerically by component.
	bool newer_than (std::string const& lhs, std::string const& rhs);

} /* ruby */

#endif /* end of include guard: IO_RUBY_DISCOVERY_H_2B7C4E11 */
