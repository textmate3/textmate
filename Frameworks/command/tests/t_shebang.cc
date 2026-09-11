#include <command/runner.h>
#include <test/jail.h>

static std::map<std::string, std::string> const NoRuby;
static std::map<std::string, std::string> const BareRuby     = { { "TM_RUBY", "ruby" } };
static std::map<std::string, std::string> const MissingRuby  = { { "TM_RUBY", "/opt/rubies/ruby-4.0.6/bin/ruby" } };

// A TM_RUBY is honored only when something runnable is at the path, so a test
// that expects one honored needs a real file rather than a plausible path.
// A link to a binary is enough, since nothing here runs it.
static std::string a_ruby_that_is_there (test::jail_t& jail)
{
	jail.mkdir("bin");
	symlink("/bin/echo", jail.path("bin/ruby").c_str());
	return jail.path("bin/ruby");
}

static std::map<std::string, std::string> tm_ruby (std::string const& ruby)
{
	return { { "TM_RUBY", ruby } };
}

void test_missing_shebang_gets_bash ()
{
	std::string command = "echo hi\n";
	command::fix_shebang(&command, NoRuby);
	OAK_ASSERT_EQ(command.substr(0, 11), "#!/bin/bash");
}

void test_env_ruby_follows_tm_ruby ()
{
	test::jail_t jail;
	std::string const ruby = a_ruby_that_is_there(jail);

	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, tm_ruby(ruby));
	OAK_ASSERT_EQ(command, "#!" + ruby + "\nputs 1\n");
}

void test_path_ruby_follows_tm_ruby_and_keeps_its_flags ()
{
	test::jail_t jail;
	std::string const ruby = a_ruby_that_is_there(jail);

	std::string command = "#!/usr/bin/ruby -wKU\nputs 1\n";
	command::fix_shebang(&command, tm_ruby(ruby));
	OAK_ASSERT_EQ(command, "#!" + ruby + " -wKU\nputs 1\n");
}

void test_env_ruby_with_flags_keeps_them ()
{
	test::jail_t jail;
	std::string const ruby = a_ruby_that_is_there(jail);

	std::string command = "#!/usr/bin/env ruby -w\nputs 1\n";
	command::fix_shebang(&command, tm_ruby(ruby));
	OAK_ASSERT_EQ(command, "#!" + ruby + " -w\nputs 1\n");
}

void test_other_interpreters_are_left_alone ()
{
	test::jail_t jail;
	std::map<std::string, std::string> const environment = tm_ruby(a_ruby_that_is_there(jail));

	// A language the application finds no runtime for is left exactly as it is.
	// Python used to be one of these and is not any more, which is the point of
	// the Python half of this file.
	std::string command = "#!/usr/bin/env perl\nprint 1\n";
	command::fix_shebang(&command, environment);
	OAK_ASSERT_EQ(command, "#!/usr/bin/env perl\nprint 1\n");

	std::string rubyish = "#!/usr/bin/env ruby18\nputs 1\n";
	command::fix_shebang(&rubyish, environment);
	OAK_ASSERT_EQ(rubyish, "#!/usr/bin/env ruby18\nputs 1\n");
}

static std::map<std::string, std::string> const ApplicationRubyOnly = { { "TM_APPLICATION_RUBY", "/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby" } };
static std::map<std::string, std::string> const SystemRubyOverApplication = { { "TM_RUBY", "/usr/bin/ruby" }, { "TM_APPLICATION_RUBY", "/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby" } };
static std::map<std::string, std::string> const SystemRubyAlone = { { "TM_RUBY", "/usr/bin/ruby" } };
static std::map<std::string, std::string> const MissingRubyOverApplication = { { "TM_RUBY", "/opt/rubies/ruby-4.0.6/bin/ruby" }, { "TM_APPLICATION_RUBY", "/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby" } };

