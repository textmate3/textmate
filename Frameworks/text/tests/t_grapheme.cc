#include <text/grapheme.h>

// A family of four joined by zero width joiners: seven code points, one cluster.
static std::string const Family = "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6";
// The Scotland flag: a black flag and five tag letters, seven code points, one cluster.
static std::string const Scotland = "\xF0\x9F\x8F\xB4\xF3\xA0\x81\xA7\xF3\xA0\x81\xA2\xF3\xA0\x81\xB3\xF3\xA0\x81\xA3\xF3\xA0\x81\xB4\xF3\xA0\x81\xBF";
// e followed by a combining acute accent: two code points, one cluster.
static std::string const DecomposedE = "e\xCC\x81";

void test_ascii_steps_one_byte ()
{
	OAK_ASSERT_EQ(text::grapheme_end("abc", 0), 1);
	OAK_ASSERT_EQ(text::grapheme_end("abc", 2), 3);
	OAK_ASSERT_EQ(text::grapheme_end("abc", 3), 3);
	OAK_ASSERT_EQ(text::grapheme_begin("abc", 3), 2);
	OAK_ASSERT_EQ(text::grapheme_begin("abc", 1), 0);
	OAK_ASSERT_EQ(text::grapheme_begin("abc", 0), 0);
}

void test_family_emoji_is_one_step ()
{
	std::string const str = "a" + Family + "b";
	OAK_ASSERT_EQ(text::grapheme_end(str, 1), 1 + Family.size());
	OAK_ASSERT_EQ(text::grapheme_begin(str, 1 + Family.size()), 1);
	// From inside the cluster the boundaries are the cluster's, not the code point's.
	OAK_ASSERT_EQ(text::grapheme_end(str, 1 + 4), 1 + Family.size());
	OAK_ASSERT_EQ(text::grapheme_begin(str, 1 + 4), 1);
}

void test_tag_sequence_flag_is_one_step ()
{
	std::string const str = Scotland + "x";
	OAK_ASSERT_EQ(text::grapheme_end(str, 0), Scotland.size());
	OAK_ASSERT_EQ(text::grapheme_begin(str, Scotland.size()), 0);
}

void test_decomposed_accent_is_one_step ()
{
	std::string const str = "caf" + DecomposedE;
	OAK_ASSERT_EQ(text::grapheme_end(str, 3), str.size());
	OAK_ASSERT_EQ(text::grapheme_begin(str, str.size()), 3);
	OAK_ASSERT_EQ(text::grapheme_begin(str, 3), 2);
}

void test_newline_is_its_own_cluster ()
{
	std::string const str = DecomposedE + "\n";
	OAK_ASSERT_EQ(text::grapheme_end(str, 0), DecomposedE.size());
	OAK_ASSERT_EQ(text::grapheme_end(str, DecomposedE.size()), str.size());
	OAK_ASSERT_EQ(text::grapheme_begin(str, str.size()), DecomposedE.size());
}

void test_invalid_utf8_falls_back_to_one_code_point ()
{
	std::string const str = "a\xFF" "b";
	OAK_ASSERT_EQ(text::grapheme_end(str, 1), 2);
	OAK_ASSERT_EQ(text::grapheme_begin(str, 2), 1);
}
