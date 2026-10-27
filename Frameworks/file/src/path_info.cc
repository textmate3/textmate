#include "path_info.h"
#include <scm/scm.h>
#include <settings/settings.h>
#include <io/entries.h>
#include <regexp/glob.h>
#include <text/tokenize.h>
#include <oak/oak.h>
#include <sys/sysctl.h>

namespace
{
	struct os_version_t { size_t major = 0, minor = 0, patch = 0; };

	// The user visible macOS version via sysctl, for the scope attribute a
	// grammar or a setting can match on. Replaces the Gestalt API, which was
	// deprecated in macOS 10.8 and capped its answers at 10.9-era values on
	// later systems, so the attribute reported fiction. kern.osproductversion
	// exists since macOS 10.13.4.
	static os_version_t const& os_version ()
	{
		static os_version_t const res = []{
			os_version_t v;
			char buf[32] = { };
			size_t len = sizeof(buf) - 1;
			if(sysctlbyname("kern.osproductversion", buf, &len, nullptr, 0) == 0)
				sscanf(buf, "%zu.%zu.%zu", &v.major, &v.minor, &v.patch);
			return v;
		}();
		return res;
	}
}

namespace file
{
	std::string path_attributes (std::string const& path)
	{
		std::vector<std::string> res;
		if(path != NULL_STR)
		{
			std::vector<std::string> revPath;
			for(auto const& token : text::tokenize(path.begin(), path.end(), '/'))
			{
				std::string tmp = token;
				for(auto const& subtoken : text::tokenize(tmp.begin(), tmp.end(), '.'))
				{
					if(subtoken.empty())
						continue;
					revPath.push_back(subtoken);
					std::replace(revPath.back().begin(), revPath.back().end(), ' ', '_');
				}
			}
			revPath.push_back("rev-path");
			revPath.push_back("attr");
			std::reverse(revPath.begin(), revPath.end());
			res.push_back(text::join(revPath, "."));
		}
		else
		{
			res.push_back("attr.untitled");
		}

		os_version_t const& os = os_version();
		res.push_back(text::format("attr.os-version.%zu.%zu.%zu", os.major, os.minor, os.patch));
		return text::join(res, " ");
	}

} /* file */
