#ifndef IO_RV_H_7D1A9C3E
#define IO_RV_H_7D1A9C3E

// rv, Spinel's Ruby manager, is how the application gets a Ruby: it knows
// every Ruby a person installed through rv, chruby or ruby-install, resolves
// a version or a series to the newest match, honors a project's
// .ruby-version, and installs a prebuilt Ruby in seconds. The application
// carries its own copy of rv, so none of this needs Homebrew or a shell, and
// prefers the person's own rv when they have one, so what it installs shows
// up in theirs.
namespace rv
{
	// The rv to run: the person's, from the places rv installs to, else the
	// application's own, else NULL_STR. The candidates are a parameter for
	// the tests.
	std::string executable ();
	std::string executable (std::vector<std::string> const& candidates);

	// The Ruby directory, the one whose bin/ruby it is, for a version or a
	// series such as 4.0, resolved by rv in the given directory so a project's
	// pin counts when no version is given. NULL_STR when rv has none.
	std::string find (std::string const& version, std::string const& directory);

	// Installs the newest Ruby matching the version or series, prebuilt, into
	// rv's own directory. True when rv reports success.
	bool install (std::string const& version);

	// The series the application's bundle commands run on.
	extern std::string const kApplicationRubySeries;

	// The Ruby the application's bundle commands run on: the newest installed
	// of the series, installing one when there is none. NULL_STR when rv is
	// missing or the install failed, which the caller reports.
	std::string application_ruby ();

} /* rv */

#endif /* end of include guard: IO_RV_H_7D1A9C3E */
