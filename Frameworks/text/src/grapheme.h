#ifndef TEXT_GRAPHEME_H
#define TEXT_GRAPHEME_H

namespace text
{
	// Grapheme cluster boundaries in a UTF-8 string, the units a caret should
	// step by: a decomposed accented letter is one cluster, and so is a family
	// emoji joined from four people or a flag built from tag characters.
	//
	// Both take a byte offset. grapheme_end returns the end of the cluster that
	// contains the code point starting at that offset, and grapheme_begin
	// returns the start of the cluster that contains the code point ending
	// there. At the ends of the string they return the offset unchanged.
	size_t grapheme_end (std::string const& str, size_t byteIndex);
	size_t grapheme_begin (std::string const& str, size_t byteIndex);

} /* text */

#endif /* end of include guard: TEXT_GRAPHEME_H */
