#include "grapheme.h"
#include "utf8.h"

namespace text
{
	namespace
	{
		using code_points_t = utf8::iterator_t<char const*>;

		// The start of the code point whose bytes include the offset.
		size_t code_point_start (std::string const& str, size_t byteIndex)
		{
			while(byteIndex > 0 && (str[byteIndex] & 0xC0) == 0x80)
				--byteIndex;
			return byteIndex;
		}

		// The end of the code point starting at the offset. A byte that starts no
		// code point, or one cut short by the end of the string, is one byte long.
		// The length is read off the lead byte here, since utf8::multibyte asserts
		// on a byte that cannot start a code point, and this is where one turns up.
		size_t code_point_end (std::string const& str, size_t byteIndex)
		{
			uint8_t const lead = str[byteIndex];
			size_t const len = lead < 0xC0 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : lead < 0xF8 ? 4 : 1;
			return byteIndex + len > str.size() ? byteIndex + 1 : byteIndex + len;
		}

		// The steps diacritics:: takes, which are Unicode's grapheme clusters with a line feed
		// always a step of its own, from the code point starting at the offset.
		diacritics::iterator_t<char const*> step_at (std::string const& str, size_t byteIndex)
		{
			char const* first = str.data();
			char const* last  = first + str.size();
			return diacritics::iterator_t<char const*>(code_points_t(first), code_points_t(first + byteIndex), code_points_t(last));
		}
	}

	// A string that is not valid UTF-8 has no clusters to find, and each code point is a step of its own.

	size_t grapheme_end (std::string const& str, size_t byteIndex)
	{
		if(byteIndex >= str.size())
			return byteIndex;

		size_t const start = code_point_start(str, byteIndex);
		if(!utf8::is_valid(str.data(), str.data() + str.size()))
			return code_point_end(str, start);

		auto step = step_at(str, start);
		return &++step - str.data();
	}

	size_t grapheme_begin (std::string const& str, size_t byteIndex)
	{
		if(byteIndex == 0 || str.empty())
			return byteIndex;
		byteIndex = std::min(byteIndex, str.size());

		size_t const start = code_point_start(str, byteIndex - 1);
		if(!utf8::is_valid(str.data(), str.data() + str.size()))
			return start;

		auto step = step_at(str, code_point_end(str, start));
		return &--step - str.data();
	}

} /* text */
