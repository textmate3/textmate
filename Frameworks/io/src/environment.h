#ifndef IO_ENVIRONMENT_H_P8799509
#define IO_ENVIRONMENT_H_P8799509

namespace oak
{
	// The Ruby inside the application bundle, under Contents/Resources/Ruby, or NULL_STR when
	// this copy carries none. Bundle commands run on it when it is there.
	std::string embedded_ruby_directory ();

	// A Ruby the application fetched and installed for itself, under its support directory,
	// which stands in when the bundle carries none. The application says where, since this
	// framework knows nothing of the support directory, and says so again after a download.
	std::string const& downloaded_ruby_directory ();
	void set_downloaded_ruby_directory (std::string const& directory);

	// The Ruby bundle commands run on: the embedded one, else the downloaded one, else NULL_STR.
	std::string application_ruby_directory ();

	std::map<std::string, std::string> const& basic_environment ();
	void set_basic_environment (std::map<std::string, std::string> const& newEnvironment);

	// The environment as it would be made now, for a caller that changed what goes into it.
	std::map<std::string, std::string> setup_basic_environment ();

} /* io */

#endif /* end of include guard: IO_ENVIRONMENT_H_P8799509 */
