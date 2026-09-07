#include "replace_all.h"

namespace text
{
	std::string replace_all (std::string_view str, std::string_view find, std::string_view replacement)
	{
		if(find.empty())
			return std::string(str);

		std::string res;
		std::string_view::size_type from = 0;
		while(true)
		{
			std::string_view::size_type at = str.find(find, from);
			if(at == std::string_view::npos)
				break;
			res.append(str, from, at - from);
			res.append(replacement);
			from = at + find.size();
		}
		res.append(str, from);
		return res;
	}

} /* text */
