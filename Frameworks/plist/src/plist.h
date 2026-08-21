#ifndef PLIST_H_34L7NUFO
#define PLIST_H_34L7NUFO

#include "date.h"
#include "uuid.h"
#include <text/format.h>
#include <oak/debug.h>

namespace plist
{
	// A recursive variant: arrays and dictionaries contain any_t, which is
	// still incomplete where the containers are named. std::vector supports
	// incomplete element types since C++17; std::map is not guaranteed to,
	// but libc++ handles it and this project is macOS-only. Deriving from
	// std::variant keeps any_t a real type name, and C++23 (P2162) makes
	// std::visit work on the derived type.
	struct any_t;
	typedef std::map<std::string, any_t> dictionary_t;
	typedef std::vector<any_t> array_t;

	struct any_t : std::variant<bool, int32_t, uint64_t, std::string, std::vector<char>, oak::date_t, array_t, dictionary_t>
	{
		using variant::variant;
	};

	// std::get_if and std::get do not accept types derived from std::variant
	// (C++23 extends only std::visit), so these helpers cast to the base.
	template <typename T> T const* get_if (any_t const* v) { return v ? std::get_if<T>(static_cast<any_t::variant const*>(v)) : nullptr; }
	template <typename T> T*       get_if (any_t* v)       { return v ? std::get_if<T>(static_cast<any_t::variant*>(v)) : nullptr; }
	template <typename T> T const& get_ref (any_t const& v) { return std::get<T>(static_cast<any_t::variant const&>(v)); }
	template <typename T> T&       get_ref (any_t& v)       { return std::get<T>(static_cast<any_t::variant&>(v)); }

	enum plist_format_t { kPlistFormatBinary, kPlistFormatXML };

	dictionary_t load (std::string const& path);
	bool save (std::string const& path, any_t const& plist, plist_format_t format = kPlistFormatBinary);
	any_t parse (std::string const& str);
	dictionary_t convert (CFPropertyListRef plist);
	CFPropertyListRef create_cf_property_list (any_t const& plist);
	bool equal (any_t const& lhs, any_t const& rhs);

	bool is_true (any_t const& item);

	template <typename T> bool get_key_path (any_t const& plist, std::string const& keyPath, T& ref);
	template <typename T> T get (plist::any_t const& from);

	// to_s flags
	enum { kStandard = 0, kPreferSingleQuotedStrings = 1, kSingleLine = 2 };

	std::string to_s (any_t const& plist, int flags = kStandard, std::vector<std::string> const& keySortOrder = std::vector<std::string>());

} /* plist */

namespace boost // transitional forwarding shim; previously any_t lived in this namespace for ADL
{
	inline std::string to_s (plist::any_t const& plist, int flags = plist::kStandard, std::vector<std::string> const& keySortOrder = std::vector<std::string>())
	{
		return plist::to_s(plist, flags, keySortOrder);
	}
}

#endif /* end of include guard: PLIST_H_34L7NUFO */
