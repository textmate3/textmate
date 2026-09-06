#ifndef IO_ENVIRONMENT_H_P8799509
#define IO_ENVIRONMENT_H_P8799509

namespace oak
{
	// The Ruby bundle commands run on, or NULL_STR when none has been found yet. The application
	// sets it at launch, from what rv finds or installs, and the environment every command gets
	// puts its bin first on PATH and names it in TM_RUBY. A TM_RUBY the person sets still wins.
	std::string const& application_ruby_directory ();
	void set_application_ruby_directory (std::string const& directory);

	std::map<std::string, std::string> const& basic_environment ();
	void set_basic_environment (std::map<std::string, std::string> const& newEnvironment);

	// The environment as it would be made now, for a caller that changed what goes into it.
	std::map<std::string, std::string> setup_basic_environment ();

} /* io */

#endif /* end of include guard: IO_ENVIRONMENT_H_P8799509 */
