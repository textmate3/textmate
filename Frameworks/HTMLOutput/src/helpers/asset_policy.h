#ifndef HTML_OUTPUT_ASSET_POLICY_H
#define HTML_OUTPUT_ASSET_POLICY_H

#include <io/path.h>

namespace html_output
{
	// A page served from TextMate's scheme may load its own assets, a style
	// sheet, a script, an image, back through that scheme, and the handler reads
	// them from disk. That read is limited to a set of root directories: the
	// bundle locations, and the directories the command that produced the page
	// was running against. Anything else is refused.
	//
	// The page comes from a command already running as the user, so this bounds
	// accidental reach rather than defending against a hostile page. Containment
	// is by normalized path: a `..` component cannot climb out, and a root of
	// `/a/b` does not admit `/a/bc/x`. Symbolic links inside a root are honored
	// rather than resolved, because a link placed there is the user's doing, and
	// bundle repositories checked out elsewhere and linked into the bundles
	// directory depend on it.
	inline bool is_asset_allowed (std::string const& path, std::vector<std::string> const& roots)
	{
		for(auto const& root : roots)
		{
			if(root == NULL_STR || root.empty())
				continue;
			if(path::is_child(path, root))
				return true;
		}
		return false;
	}

} /* html_output */

#endif /* end of include guard: HTML_OUTPUT_ASSET_POLICY_H */
