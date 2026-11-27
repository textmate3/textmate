#include <text/parse.h>
#include <text/utf8.h>

// How long wrapping and stepping by grapheme take over a megabyte of text of each kind.
// Soft wrapping walks every grapheme of a line and counts its columns, as the layout does.

static std::string const kCodeLine  = "\tfor(auto const& item : items) { total += item.size(); } // sum\n";
static std::string const kProseLine = "Le caf\xC3\xA9 d\xC3\xA9j\xC3\xA0 vu, na\xC3\xAFve fa\xC3\xA7" "ade, r\xC3\xA9sum\xC3\xA9 et e\xCC\x81 d\xC3\xA9" "compos\xC3\xA9.\n";
static std::string const kEmojiLine = "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6 \xF0\x9F\x87\xBA\xF0\x9F\x87\xB8 \xF0\x9F\x91\x8B\xF0\x9F\x8F\xBD ok \xF0\x9F\x87\xAB\xF0\x9F\x87\xB7\n";

static std::string megabyte_of (std::string const& line)
{
	std::string res;
	while(res.size() < 1024*1024)
		res += line;
	return res;
}

static size_t count_steps (std::string const& str)
{
	size_t res = 0;
	for(auto ch : diacritics::make_range(str.data(), str.data() + str.size()))
		res += ch != 0;
	return res;
}

void benchmark_soft_breaks_code_1_mb ()
{
	std::string const str = megabyte_of(kCodeLine);
	OAK_ASSERT(!text::soft_breaks(str, 40, 4).empty());
}

void benchmark_soft_breaks_prose_1_mb ()
{
	std::string const str = megabyte_of(kProseLine);
	OAK_ASSERT(!text::soft_breaks(str, 40, 4).empty());
}

void benchmark_soft_breaks_emoji_1_mb ()
{
	std::string const str = megabyte_of(kEmojiLine);
	OAK_ASSERT(!text::soft_breaks(str, 40, 4).empty());
}

void benchmark_grapheme_steps_code_1_mb ()
{
	OAK_ASSERT(count_steps(megabyte_of(kCodeLine)) > 0);
}

void benchmark_grapheme_steps_emoji_1_mb ()
{
	OAK_ASSERT(count_steps(megabyte_of(kEmojiLine)) > 0);
}
