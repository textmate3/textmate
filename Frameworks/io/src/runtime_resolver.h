#ifndef IO_RUNTIME_RESOLVER_H_1B4F7C22
#define IO_RUNTIME_RESOLVER_H_1B4F7C22

// Reading a Runtimes bundle resolver's answer, whichever language it is for.
//
// A resolver is a shell script the bundle carries, since it runs before the
// runtime it finds exists. It answers on standard output, one word per line
// then its arguments, where <keyword> is the language: ruby, python.
//
//   <keyword> <path>                 the runtime to use
//   installed <version> <path>       an install happened first
//   fallback <path> <reason>         not the version asked for
//   error <message>                  nothing to run on
//
// What <path> means is the resolver's business rather than this code's. The
// Ruby resolver answers a directory, because rv points into a Ruby whose
// layout the application then relies on. The Python resolver answers the
// interpreter itself, because uv does.
namespace runtime_resolver
{
	struct answer_t
	{
		std::string path      = NULL_STR; // The runtime, or NULL_STR with an error.
		std::string installed = NULL_STR; // The version installed on the way, or NULL_STR.
		std::string fallback  = NULL_STR; // Why the answer is not the version asked for, or NULL_STR.
		std::string error     = NULL_STR;
	};

	answer_t parse (std::string const& output, std::string const& keyword);

	// Runs the resolver for the version and reads its answer. The script's own
	// standard error goes to ours, prefixed with the keyword.
	answer_t resolve (std::string const& resolverPath, std::string const& version, std::string const& keyword);

} /* runtime_resolver */

#endif /* end of include guard: IO_RUNTIME_RESOLVER_H_1B4F7C22 */
