#include <io/project_ruby.h>
#include <io/path.h>
#include <test/jail.h>

// The fixtures are stand-in resolvers: shell scripts that print one answer each.
static std::string fixture (std::string const& name)
{
	return path::join(path::join(__FILE__, ".."), "fixtures/project_ruby/" + name);
}

void test_a_pin_that_resolves ()
{
	project_ruby::answer_t const answer = project_ruby::parse("ruby /Users/someone/.local/share/rv/rubies/ruby-3.4.1\n");
	OAK_ASSERT_EQ(answer.ruby,    "/Users/someone/.local/share/rv/rubies/ruby-3.4.1");
	OAK_ASSERT_EQ(answer.missing, NULL_STR);
	OAK_ASSERT_EQ(answer.error,   NULL_STR);
	OAK_ASSERT(!answer.none);
}

void test_a_pin_that_is_not_installed_names_its_version ()
{
	project_ruby::answer_t const answer = project_ruby::parse("missing 3.4.1\n");
	OAK_ASSERT_EQ(answer.ruby,    NULL_STR);
	OAK_ASSERT_EQ(answer.missing, "3.4.1");
	OAK_ASSERT_EQ(answer.error,   NULL_STR);
}

void test_no_pin_anywhere ()
{
	project_ruby::answer_t const answer = project_ruby::parse("none\n");
	OAK_ASSERT(answer.none);
	OAK_ASSERT_EQ(answer.ruby,  NULL_STR);
	OAK_ASSERT_EQ(answer.error, NULL_STR);
}

void test_an_error_has_nothing_else ()
{
	project_ruby::answer_t const answer = project_ruby::parse("error rv is missing: the Runtimes bundle carries none and none is installed\n");
	OAK_ASSERT_EQ(answer.ruby,  NULL_STR);
	OAK_ASSERT_EQ(answer.error, "rv is missing: the Runtimes bundle carries none and none is installed");
}

void test_silence_is_an_error ()
{
	project_ruby::answer_t const answer = project_ruby::parse("");
	OAK_ASSERT_EQ(answer.ruby, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

void test_the_resolver_is_run_with_the_directory ()
{
	test::jail_t jail;
	project_ruby::answer_t const answer = project_ruby::resolve(fixture("answers_with_the_directory"), jail.path());
	OAK_ASSERT_EQ(answer.ruby, path::join(jail.path(), "stub-ruby"));
}

void test_a_missing_resolver_is_an_error ()
{
	project_ruby::answer_t const answer = project_ruby::resolve("/nowhere/project_ruby", "/tmp");
	OAK_ASSERT_EQ(answer.ruby, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

// The fingerprint changes when a pin file in the directory or above it changes, appears or goes, and not otherwise.
void test_the_fingerprint_follows_the_pin_files ()
{
	test::jail_t jail;
	jail.set_content("project/README.md", "nothing to do with Ruby");

	std::string const before = project_ruby::fingerprint(jail.path("project"));
	OAK_ASSERT_EQ(project_ruby::fingerprint(jail.path("project")), before);

	jail.set_content("project/.ruby-version", "3.4.1\n");
	std::string const pinned = project_ruby::fingerprint(jail.path("project"));
	OAK_ASSERT(pinned != before);

	jail.set_content(".tool-versions", "ruby 3.3.0\n");
	std::string const parentPinned = project_ruby::fingerprint(jail.path("project"));
	OAK_ASSERT(parentPinned != pinned);
}

// The resolver is asked once per directory and again only when the fingerprint moves.
void test_the_answer_is_kept_until_a_pin_changes ()
{
	test::jail_t jail;
	jail.set_content("project/.ruby-version", "3.4.1\n");
	std::string const log = jail.path("project/resolver.log");

	project_ruby::answer_t const first = project_ruby::cached_resolve(fixture("logs_each_run"), jail.path("project"));
	OAK_ASSERT_EQ(first.ruby, path::join(jail.path("project"), "stub-ruby"));
	OAK_ASSERT_EQ(path::content(log), "run\n");

	project_ruby::cached_resolve(fixture("logs_each_run"), jail.path("project"));
	OAK_ASSERT_EQ(path::content(log), "run\n");

	jail.set_content("project/.ruby-version", "3.3.0\n");
	project_ruby::cached_resolve(fixture("logs_each_run"), jail.path("project"));
	OAK_ASSERT_EQ(path::content(log), "run\nrun\n");
}
