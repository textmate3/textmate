#include <text/utf8.h>

// What diacritics::make_range calls a grapheme: a grapheme cluster by Unicode's
// rules, so a family emoji or a flag or a skin tone is one step, with a line
// feed always a step of its own. Each step is shown as its code point, its byte
// offset and its byte length.
static std::string steps (std::string const& str)
{
	std::string res;
	auto const graphemes = diacritics::make_range(str.data(), str.data() + str.size());
	for(auto ch = graphemes.begin(); ch != graphemes.end(); ++ch)
		res += std::format("{}U+{:04X}@{}:{}", res.empty() ? "" : " ", *ch, &ch - str.data(), ch.length());
	return res;
}

// The same, through graphemes(), which hands each step over as a value.
static std::string values (std::string const& str)
{
	std::string res;
	for(auto grapheme : diacritics::graphemes(str.data(), str.data() + str.size()))
		res += std::format("{}U+{:04X}@{}:{}", res.empty() ? "" : " ", grapheme.code_point, grapheme.first - str.data(), grapheme.length());
	return res;
}

void test_graphemes_agree_with_make_range ()
{
	static std::string const samples[] = {
		"", "abc", "caf\xC3\xA9", "cafe\xCC\x81", "a\xCC\x81\xCC\xA7" "b", "\xE6\x97\xA5\xE6\x9C\xAC", "a\tb\n", "a\r\nb",
		"\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6",
		"\xF0\x9F\x8F\xB4\xF3\xA0\x81\xA7\xF3\xA0\x81\xA2\xF3\xA0\x81\xB3\xF3\xA0\x81\xA3\xF3\xA0\x81\xB4\xF3\xA0\x81\xBF",
		"\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD",
	};
	for(auto const& sample : samples)
		OAK_ASSERT_EQ(values(sample), steps(sample));
}

void test_a_grapheme_value_carries_its_bytes ()
{
	std::string const str = "cafe\xCC\x81!";
	std::vector<std::string> bytes;
	for(auto grapheme : diacritics::graphemes(str.data(), str.data() + str.size()))
		bytes.emplace_back(grapheme.first, grapheme.last);
	OAK_ASSERT_EQ(bytes.size(), 5);
	OAK_ASSERT_EQ(bytes[3], "e\xCC\x81");
	OAK_ASSERT_EQ(bytes[4], "!");
}

void test_ascii_is_one_byte_a_step ()
{
	OAK_ASSERT_EQ(steps("abc"), "U+0061@0:1 U+0062@1:1 U+0063@2:1");
	OAK_ASSERT_EQ(steps(""), "");
}

void test_precomposed_accent_is_one_step ()
{
	OAK_ASSERT_EQ(steps("caf\xC3\xA9"), "U+0063@0:1 U+0061@1:1 U+0066@2:1 U+00E9@3:2");
}

void test_combining_marks_join_their_base ()
{
	// e and a combining acute accent.
	OAK_ASSERT_EQ(steps("cafe\xCC\x81"), "U+0063@0:1 U+0061@1:1 U+0066@2:1 U+0065@3:3");
	// a with a combining acute and a combining cedilla, then b.
	OAK_ASSERT_EQ(steps("a\xCC\x81\xCC\xA7" "b"), "U+0061@0:5 U+0062@5:1");
}

void test_wide_characters_are_one_step_each ()
{
	OAK_ASSERT_EQ(steps("\xE6\x97\xA5\xE6\x9C\xAC"), "U+65E5@0:3 U+672C@3:3");
}

void test_tab_newline_and_carriage_return_are_steps_of_their_own ()
{
	OAK_ASSERT_EQ(steps("a\tb\n"), "U+0061@0:1 U+0009@1:1 U+0062@2:1 U+000A@3:1");
	OAK_ASSERT_EQ(steps("a\r\nb"), "U+0061@0:1 U+000D@1:1 U+000A@2:1 U+0062@3:1");
}

void test_joined_emoji_are_one_step ()
{
	// A family of four joined by zero width joiners.
	OAK_ASSERT_EQ(steps("\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6"), "U+1F468@0:25");
	// The Scotland flag, a black flag and five tag letters.
	OAK_ASSERT_EQ(steps("\xF0\x9F\x8F\xB4\xF3\xA0\x81\xA7\xF3\xA0\x81\xA2\xF3\xA0\x81\xB3\xF3\xA0\x81\xA3\xF3\xA0\x81\xB4\xF3\xA0\x81\xBF"), "U+1F3F4@0:28");
	// A thumbs up and a skin tone modifier.
	OAK_ASSERT_EQ(steps("\xF0\x9F\x91\x8D\xF0\x9F\x8F\xBD"), "U+1F44D@0:8");
}

void test_regional_indicators_pair_into_flags ()
{
	// The United States flag and then the French flag, four regional indicators.
	OAK_ASSERT_EQ(steps("\xF0\x9F\x87\xBA\xF0\x9F\x87\xB8\xF0\x9F\x87\xAB\xF0\x9F\x87\xB7"), "U+1F1FA@0:8 U+1F1EB@8:8");
}

void test_indic_conjunct_is_one_step ()
{
	// Devanagari ka, virama, ssa and the vowel sign i: one conjunct.
	OAK_ASSERT_EQ(steps("\xE0\xA4\x95\xE0\xA5\x8D\xE0\xA4\xB7\xE0\xA4\xBF"), "U+0915@0:12");
}

void test_carriage_return_and_line_feed_stay_two_steps ()
{
	// Unicode joins CR LF, but every caller looks for a line feed as a step of its own.
	OAK_ASSERT_EQ(steps("\r\n"), "U+000D@0:1 U+000A@1:1");
}

// Stepping back from the end finds the same steps as stepping forward.
static std::string steps_backward (std::string const& str)
{
	std::vector<std::string> found;
	auto const graphemes = diacritics::make_range(str.data(), str.data() + str.size());
	for(auto ch = graphemes.end(); ch != graphemes.begin(); )
	{
		--ch;
		found.insert(found.begin(), std::format("U+{:04X}@{}:{}", *ch, &ch - str.data(), ch.length()));
	}
	std::string res;
	for(auto const& step : found)
		res += (res.empty() ? "" : " ") + step;
	return res;
}

void test_stepping_backward_agrees_with_forward ()
{
	static std::string const samples[] = {
		"abc", "cafe\xCC\x81!", "a\r\nb",
		"x\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6y",
		"\xF0\x9F\x87\xBA\xF0\x9F\x87\xB8\xF0\x9F\x87\xAB\xF0\x9F\x87\xB7\xF0\x9F\x87\xBA",
		"\xE0\xA4\x95\xE0\xA5\x8D\xE0\xA4\xB7\xE0\xA4\xBF" "a",
	};
	for(auto const& sample : samples)
		OAK_ASSERT_EQ(steps_backward(sample), steps(sample));
}
