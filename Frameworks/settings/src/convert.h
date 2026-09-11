#ifndef SETTINGS_CONVERT_H_3F81A0C7
#define SETTINGS_CONVERT_H_3F81A0C7

// Reading a .tm_properties file and writing the same thing as JSON.
//
// This converts. It does not replace anything: the application still reads the
// old format through the parser, and nothing here is wired into that path.
//
// The shape it writes, with comments, which is why the format is JSON with
// comments rather than strict JSON:
//
//   {
//     "settings":  { "tabSize": 2, "softTabs": true },
//     "variables": { "TM_GIT": "/usr/bin/git" },
//     "scoped": [
//       { "match": ["*.txt"], "settings": { "softWrap": true } }
//     ]
//   }
//
// Two namespaces exist in the old format and the discriminator is the first
// letter's case: lowercase is an editor setting from a known set, uppercase is
// a variable handed to bundle commands. That convention is something a person
// had to know. Here they are two places.
//
// Types are promoted only for settings whose type is known from how the
// application reads them. Everything else stays a string, because guessing at
// a type is how a converter loses information it cannot get back.
namespace settings
{
	// The JSON for a settings file's contents. The path is used for the comment
	// naming where it came from, and for nothing else.
	std::string to_json (std::string const& content, std::string const& path);

	// The same, reading the file itself. NULL_STR when it cannot be read.
	std::string to_json_for_path (std::string const& path);

} /* settings */

#endif /* end of include guard: SETTINGS_CONVERT_H_3F81A0C7 */