void test_unset_or_relative_tm_ruby_falls_to_the_applications_ruby ()
{
	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, ApplicationRubyOnly);
	OAK_ASSERT_EQ(command, "#!/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby\nputs 1\n");

	std::string bare = "#!/usr/bin/env ruby\nputs 1\n";
	std::map<std::string, std::string> bareOverApplication = ApplicationRubyOnly;
	bareOverApplication["TM_RUBY"] = "ruby";
	command::fix_shebang(&bare, bareOverApplication);
	OAK_ASSERT_EQ(bare, "#!/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby\nputs 1\n");
}

void test_the_persons_tm_ruby_wins_over_the_applications ()
{
	test::jail_t jail;
	std::map<std::string, std::string> environment = ApplicationRubyOnly;
	environment["TM_RUBY"] = a_ruby_that_is_there(jail);

	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, environment);
	OAK_ASSERT_EQ(command, "#!" + environment["TM_RUBY"] + "\nputs 1\n");
}

void test_a_tm_ruby_with_nothing_at_it_falls_to_the_applications ()
{
	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, MissingRubyOverApplication);
	OAK_ASSERT_EQ(command, "#!/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby\nputs 1\n");
}

void test_a_tm_ruby_that_is_a_directory_is_refused_like_one_that_is_absent ()
{
	test::jail_t jail;
	jail.mkdir("rubies/ruby-4.0.6/bin");

	std::map<std::string, std::string> environment = ApplicationRubyOnly;
	environment["TM_RUBY"] = jail.path("rubies/ruby-4.0.6/bin");

	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, environment);
	OAK_ASSERT_EQ(command, "#!/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby\nputs 1\n");
}

void test_the_system_ruby_is_refused_in_favor_of_the_applications ()
{
	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, SystemRubyOverApplication);
	OAK_ASSERT_EQ(command, "#!/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby\nputs 1\n");

	std::string byPath = "#!/usr/bin/ruby -w\nputs 1\n";
	command::fix_shebang(&byPath, SystemRubyOverApplication);
	OAK_ASSERT_EQ(byPath, "#!/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby -w\nputs 1\n");
}

void test_with_no_ruby_at_all_the_command_refuses_to_run_rather_than_reach_the_system ()
{
	for(auto const& environment : { NoRuby, BareRuby, SystemRubyAlone, MissingRuby })
	{
		std::string command = "#!/usr/bin/env ruby\nputs 1\n";
		command::fix_shebang(&command, environment);
		OAK_ASSERT_EQ(command.substr(0, 9), "#!/bin/sh");
		OAK_ASSERT(command.find("exit 1\n") != std::string::npos);
		OAK_ASSERT(command.find("/usr/bin/env ruby") == std::string::npos);
	}
}

void test_a_command_in_an_unmanaged_language_is_untouched_even_with_no_runtime ()
{
	std::string command = "#!/usr/bin/env perl\nprint 1\n";
	command::fix_shebang(&command, NoRuby);
	OAK_ASSERT_EQ(command, "#!/usr/bin/env perl\nprint 1\n");
}

void test_a_shebang_spelling_out_the_system_framework_ruby_is_rewritten ()
{
	test::jail_t jail;
	std::string const ruby = a_ruby_that_is_there(jail);
	std::map<std::string, std::string> const environment = tm_ruby(ruby);

	std::string command = "#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby\nputs 1\n";
	command::fix_shebang(&command, environment);
	OAK_ASSERT_EQ(command, "#!" + ruby + "\nputs 1\n");

	std::string current = "#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby -w\nputs 1\n";
	command::fix_shebang(&current, environment);
	OAK_ASSERT_EQ(current, "#!" + ruby + " -w\nputs 1\n");

	std::string trailingSpace = "#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby \nputs 1\n";
	command::fix_shebang(&trailingSpace, environment);
	OAK_ASSERT_EQ(trailingSpace, "#!" + ruby + " \nputs 1\n");

	std::string withNoRuby = "#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby\nputs 1\n";
	command::fix_shebang(&withNoRuby, NoRuby);
	OAK_ASSERT_EQ(withNoRuby.substr(0, 9), "#!/bin/sh");
	OAK_ASSERT(withNoRuby.find("Ruby.framework") == std::string::npos);
}

