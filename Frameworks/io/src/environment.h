#ifndef IO_ENVIRONMENT_H_P8799509
#define IO_ENVIRONMENT_H_P8799509

namespace oak
{
	// The Ruby inside the application bundle, under Contents/Resources/Ruby, or NULL_STR when
	// this copy carries none. Bundle commands run on it when it is there.
	std::string embedded_ruby_directory ();

	std::map<std::string, std::string> const& basic_environment ();
	void set_basic_environment (std::map<std::string, std::string> const& newEnvironment);

} /* io */

#endif /* end of include guard: IO_ENVIRONMENT_H_P8799509 */
