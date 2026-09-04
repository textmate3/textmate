#include <plist/plist.h>
#include <plist/stl.h>

void test_basic ()
{
	plist::any_t empty;
	// OAK_ASSERT(plist::get_if<bool>(&empty)        == nullptr);
	OAK_ASSERT(plist::get_if<int32_t>(&empty)     == nullptr);
	OAK_ASSERT(plist::get_if<std::string>(&empty) == nullptr);
}

void test_true_test ()
{
	OAK_ASSERT_EQ(plist::is_true(plist::any_t()),                     false);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(false)),                false);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(true)),                 true);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(0)),                    false);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(1)),                    true);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(std::string("0"))),     false);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(std::string("1"))),     true);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(std::string("NO"))),    true);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(std::string("YES"))),   true);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(std::string("false"))), true);
	OAK_ASSERT_EQ(plist::is_true(plist::any_t(std::string("true"))),  true);
}

void test_dictionary_keys ()
{
	std::map<std::string, int32_t> integerMap;
	integerMap["42"] = 1;
	integerMap["80"] = 2;
	OAK_ASSERT_EQ(plist::to_s(plist::any_t(plist::dictionary_t{ { "42", 1 }, { "80", 2 } })), plist::to_s(plist::to_plist(integerMap)));

	std::map<std::string, std::string> booleanMap;
	booleanMap["1"] = std::string("true");
	booleanMap["0"] = std::string("false");
	OAK_ASSERT_EQ(plist::to_s(plist::any_t(plist::dictionary_t{ { "1", std::string("true") }, { "0", std::string("false") } })), plist::to_s(plist::to_plist(booleanMap)));
}
