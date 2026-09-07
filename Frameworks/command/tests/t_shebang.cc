#include <command/runner.h>

static std::map<std::string, std::string> const NoRuby;
static std::map<std::string, std::string> const AbsoluteRuby = { { "TM_RUBY", "/opt/rubies/ruby-4.0.6/bin/ruby" } };
static std::map<std::string, std::string> const BareRuby     = { { "TM_RUBY", "ruby" } };

void test_missing_shebang_gets_bash ()
{
	std::string command = "echo hi\n";
	command::fix_shebang(&command, NoRuby);
	OAK_ASSERT_EQ(command.substr(0, 11), "#!/bin/bash");
}

void test_env_ruby_follows_tm_ruby ()
{
	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, AbsoluteRuby);
	OAK_ASSERT_EQ(command, "#!/opt/rubies/ruby-4.0.6/bin/ruby\nputs 1\n");
}

void test_path_ruby_follows_tm_ruby_and_keeps_its_flags ()
{
	std::string command = "#!/usr/bin/ruby -wKU\nputs 1\n";
	command::fix_shebang(&command, AbsoluteRuby);
	OAK_ASSERT_EQ(command, "#!/opt/rubies/ruby-4.0.6/bin/ruby -wKU\nputs 1\n");
}

void test_env_ruby_with_flags_keeps_them ()
{
	std::string command = "#!/usr/bin/env ruby -w\nputs 1\n";
	command::fix_shebang(&command, AbsoluteRuby);
	OAK_ASSERT_EQ(command, "#!/opt/rubies/ruby-4.0.6/bin/ruby -w\nputs 1\n");
}

void test_other_interpreters_are_left_alone ()
{
	std::string command = "#!/usr/bin/env python3\nprint(1)\n";
	command::fix_shebang(&command, AbsoluteRuby);
	OAK_ASSERT_EQ(command, "#!/usr/bin/env python3\nprint(1)\n");

	std::string rubyish = "#!/usr/bin/env ruby18\nputs 1\n";
	command::fix_shebang(&rubyish, AbsoluteRuby);
	OAK_ASSERT_EQ(rubyish, "#!/usr/bin/env ruby18\nputs 1\n");
}

static std::map<std::string, std::string> const ApplicationRubyOnly = { { "TM_APPLICATION_RUBY", "/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby" } };
static std::map<std::string, std::string> const SystemRubyOverApplication = { { "TM_RUBY", "/usr/bin/ruby" }, { "TM_APPLICATION_RUBY", "/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby" } };
static std::map<std::string, std::string> const PersonsRubyOverApplication = { { "TM_RUBY", "/opt/rubies/ruby-4.1.0/bin/ruby" }, { "TM_APPLICATION_RUBY", "/Users/someone/.local/share/rv/rubies/ruby-4.0.6/bin/ruby" } };
static std::map<std::string, std::string> const SystemRubyAlone = { { "TM_RUBY", "/usr/bin/ruby" } };

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
	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, PersonsRubyOverApplication);
	OAK_ASSERT_EQ(command, "#!/opt/rubies/ruby-4.1.0/bin/ruby\nputs 1\n");
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
	for(auto const& environment : { NoRuby, BareRuby, SystemRubyAlone })
	{
		std::string command = "#!/usr/bin/env ruby\nputs 1\n";
		command::fix_shebang(&command, environment);
		OAK_ASSERT_EQ(command.substr(0, 9), "#!/bin/sh");
		OAK_ASSERT(command.find("exit 1\n") != std::string::npos);
		OAK_ASSERT(command.find("/usr/bin/env ruby") == std::string::npos);
	}
}

void test_a_command_that_is_not_ruby_is_untouched_even_with_no_ruby ()
{
	std::string command = "#!/usr/bin/env python3\nprint(1)\n";
	command::fix_shebang(&command, NoRuby);
	OAK_ASSERT_EQ(command, "#!/usr/bin/env python3\nprint(1)\n");
}
