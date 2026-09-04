#include <plist/delta.h>

// A string value. Bare character literals would become booleans in a
// property list value, so every text goes through this.
static plist::any_t text (char const* value)
{
	return std::string(value);
}

void test_delta ()
{
	plist::dictionary_t const oldPlist =
	{
		{ "foo",     text("bar") },
		{ "bar",     text("bar") },
		{ "duff",    text("me") },
		{ "array_1", plist::array_t{ 1, 2, 3 } },
		{ "array_2", plist::array_t{ 1, 3 } },
		{ "array_3", plist::array_t{ text("power"), plist::array_t{ text("me"), plist::dictionary_t{ { "bad", text("good") } } }, 3 } },
		{ "dict_1",  plist::dictionary_t{
			{ "key",    text("value") },
			{ "foo",    plist::array_t{ text("bar") } },
			{ "nested", plist::dictionary_t{ { "funny", text("shit") }, { "more", text("clean") } } },
		} },
		{ "dict_2",  plist::dictionary_t{
			{ "key",    text("value") },
			{ "foo",    plist::array_t{ text("bar") } },
			{ "nested", plist::dictionary_t{ { "funny", text("shit") }, { "more", text("clean") } } },
		} },
	};

	plist::dictionary_t const newPlist =
	{
		{ "foo",     text("bar") },
		{ "duff",    text("other") },
		{ "charlie", text("sheen") },
		{ "array_1", plist::array_t{ 1, 2, 3 } },
		{ "array_2", plist::array_t{ 1, 5, 3 } },
		{ "array_3", plist::array_t{ text("power"), plist::array_t{ text("me"), plist::dictionary_t{ { "bad", text("good") } } }, 3 } },
		{ "dict_1",  plist::dictionary_t{
			{ "key",    text("value") },
			{ "foo",    plist::array_t{ text("bar") } },
			{ "nested", plist::dictionary_t{ { "funny", text("shit") }, { "more", text("explicit") } } },
		} },
		{ "dict_2",  plist::dictionary_t{
			{ "key",    text("value") },
			{ "foo",    plist::array_t{ text("bar") } },
			{ "nested", plist::dictionary_t{ { "funny", text("shit") }, { "less", text("clean") } } },
		} },
	};

	plist::dictionary_t const deltaPlist =
	{
		{ "deleted", plist::array_t{ text("bar"), text("dict_2.nested.more") } },
		{ "changed", plist::dictionary_t{
			{ "duff",               text("other") },
			{ "charlie",            text("sheen") },
			{ "array_2",            plist::array_t{ 1, 5, 3 } },
			{ "dict_1.nested.more", text("explicit") },
			{ "dict_2.nested.less", text("clean") },
		} },
		{ "isDelta", true },
	};

	OAK_ASSERT_EQ(to_s(plist::create_delta(oldPlist, newPlist)), to_s(deltaPlist));

	std::vector<plist::dictionary_t> plists{ deltaPlist, oldPlist };
	OAK_ASSERT_EQ(to_s(plist::merge_delta(plists)), to_s(newPlist));

	// =======================
	// = Test plist::equal() =
	// =======================

	OAK_ASSERT(plist::equal(plist::create_delta(oldPlist, newPlist), deltaPlist));
	OAK_ASSERT(plist::equal(plist::merge_delta(plists), newPlist));
	OAK_ASSERT(!plist::equal(oldPlist, newPlist));
}

void test_delta_settings_changed ()
{
	plist::dictionary_t const oldPlist =
	{
		{ "name",     text("Tag Preferences") },
		{ "scope",    text("meta.tag") },
		{ "settings", plist::array_t{ text("smartTypingPairs"), text("spellChecking") } },
		{ "uuid",     text("73251DBE-EBD2-470F-8148-E6F2EC1A9641") },
	};

	plist::dictionary_t const deltaPlist =
	{
		{ "changed", plist::dictionary_t{
			{ "settings.shellVariables", plist::array_t{ plist::dictionary_t{ { "name", text("TM_FOO") }, { "value", text("bar") } } } },
		} },
		{ "isDelta", true },
		{ "uuid",    text("73251DBE-EBD2-470F-8148-E6F2EC1A9641") },
	};

	plist::dictionary_t const newPlist =
	{
		{ "name",     text("Tag Preferences") },
		{ "scope",    text("meta.tag") },
		{ "settings", plist::array_t{ text("smartTypingPairs"), text("spellChecking"), text("shellVariables") } },
		{ "uuid",     text("73251DBE-EBD2-470F-8148-E6F2EC1A9641") },
	};

	std::vector<plist::dictionary_t> plists{ deltaPlist, oldPlist };
	OAK_ASSERT_EQ(to_s(plist::merge_delta(plists)), to_s(newPlist));
}

void test_delta_settings_deleted ()
{
	plist::dictionary_t const oldPlist =
	{
		{ "name",     text("Unprintable") },
		{ "scope",    text("deco.unprintable") },
		{ "settings", plist::array_t{ text("background"), text("fontName"), text("fontSize"), text("foreground") } },
		{ "uuid",     text("20881CB9-5D12-4D74-8EE6-9ABAA7B408D3") },
	};

	plist::dictionary_t const deltaPlist =
	{
		{ "deleted", plist::array_t{ text("settings.fontName"), text("settings.fontSize") } },
		{ "isDelta", true },
		{ "uuid",    text("20881CB9-5D12-4D74-8EE6-9ABAA7B408D3") },
	};

	plist::dictionary_t const newPlist =
	{
		{ "name",     text("Unprintable") },
		{ "scope",    text("deco.unprintable") },
		{ "settings", plist::array_t{ text("background"), text("foreground") } },
		{ "uuid",     text("20881CB9-5D12-4D74-8EE6-9ABAA7B408D3") },
	};

	std::vector<plist::dictionary_t> plists{ deltaPlist, oldPlist };
	OAK_ASSERT_EQ(to_s(plist::merge_delta(plists)), to_s(newPlist));
}

void test_delta_keys_with_dots ()
{
	plist::dictionary_t const oldPlist =
	{
		{ "name",       text("HTML Grammar") },
		{ "injections", plist::dictionary_t{
			{ "text.html.basic", text("foo") },
			{ "text.html.php",   text("bar") },
		} },
	};

	plist::dictionary_t const deltaPlist =
	{
		{ "changed", plist::dictionary_t{
			{ "injections.text\\.html\\.basic",    text("bar") },
			{ "injections.text\\.html\\.markdown", plist::dictionary_t{ { "name", text("something") } } },
		} },
		{ "deleted", plist::array_t{ text("injections.text\\.html\\.php") } },
		{ "isDelta", true },
	};

	plist::dictionary_t const newPlist =
	{
		{ "name",       text("HTML Grammar") },
		{ "injections", plist::dictionary_t{
			{ "text.html.basic",    text("bar") },
			{ "text.html.markdown", plist::dictionary_t{ { "name", text("something") } } },
		} },
	};

	OAK_ASSERT_EQ(to_s(plist::create_delta(oldPlist, newPlist)), to_s(deltaPlist));

	std::vector<plist::dictionary_t> plists{ deltaPlist, oldPlist };
	OAK_ASSERT_EQ(to_s(plist::merge_delta(plists)), to_s(newPlist));
}
