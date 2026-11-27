#include <text/grapheme_break.h>
#include <text/utf8.h>
#include <filesystem>
#include <fstream>

// Unicode's own boundary tests, saved by script/generate_grapheme_tables beside the table of the same version.
// Each line is code points in hex with ÷ where a boundary falls and × where none does, then a comment.
struct case_t
{
	std::string line, text;
	std::vector<size_t> boundaries;
};

static std::vector<case_t> unicode_cases ()
{
	std::ifstream file(std::filesystem::path(__FILE__).parent_path() / "fixtures/GraphemeBreakTest.txt");
	std::vector<case_t> res;
	for(std::string line; std::getline(file, line); )
	{
		std::string const data = line.substr(0, line.find('#'));
		if(data.find_first_not_of(" \t") == std::string::npos)
			continue;

		case_t test{ line };
		std::istringstream tokens(data);
		for(std::string token; tokens >> token; )
		{
			if(token == "\xC3\xB7") // ÷
				test.boundaries.push_back(test.text.size());
			else if(token != "\xC3\x97") // ×
				test.text += utf8::to_s(std::stoul(token, nullptr, 16));
		}
		res.push_back(test);
	}
	return res;
}

// The byte offsets of every boundary is_boundary finds, from the start of the text to its end.
static std::vector<size_t> boundaries_of (std::string const& text)
{
	utf8::iterator_t<char const*> const first(text.data()), last(text.data() + text.size());
	std::vector<size_t> res;
	for(auto it = first; ; ++it)
	{
		if(grapheme::is_boundary(first, it, last))
			res.push_back(&it - text.data());
		if(it == last)
			break;
	}
	return res;
}

void test_unicode_boundary_tests ()
{
	auto const cases = unicode_cases();
	OAK_ASSERT_EQ(cases.size(), 766);
	for(auto const& test : cases)
		OAK_MASSERT(test.line.c_str(), boundaries_of(test.text) == test.boundaries);
}

void test_table_names_its_unicode_version ()
{
	OAK_ASSERT_EQ(std::string(grapheme::kUnicodeVersion), "17.0.0");
}

void test_ascii_breaks_everywhere_but_inside_cr_lf ()
{
	OAK_ASSERT(boundaries_of("ab\r\nc") == std::vector<size_t>({ 0, 1, 2, 4, 5 }));
}