// ================================
// = The Python side, same shape =
// ================================

static std::map<std::string, std::string> const ApplicationPythonOnly = { { "TM_APPLICATION_PYTHON", "/Users/someone/.local/share/uv/python/cpython-3.13/bin/python3.13" } };

static std::map<std::string, std::string> tm_python (std::string const& python)
{
	return { { "TM_PYTHON", python } };
}

void test_every_python_spelling_follows_tm_python ()
{
	test::jail_t jail;
	std::string const python = a_ruby_that_is_there(jail);
	std::map<std::string, std::string> const environment = tm_python(python);

	for(std::string const& spelling : { "/usr/bin/env python", "/usr/bin/env python3", "/usr/bin/python", "/usr/bin/python3", "/usr/bin/env python3.9" })
	{
		std::string command = "#!" + spelling + "\nprint(1)\n";
		command::fix_shebang(&command, environment);
		OAK_MASSERT_EQ(spelling.c_str(), command, "#!" + python + "\nprint(1)\n");
	}
}

void test_a_python_shebang_keeps_its_flags ()
{
	test::jail_t jail;
	std::string const python = a_ruby_that_is_there(jail);

	std::string command = "#!/usr/bin/env python3 -u\nprint(1)\n";
	command::fix_shebang(&command, tm_python(python));
	OAK_ASSERT_EQ(command, "#!" + python + " -u\nprint(1)\n");
}

void test_the_system_python_is_refused_in_favor_of_the_applications ()
{
	std::map<std::string, std::string> environment = ApplicationPythonOnly;
	environment["TM_PYTHON"] = "/usr/bin/python3";

	std::string command = "#!/usr/bin/env python3\nprint(1)\n";
	command::fix_shebang(&command, environment);
	OAK_ASSERT_EQ(command, "#!/Users/someone/.local/share/uv/python/cpython-3.13/bin/python3.13\nprint(1)\n");
}

void test_a_tm_python_with_nothing_at_it_falls_to_the_applications ()
{
	std::map<std::string, std::string> environment = ApplicationPythonOnly;
	environment["TM_PYTHON"] = "/opt/pythons/cpython-3.13/bin/python3";

	std::string command = "#!/usr/bin/env python3\nprint(1)\n";
	command::fix_shebang(&command, environment);
	OAK_ASSERT_EQ(command, "#!/Users/someone/.local/share/uv/python/cpython-3.13/bin/python3.13\nprint(1)\n");
}

void test_with_no_python_the_command_refuses_to_run_rather_than_reach_the_system ()
{
	std::string command = "#!/usr/bin/env python3\nprint(1)\n";
	command::fix_shebang(&command, NoRuby);
	OAK_ASSERT_EQ(command.substr(0, 9), "#!/bin/sh");
	OAK_ASSERT(command.find("no Python for bundle commands") != std::string::npos);
	OAK_ASSERT(command.find("/usr/bin/env python3") == std::string::npos);
}

// A Ruby command with a Python set, and the reverse, so neither language's
// answer can ever land in the other's shebang.
void test_one_language_never_answers_for_the_other ()
{
	test::jail_t jail;
	std::string const interpreter = a_ruby_that_is_there(jail);

	std::string rubyCommand = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&rubyCommand, tm_python(interpreter));
	OAK_ASSERT_EQ(rubyCommand.substr(0, 9), "#!/bin/sh");
	OAK_ASSERT(rubyCommand.find("no Ruby for bundle commands") != std::string::npos);

	std::string pythonCommand = "#!/usr/bin/env python3\nprint(1)\n";
	command::fix_shebang(&pythonCommand, tm_ruby(interpreter));
	OAK_ASSERT_EQ(pythonCommand.substr(0, 9), "#!/bin/sh");
	OAK_ASSERT(pythonCommand.find("no Python for bundle commands") != std::string::npos);
}
