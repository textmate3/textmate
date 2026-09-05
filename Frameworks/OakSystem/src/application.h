#ifndef APPLICATION_H_J6YAXEQE
#define APPLICATION_H_J6YAXEQE

namespace oak
{
	// The application's identity on disk. The bundle identifier names the
	// defaults domain and the caches folder, and is what the Info.plist
	// declares. The support directory name is the folder under Application
	// Support, the application's own rather than TextMate 2's, so the two can
	// be installed side by side without sharing a session.
	extern char const* const kBundleIdentifier;
	extern char const* const kSupportDirectoryName;

	struct application_t
	{
		application_t (int argc, char const* argv[]);

		static void relaunch (char const* args = "-disableSessionRestore NO");
		static std::string name ();
		static std::string path (std::string const& relativePath = ".");
		static void set_name (std::string const& newName);
		static void set_path (std::string const& newPath);
		static void set_support (std::string const& newPath);
		static std::string support (std::string const& relativePath = ".");
		static std::string cache (std::string const& relativePath = ".");
		static std::string version ();
	};

} /* oak */

#endif /* end of include guard: APPLICATION_H_J6YAXEQE */
