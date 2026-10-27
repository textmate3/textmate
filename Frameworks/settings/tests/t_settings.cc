#include <test/jail.h>
#include <settings/settings.h>

void test_settings ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "testSetting = Hello");
	jail.set_content("dir/.tm_properties", "[ *.cc ]\ntestSetting = '${testSetting}, world!'");

	OAK_ASSERT_EQ(settings_for_path(jail.path("dir/file.cc")).get("testSetting"), "Hello, world!");
	OAK_ASSERT_EQ(settings_for_path(jail.path("dir/file.h")).get("testSetting"), "Hello");
}

void test_sections ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "testSetting = 7\n[ *.cc; *.h ]\ntestSetting = 6\n[ *.mm ]\ntestSetting = 5\n");

	OAK_ASSERT_EQ(settings_for_path(jail.path("file.m")).get("testSetting",  3), 7);
	OAK_ASSERT_EQ(settings_for_path(jail.path("file.h")).get("testSetting",  3), 6);
	OAK_ASSERT_EQ(settings_for_path(jail.path("file.cc")).get("testSetting", 3), 6);
	OAK_ASSERT_EQ(settings_for_path(jail.path("file.mm")).get("testSetting", 3), 5);
}

void test_sections_with_only_directory ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "testSetting = parent\n[ folder/** ]\ntestSetting = child\n");
	OAK_ASSERT_EQ(settings_for_path(NULL_STR, "", jail.path()).get("testSetting"), "parent");
	OAK_ASSERT_EQ(settings_for_path(NULL_STR, "", jail.path("folder")).get("testSetting"), "child");
}

// A comma between names separates them the way a semicolon does, with or
// without a space, while a comma inside braces stays part of a glob and a
// comma inside quotes stays part of a scope selector.
void test_sections_separated_by_commas ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "testSetting = root\n[ *.md, *.markdown ]\ntestSetting = markdown\n[ *.rb,*.rake ]\ntestSetting = ruby\n[ 'source.c++, source.objc++' ]\nscoped = yes\n[ tests/t_*.{cc,mm} ]\ntestSetting = test\n");

	OAK_ASSERT_EQ(settings_for_path(jail.path("a.md")).get("testSetting"),           "markdown");
	OAK_ASSERT_EQ(settings_for_path(jail.path("a.markdown")).get("testSetting"),     "markdown");
	OAK_ASSERT_EQ(settings_for_path(jail.path("a.rb")).get("testSetting"),           "ruby");
	OAK_ASSERT_EQ(settings_for_path(jail.path("a.rake")).get("testSetting"),         "ruby");
	OAK_ASSERT_EQ(settings_for_path(jail.path("a.txt")).get("testSetting"),          "root");
	OAK_ASSERT_EQ(settings_for_path(jail.path("tests/t_foo.cc")).get("testSetting"), "test");
	OAK_ASSERT_EQ(settings_for_path(jail.path("tests/t_foo.mm")).get("testSetting"), "test");
	OAK_ASSERT_EQ(settings_for_path(jail.path("tests/t_foo.py")).get("testSetting"), "root");
}

// A header that cannot be read opens a section that applies nowhere, so the
// settings under it reach no file, rather than every file through the root.
void test_malformed_section_applies_nowhere ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "testSetting = root\n[ *.md\ntestSetting = lost\n[ *.rb ]\ntestSetting = ruby\n");

	OAK_ASSERT_EQ(settings_for_path(jail.path("a.md")).get("testSetting"),  "root");
	OAK_ASSERT_EQ(settings_for_path(jail.path("a.txt")).get("testSetting"), "root");
	OAK_ASSERT_EQ(settings_for_path(jail.path("a.rb")).get("testSetting"),  "ruby");
}

// Every parse of a settings file reports the headers it could not read, by
// text and line, so the application can show them, and reports an empty list
// for a file whose headers all read, so it can take a warning down again.
void test_malformed_headers_are_reported ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "testSetting = root\n[ *.md\ntestSetting = lost\n[ *.rb ]\ntestSetting = ruby\n[ *.py \n");
	jail.set_content("clean/.tm_properties", "[ *.rb ]\ntestSetting = ruby\n");

	std::map<std::string, std::vector<settings_t::malformed_header_t>> reports;
	settings_t::set_malformed_headers_handler([&](std::string const& path, std::vector<settings_t::malformed_header_t> const& headers){
		reports[path] = headers;
	});

	settings_for_path(jail.path("a.md"));
	settings_for_path(jail.path("clean/a.rb"));
	settings_t::set_malformed_headers_handler(nullptr);

	OAK_ASSERT_EQ(reports[jail.path(".tm_properties")].size(), 2);
	OAK_ASSERT_EQ(reports[jail.path(".tm_properties")][0].header, "[ *.md");
	OAK_ASSERT_EQ(reports[jail.path(".tm_properties")][0].line_number, 2);
	OAK_ASSERT_EQ(reports[jail.path(".tm_properties")][1].header, "[ *.py");
	OAK_ASSERT_EQ(reports[jail.path(".tm_properties")][1].line_number, 6);
	OAK_ASSERT_EQ(reports[jail.path("clean/.tm_properties")].size(), 0);
}

void test_conversions ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "bool = true\nint = 42\nfloat = 5.5\nstring = 'charlie'\n");
	settings_t s = settings_for_path(jail.path("file.cc"));

	OAK_ASSERT_EQ(s.get("bool",        false),      true);
	OAK_ASSERT_EQ(s.get("int",             7),        42);
	OAK_ASSERT_EQ(s.get("float",         1.1),       5.5);
	OAK_ASSERT_EQ(s.get("string",    "sheen"), "charlie");

	OAK_ASSERT_EQ(s.get("Nonbool",     false),     false);
	OAK_ASSERT_EQ(s.get("Nonint",          7),         7);
	OAK_ASSERT_EQ(s.get("Nonfloat",      1.1),       1.1);
	OAK_ASSERT_EQ(s.get("Nonstring", "sheen"),   "sheen");
}

void test_coercion ()
{
	test::jail_t jail;
	jail.set_content(".tm_properties", "int = 42\nfloat = 42.0\nstring_1 = '42'\nstring_2 = '42.0'\n");
	settings_t s = settings_for_path(jail.path("file.cc"));

	OAK_ASSERT_EQ(s.get("int",    0),   42);
	OAK_ASSERT_EQ(s.get("int",  0.0), 42.0);
	OAK_ASSERT_EQ(s.get("int",  "0"), "42");

	OAK_ASSERT_EQ(s.get("float",    0),     42);
	OAK_ASSERT_EQ(s.get("float",  0.0),   42.0);
	OAK_ASSERT_EQ(s.get("float",  "0"), "42.0");

	OAK_ASSERT_EQ(s.get("string_1",    0),     42);
	OAK_ASSERT_EQ(s.get("string_1",  0.0),   42.0);
	OAK_ASSERT_EQ(s.get("string_1",  "0"),   "42");

	OAK_ASSERT_EQ(s.get("string_2",    0),     42);
	OAK_ASSERT_EQ(s.get("string_2",  0.0),   42.0);
	OAK_ASSERT_EQ(s.get("string_2",  "0"), "42.0");
}
