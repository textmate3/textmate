#include <settings/convert.h>

static std::string convert (std::string const& content)
{
	return settings::to_json(content, "/somewhere/.tm_properties");
}

static bool has (std::string const& haystack, std::string const& needle)
{
	return haystack.find(needle) != std::string::npos;
}

void test_a_setting_and_a_variable_go_to_their_own_places ()
{
	std::string const json = convert("tabSize = 2\nTM_GIT = \"/usr/bin/git\"\n");
	OAK_ASSERT(has(json, "\"settings\": {\n\t\t\"tabSize\": 2\n\t}"));
	OAK_ASSERT(has(json, "\"variables\": {\n\t\t\"TM_GIT\": \"/usr/bin/git\"\n\t}"));
}

void test_the_settings_with_a_known_type_are_promoted ()
{
	std::string const json = convert("tabSize = 4\nfontSize = 11\nsoftTabs = true\nsoftWrap = false\n");
	OAK_ASSERT(has(json, "\"tabSize\": 4"));
	OAK_ASSERT(has(json, "\"fontSize\": 11"));
	OAK_ASSERT(has(json, "\"softTabs\": true"));
	OAK_ASSERT(has(json, "\"softWrap\": false"));
}

void test_a_setting_with_no_known_type_stays_a_string ()
{
	std::string const json = convert("theme = 06CD1FB2-A00A-4F8C-97B2-60E131980454\nfontName = Menlo\n");
	OAK_ASSERT(has(json, "\"theme\": \"06CD1FB2-A00A-4F8C-97B2-60E131980454\""));
	OAK_ASSERT(has(json, "\"fontName\": \"Menlo\""));
}

void test_the_quoting_the_old_format_needed_does_not_survive ()
{
	std::string const json = convert("spellingLanguage = \"en\"\n");
	OAK_ASSERT(has(json, "\"spellingLanguage\": \"en\""));
	OAK_ASSERT(!has(json, "\\\"en\\\""));
}

// The value mini language is not this converter's business. What goes in comes
// out, so the expander is handed the same bytes it was handed before.
void test_the_value_mini_language_is_carried_through_untouched ()
{
	std::string const json = convert("excludeInFileChooser = \"{$excludeInFileChooser,$myExtraExcludes}\"\n");
	OAK_ASSERT(has(json, "\"excludeInFileChooser\": \"{$excludeInFileChooser,$myExtraExcludes}\""));
}

// JSON eats one level of backslash, so a value carrying one has to gain one.
void test_a_backslash_is_escaped_so_the_expander_sees_what_it_saw_before ()
{
	std::string const json = convert("exclude = \"{Icon\\r,*\\~.nib}\"\n");
	OAK_ASSERT(has(json, "\\\\r"));
	OAK_ASSERT(has(json, "\\\\~"));
}

void test_a_quote_inside_a_value_is_escaped ()
{
	std::string const json = convert("TM_SAY = 'he said \"hi\"'\n");
	OAK_ASSERT(has(json, "\\\"hi\\\""));
}

void test_a_section_becomes_a_scoped_entry ()
{
	std::string const json = convert("tabSize = 2\n\n[ *.txt ]\nsoftWrap = true\n");
	OAK_ASSERT(has(json, "\"scoped\": ["));
	OAK_ASSERT(has(json, "\"match\": [\"*.txt\"]"));
	OAK_ASSERT(has(json, "\"softWrap\": true"));
}

// The separator inside a section header is a semicolon. Spaces around the
// selectors are fine.
void test_a_section_with_several_selectors_keeps_them_all ()
{
	std::string const json = convert("[ *.md; *.markdown ]\nsoftWrap = true\n");
	OAK_ASSERT(has(json, "\"match\": [\"*.md\", \"*.markdown\"]"));

	std::string const tight = convert("[*.md;*.markdown]\nsoftWrap = true\n");
	OAK_ASSERT(has(tight, "\"match\": [\"*.md\", \"*.markdown\"]"));
}

// A comma is not a separator, which is worth pinning down because it is the
// thing a person reaches for. Without a space it becomes part of one selector,
// which then matches nothing. With a space the whole section fails to parse and
// is dropped in silence, and the settings under it land at the root, where they
// apply everywhere rather than nowhere.
//
// The converter carries this through rather than correcting it, because a
// converter that silently changes what a file means is worse than one that
// shows you what the file always meant.
void test_a_comma_is_not_a_separator_and_the_converter_does_not_pretend_it_is ()
{
	std::string const tight = convert("[*.md,*.markdown]\nsoftWrap = true\n");
	OAK_ASSERT(has(tight, "\"match\": [\"*.md,*.markdown\"]"));

	std::string const spaced = convert("[*.md, *.markdown]\nsoftWrap = true\n");
	OAK_ASSERT(!has(spaced, "\"scoped\""));
	OAK_ASSERT(has(spaced, "\"softWrap\": true"));
}

void test_a_variable_inside_a_section_stays_a_variable ()
{
	std::string const json = convert("[ source.ruby ]\nTM_RUBY = \"/opt/ruby\"\ntabSize = 2\n");
	OAK_ASSERT(has(json, "\t\t\t\"variables\": {\n\t\t\t\t\"TM_RUBY\": \"/opt/ruby\"\n\t\t\t}"));
	OAK_ASSERT(has(json, "\t\t\t\"settings\": {\n\t\t\t\t\"tabSize\": 2\n\t\t\t}"));
}

void test_an_empty_file_still_converts_to_something_valid ()
{
	std::string const json = convert("");
	OAK_ASSERT(has(json, "\"settings\": {"));
	OAK_ASSERT(has(json, "\"variables\": {"));
	OAK_ASSERT(!has(json, "\"scoped\""));
}

void test_comments_in_the_old_file_do_not_carry_values_over ()
{
	std::string const json = convert("# tabSize = 99\ntabSize = 2\n");
	OAK_ASSERT(has(json, "\"tabSize\": 2"));
	OAK_ASSERT(!has(json, "99"));
}
