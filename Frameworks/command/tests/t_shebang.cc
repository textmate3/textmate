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

void test_unset_or_relative_tm_ruby_leaves_the_shebang ()
{
	std::string command = "#!/usr/bin/env ruby\nputs 1\n";
	command::fix_shebang(&command, NoRuby);
	OAK_ASSERT_EQ(command, "#!/usr/bin/env ruby\nputs 1\n");
	command::fix_shebang(&command, BareRuby);
	OAK_ASSERT_EQ(command, "#!/usr/bin/env ruby\nputs 1\n");
}
