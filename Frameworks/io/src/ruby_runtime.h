#ifndef IO_RUBY_RUNTIME_H_5E2A8D40
#define IO_RUBY_RUNTIME_H_5E2A8D40

// The Ruby bundle commands run on. The application pins one version and
// asks the Runtimes bundle's resolver for it; the resolver, a shell script
// around rv, finds it wherever rv looks or installs it, and answers on
// standard output one word per line then its arguments:
//
//   ruby <directory>                 the Ruby to use, the directory whose bin/ruby it is
//   installed <version> <directory>  an install happened first
//   fallback <directory> <reason>    not the version asked for
//   error <message>                  nothing to run on
//
// The system Ruby is never used. The resolver cannot answer with it, since
// rv does not know it, and the application refuses it wherever a person
// names it, which is the one rule here the bundle cannot loosen.
namespace ruby_runtime
{
	// The version bundle support is tested on. Moved by an application release.
	extern std::string const kPinnedVersion;

	struct answer_t
	{
		std::string ruby      = NULL_STR; // The directory, or NULL_STR with an error.
		std::string installed = NULL_STR; // The version installed on the way, or NULL_STR.
		std::string fallback  = NULL_STR; // Why the Ruby is not the pinned one, or NULL_STR.
		std::string error     = NULL_STR;
	};

	answer_t parse (std::string const& output);

	// Runs the resolver for the version and reads its answer. The script's own
	// standard error goes to ours.
	answer_t resolve (std::string const& resolverPath, std::string const& version);

	// /usr/bin/ruby, anything under the system's Ruby framework, and anything
	// that resolves there through a link.
	bool is_system_ruby (std::string const& executable);

} /* ruby_runtime */

#endif /* end of include guard: IO_RUBY_RUNTIME_H_5E2A8D40 */
