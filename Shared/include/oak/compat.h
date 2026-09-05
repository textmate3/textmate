#ifndef COMPAT_H_RD1Z6YZA
#define COMPAT_H_RD1Z6YZA

#include <sys/sysctl.h>

namespace oak
{
	namespace detail
	{
		struct os_version_t { size_t major = 0, minor = 0, patch = 0; };

		// The user visible macOS version via sysctl. Replaces the Gestalt
		// API, which was deprecated in macOS 10.8 and capped its answers at
		// 10.9-era values on later systems, so version-derived scope
		// attributes and the update user agent reported fiction.
		// kern.osproductversion exists since macOS 10.13.4.
		inline os_version_t const& os_version ()
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

	inline size_t os_major () { return detail::os_version().major; }
	inline size_t os_minor () { return detail::os_version().minor; }
	inline size_t os_patch () { return detail::os_version().patch; }
} /* oak */

#endif /* end of include guard: COMPAT_H_RD1Z6YZA */
