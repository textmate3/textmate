#ifndef IO_PYTHON_RUNTIME_H_6D3A91E5
#define IO_PYTHON_RUNTIME_H_6D3A91E5

#include "runtime_resolver.h"

// The Python bundle commands run on. The same arrangement as ruby_runtime:
// the application names a version, the Runtimes bundle's resolver finds it
// through uv or installs it, and the answer goes into the environment.
//
// Two things differ from Ruby, both because Python's situation differs.
//
// The answer is the interpreter rather than a directory, since uv answers
// that way and a Python's layout varies more than a Ruby's.
//
// The system Python has to be excluded on purpose. rv does not know the
// system Ruby, so the Ruby resolver could not answer with it by accident.
// uv finds /usr/bin/python3 and Xcode's copy readily, so the resolver passes
// --managed-python and this code refuses them wherever a person names one.
namespace python_runtime
{
	using answer_t = runtime_resolver::answer_t;

	// The version bundle commands run on, named exactly the way Ruby's is, and
	// for the same reason: a series would move under the bundles without
	// anything recording that it moved. Latest, and moved deliberately.
	extern std::string const kPinnedVersion;

	answer_t parse (std::string const& output);
	answer_t resolve (std::string const& resolverPath, std::string const& version);

	// /usr/bin/python3, anything inside an Xcode or Command Line Tools
	// developer directory, anything under the system Python framework, and
	// anything that resolves to one of those through a link.
	bool is_system_python (std::string const& executable);

} /* python_runtime */

#endif /* end of include guard: IO_PYTHON_RUNTIME_H_6D3A91E5 */
