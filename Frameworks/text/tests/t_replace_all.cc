#include <text/replace_all.h>

void test_replace_all ()
{
	OAK_ASSERT_EQ(text::replace_all("a\nb\nc",   "\n", "\r\n"), "a\r\nb\r\nc");
	OAK_ASSERT_EQ(text::replace_all("\n\n",      "\n", "\r\n"), "\r\n\r\n");
	OAK_ASSERT_EQ(text::replace_all("no match",  "\n", "\r\n"), "no match");
	OAK_ASSERT_EQ(text::replace_all("",          "\n", "\r\n"), "");
	OAK_ASSERT_EQ(text::replace_all("abc",       "b",  ""),     "ac");
	OAK_ASSERT_EQ(text::replace_all("aaa",       "a",  "aa"),   "aaaaaa");
	OAK_ASSERT_EQ(text::replace_all("aaa",       "aa", "a"),    "aa");
}

void test_replace_all_leaves_replacement_alone ()
{
	OAK_ASSERT_EQ(text::replace_all("x", "x", "xx"), "xx");
}

void test_replace_all_with_empty_find ()
{
	OAK_ASSERT_EQ(text::replace_all("abc", "", "-"), "abc");
}

void test_replace_all_of_script_path ()
{
	std::string const path = "/tmp/textmate_command.aBcDe";
	std::string const out  = path + ":3: syntax error\n" + path + ":7: warning\n";
	OAK_ASSERT_EQ(text::replace_all(out, path, "Run Script"), "Run Script:3: syntax error\nRun Script:7: warning\n");
}
