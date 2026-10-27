#ifndef IO_PROJECT_RUBY_H_7C3E51A9
#define IO_PROJECT_RUBY_H_7C3E51A9

// The Ruby a project asks for, for running the person's own code.
//
// Bundle commands run on the Ruby the application pins, TM_RUBY. The person's
// own code, run with Command-R, runs on the Ruby their project pins, which the
// Runtimes Ruby bundle's project_ruby resolves through rv: a .ruby-version or
// .tool-versions in the project directory or above it, the home directory's
// included, against every Ruby on the machine. The answer goes into the
// command environment as TM_PROJECT_RUBY, and the Ruby bundle's run commands
// prefer it. A pin that names a version not installed is reported, not
// installed: an install on Command-R would be a surprise.
//
// The resolver answers on standard output:
//
//   ruby <directory>    the project's Ruby, the directory whose bin/ruby it is
//   missing <version>   the pin names a version that is not installed
//   none                nothing is pinned, anywhere rv looks
//   error <message>     rv could not be asked
namespace project_ruby
{
	struct answer_t
	{
		std::string ruby    = NULL_STR; // The directory, when the pin resolves.
		std::string missing = NULL_STR; // The pinned version, when it is not installed.
		std::string error   = NULL_STR;
		bool none = false;
	};

	answer_t parse (std::string const& output);

	// Runs the resolver for the directory and reads its answer.
	answer_t resolve (std::string const& resolverPath, std::string const& directory);

	// The answer for a directory, asked of the resolver once and kept until
	// something it depends on changes: a pin file from the directory up to
	// the root or in the home directory, or the directory of any Ruby
	// manager, which is how an install the person makes is noticed.
	answer_t cached_resolve (std::string const& resolverPath, std::string const& directory);

	// What cached_resolve watches, as one string that changes when any of it does. Exposed for the tests.
	std::string fingerprint (std::string const& directory);

} /* project_ruby */

#endif /* end of include guard: IO_PROJECT_RUBY_H_7C3E51A9 */
