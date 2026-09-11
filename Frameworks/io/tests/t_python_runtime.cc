#include <io/python_runtime.h>
#include <io/path.h>

// The fixtures are stand-in resolvers: shell scripts that print one answer each.
static std::string fixture (std::string const& name)
{
	return path::join(path::join(__FILE__, ".."), "fixtures/python_runtime/" + name);
}

void test_a_plain_python_answer ()
{
	python_runtime::answer_t const answer = python_runtime::parse("python /Users/someone/.local/share/uv/python/cpython-3.13/bin/python3.13\n");
	OAK_ASSERT_EQ(answer.path,      "/Users/someone/.local/share/uv/python/cpython-3.13/bin/python3.13");
	OAK_ASSERT_EQ(answer.installed, NULL_STR);
	OAK_ASSERT_EQ(answer.fallback,  NULL_STR);
	OAK_ASSERT_EQ(answer.error,     NULL_STR);
}

void test_a_python_install_names_the_version_and_the_interpreter ()
{
	python_runtime::answer_t const answer = python_runtime::parse("installed 3.13 /stub/bin/python3.13\npython /stub/bin/python3.13\n");
	OAK_ASSERT_EQ(answer.installed, "3.13");
	OAK_ASSERT_EQ(answer.path,      "/stub/bin/python3.13");
}

void test_a_python_fallback_carries_its_reason ()
{
	python_runtime::answer_t const answer = python_runtime::parse("fallback /stub/bin/python3.12 Python 3.13 could not be installed\n");
	OAK_ASSERT_EQ(answer.path,     "/stub/bin/python3.12");
	OAK_ASSERT_EQ(answer.fallback, "Python 3.13 could not be installed");
}

void test_a_python_error_has_no_interpreter ()
{
	python_runtime::answer_t const answer = python_runtime::parse("error uv manages no Python on this machine\n");
	OAK_ASSERT_EQ(answer.path,  NULL_STR);
	OAK_ASSERT_EQ(answer.error, "uv manages no Python on this machine");
}

void test_python_silence_is_an_error ()
{
	python_runtime::answer_t const answer = python_runtime::parse("");
	OAK_ASSERT_EQ(answer.path, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

// A Ruby answer read as a Python one finds no interpreter, which is what keeps
// the two resolvers from being mistaken for each other.
void test_the_keyword_belongs_to_its_language ()
{
	python_runtime::answer_t const answer = python_runtime::parse("ruby /Users/someone/.rubies/ruby-4.0.6\n");
	OAK_ASSERT_EQ(answer.path, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

void test_the_python_resolver_is_run_and_read ()
{
	python_runtime::answer_t const answer = python_runtime::resolve(fixture("answers_installed"), "3.13");
	OAK_ASSERT_EQ(answer.installed, "3.13");
	OAK_ASSERT_EQ(answer.path,      "/stub/pythons/cpython-3.13/bin/python3");
}

void test_a_missing_python_resolver_is_an_error ()
{
	python_runtime::answer_t const answer = python_runtime::resolve(fixture("does_not_exist"), "3.13");
	OAK_ASSERT_EQ(answer.path, NULL_STR);
	OAK_ASSERT(answer.error != NULL_STR);
}

void test_the_system_python_is_known_by_every_name ()
{
	OAK_ASSERT(python_runtime::is_system_python("/usr/bin/python3"));
	OAK_ASSERT(python_runtime::is_system_python("/usr/bin/python"));
	OAK_ASSERT(python_runtime::is_system_python("/System/Library/Frameworks/Python.framework/Versions/3.9/bin/python3"));
	OAK_ASSERT(python_runtime::is_system_python("/Applications/Xcode.app/Contents/Developer/usr/bin/python3"));
	OAK_ASSERT(python_runtime::is_system_python("/Library/Developer/CommandLineTools/usr/bin/python3"));

	OAK_ASSERT(!python_runtime::is_system_python("/Users/someone/.local/share/uv/python/cpython-3.13/bin/python3.13"));
	OAK_ASSERT(!python_runtime::is_system_python("/opt/homebrew/bin/python3"));
	OAK_ASSERT(!python_runtime::is_system_python(NULL_STR));
}

void test_the_proposed_python_version ()
{
	OAK_ASSERT_EQ(python_runtime::kPinnedVersion, "3.13");
}
