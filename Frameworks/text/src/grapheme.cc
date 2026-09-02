#include "grapheme.h"
#include "utf8.h"
#include <CoreFoundation/CoreFoundation.h>

namespace text
{
	namespace
	{
		// The byte offset and UTF-16 offset of every code point start, plus one
		// entry for the end of the string, so offsets translate both ways.
		struct offsets_t
		{
			std::vector<size_t> bytes, units;

			explicit offsets_t (std::string const& str)
			{
				size_t b = 0, u = 0;
				while(b < str.size())
				{
					size_t len = utf8::multibyte<char>::length(str[b]);
					if(len == 0 || b + len > str.size())
						len = 1;
					bytes.push_back(b); units.push_back(u);
					uint32_t ch = utf8::to_ch(str.substr(b, len));
					u += ch > 0xFFFF ? 2 : 1;
					b += len;
				}
				bytes.push_back(str.size()); units.push_back(u);
			}

			// The index of the code point whose byte range contains the offset.
			size_t code_point_at (size_t byteIndex) const
			{
				size_t i = std::upper_bound(bytes.begin(), bytes.end(), byteIndex) - bytes.begin();
				return i ? i - 1 : 0;
			}

			size_t bytes_for_unit (size_t unit) const
			{
				size_t i = std::lower_bound(units.begin(), units.end(), unit) - units.begin();
				return bytes[std::min(i, bytes.size() - 1)];
			}
		};

		// The byte range of the cluster containing the given code point. When
		// the string is not valid UTF-8 there is no cluster to ask for, and the
		// code point's own bytes are the answer, as before.
		std::pair<size_t, size_t> cluster_containing (std::string const& str, offsets_t const& offsets, size_t codePoint)
		{
			std::pair<size_t, size_t> codePointBytes = { offsets.bytes[codePoint], offsets.bytes[codePoint + 1] };

			CFStringRef cf = CFStringCreateWithBytes(kCFAllocatorDefault, (UInt8 const*)str.data(), str.size(), kCFStringEncodingUTF8, false);
			if(!cf)
				return codePointBytes;
			CFRange range = CFStringGetRangeOfComposedCharactersAtIndex(cf, offsets.units[codePoint]);
			CFRelease(cf);

			std::pair<size_t, size_t> res = { offsets.bytes_for_unit(range.location), offsets.bytes_for_unit(range.location + range.length) };
			return res.first < res.second ? res : codePointBytes;
		}
	}

	size_t grapheme_end (std::string const& str, size_t byteIndex)
	{
		if(byteIndex >= str.size())
			return byteIndex;

		offsets_t offsets(str);
		return cluster_containing(str, offsets, offsets.code_point_at(byteIndex)).second;
	}

	size_t grapheme_begin (std::string const& str, size_t byteIndex)
	{
		if(byteIndex == 0 || str.empty())
			return byteIndex;
		byteIndex = std::min(byteIndex, str.size());

		offsets_t offsets(str);
		return cluster_containing(str, offsets, offsets.code_point_at(byteIndex - 1)).first;
	}

} /* text */
