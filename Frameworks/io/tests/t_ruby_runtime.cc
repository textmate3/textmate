#include <io/ruby_runtime.h>
#include <io/path.h>

// The fixtures are stand-in resolvers: shell scripts that print one answer each.
static std::string fixture (std::string const& name)
{
	return path::join(path::join(__FILE__, ".."), "fixtures/ruby_runtime/" + name);
}

void test_a_plain_answer ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::parse("ruby /Users/someone/.rubies/ruby-4.0.6\n");
	OAK_ASSERT_EQ(answer.ruby,      "/Users/someone/.rubies/ruby-4.0.6");
	OAK_ASSERT_EQ(answer.installed, NULL_STR);
	OAK_ASSERT_EQ(answer.fallback,  NULL_STR);
	OAK_ASSERT_EQ(answer.error,     NULL_STR);
}

void test_an_install_names_the_version_and_the_ruby ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::parse("installed 4.0.6 /Users/someone/.local/share/rv/rubies/ruby-4.0.6\nruby /Users/someone/.local/share/rv/rubies/ruby-4.0.6\n");
	OAK_ASSERT_EQ(answer.installed, "4.0.6");
	OAK_ASSERT_EQ(answer.ruby,      "/Users/someone/.local/share/rv/rubies/ruby-4.0.6");
}

void test_a_fallback_carries_its_reason ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::parse("fallback /Users/someone/.rubies/ruby-4.1.0 Ruby 4.0.6 could not be installed, so the newest Ruby 4 on this machine stands in\n");
	OAK_ASSERT_EQ(answer.ruby,     "/Users/someone/.rubies/ruby-4.1.0");
	OAK_ASSERT_EQ(answer.fallback, "Ruby 4.0.6 could not be installed, so the newest Ruby 4 on this machine stands in");
}

void test_an_error_has_no_ruby ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::parse("error Ruby 4.0.6 could not be installed and no Ruby 4 is on this machine\n");
	OAK_ASSERT_EQ(answer.ruby,  NULL_STR);
	OAK_ASSERT_EQ(answer.error, "Ruby 4.0.6 could not be installed and no Ruby 4 is on this machine");
}

void test_silence_is_an_error ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::parse("");
	OAK_ASSERT_EQ(answer.ruby, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

void test_the_resolver_is_run_and_read ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::resolve(fixture("answers_installed"), "4.0.6");
	OAK_ASSERT_EQ(answer.installed, "4.0.6");
	OAK_ASSERT_EQ(answer.ruby,      "/stub/rubies/ruby-4.0.6");
}

void test_a_missing_resolver_is_an_error ()
{
	ruby_runtime::answer_t const answer = ruby_runtime::resolve(fixture("does_not_exist"), "4.0.6");
	OAK_ASSERT_EQ(answer.ruby, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

void test_the_system_ruby_is_known_by_every_name ()
{
	OAK_ASSERT(ruby_runtime::is_system_ruby("/usr/bin/ruby"));
	OAK_ASSERT(ruby_runtime::is_system_ruby("/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/bin/ruby"));
	OAK_ASSERT(!ruby_runtime::is_system_ruby("/Users/someone/.rubies/ruby-4.0.6/bin/ruby"));
	OAK_ASSERT(!ruby_runtime::is_system_ruby("/opt/homebrew/opt/ruby/bin/ruby"));
	OAK_ASSERT(!ruby_runtime::is_system_ruby(NULL_STR));
}

void test_the_pinned_version ()
{
	OAK_ASSERT_EQ(ruby_runtime::kPinnedVersion, "4.0.6");
}
