#ifndef TEXT_REPLACE_ALL_H_2K7QXWFP
#define TEXT_REPLACE_ALL_H_2K7QXWFP

namespace text
{
	// Every occurrence of find in str becomes replacement.
	// The search resumes after each replacement, so nothing the replacement introduces is matched.
	// An empty find matches nowhere and str comes back unchanged.
	std::string replace_all (std::string_view str, std::string_view find, std::string_view replacement);

} /* text */

#endif /* end of include guard: TEXT_REPLACE_ALL_H_2K7QXWFP */
