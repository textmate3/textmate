#include <io/ruby_discovery.h>
#include <io/path.h>

// The fixtures: a home with chruby and rbenv installs, 4.0.6, 3.4.2 and
// 4.1.0, plus a directory under .rubies that is not a version, and projects
// that pin a version by .ruby-version, by .tool-versions, pin one that is
// not installed, or pin nothing.
static std::string fixture (std::string const& name)
{
	return path::join(path::join(__FILE__, ".."), "fixtures/ruby_discovery/" + name);
}

static std::vector<ruby::install_t> fixture_installs ()
{
	return ruby::installs(fixture("home"), { });
}

void test_installs_are_found_newest_first ()
{
	std::vector<ruby::install_t> const installs = fixture_installs();
	OAK_ASSERT_EQ(installs.size(), 3);
	OAK_ASSERT_EQ(installs[0].version, "4.1.0");
	OAK_ASSERT_EQ(installs[0].source,  "rbenv");
	OAK_ASSERT_EQ(installs[1].version, "4.0.6");
	OAK_ASSERT_EQ(installs[1].source,  "chruby");
	OAK_ASSERT_EQ(installs[2].version, "3.4.2");
	OAK_ASSERT_EQ(installs[1].path,    fixture("home/.rubies/ruby-4.0.6"));
}

void test_version_order_is_numeric ()
{
	OAK_ASSERT(ruby::newer_than("4.10.0", "4.9.1"));
	OAK_ASSERT(ruby::newer_than("4.0.6", "4.0"));
	OAK_ASSERT(!ruby::newer_than("4.0", "4.0.0"));
	OAK_ASSERT(!ruby::newer_than("3.4.2", "4.0.6"));
}

void test_ruby_version_file_pins_the_project_and_what_is_below_it ()
{
	OAK_ASSERT_EQ(ruby::requested_version(fixture("projects/pinned")),        "3.4.2");
	OAK_ASSERT_EQ(ruby::requested_version(fixture("projects/pinned/nested")), "3.4.2");
	OAK_ASSERT_EQ(ruby::install_for_directory(fixture("projects/pinned/nested"), fixture_installs()).version, "3.4.2");
}

void test_tool_versions_file_names_ruby_among_other_tools ()
{
	OAK_ASSERT_EQ(ruby::requested_version(fixture("projects/asdf")), "4.0");
	OAK_ASSERT_EQ(ruby::install_for_directory(fixture("projects/asdf"), fixture_installs()).version, "4.0.6");
}

void test_unpinned_project_gets_the_newest_ruby_4_or_later ()
{
	OAK_ASSERT_EQ(ruby::requested_version(fixture("projects/unpinned")), NULL_STR);
	OAK_ASSERT_EQ(ruby::install_for_directory(fixture("projects/unpinned"), fixture_installs()).version, "4.1.0");
}

void test_pinned_to_missing_version_names_it_and_has_no_path ()
{
	ruby::install_t const install = ruby::install_for_directory(fixture("projects/pinned_to_missing"), fixture_installs());
	OAK_ASSERT_EQ(install.version, "5.0.0");
	OAK_ASSERT_EQ(install.path,    NULL_STR);
}

void test_nothing_installed_gives_nothing ()
{
	ruby::install_t const install = ruby::install_for_directory(fixture("projects/unpinned"), { });
	OAK_ASSERT_EQ(install.path, NULL_STR);
}

void test_only_rubies_4_or_later_stand_in_for_an_unpinned_project ()
{
	std::vector<ruby::install_t> const old = { { "3.4.2", "/somewhere", "chruby" } };
	OAK_ASSERT_EQ(ruby::install_for_directory(fixture("projects/unpinned"), old).path, NULL_STR);
}
