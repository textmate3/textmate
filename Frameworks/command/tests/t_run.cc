#include <command/runner.h>
#include <command/parser.h>
#include <settings/settings.h>
#include <cf/cf.h>
#include <io/entries.h>
#include <io/exec.h>
#include <io/path.h>
#include <io/ruby_runtime.h>
#include <test/jail.h>
#include <OakSystem/application.h>

static std::string as_str (output::type output)
{
	switch(output)
	{
		case output::replace_input:     return "replace_input";
		case output::replace_document:  return "replace_document";
		case output::at_caret:          return "at_caret";
		case output::after_input:       return "after_input";
		case output::new_window:        return "new_window";
		case output::tool_tip:          return "tool_tip";
		case output::discard:           return "discard";
		case output::replace_selection: return "replace_selection";
	}
}

struct delegate_t : command::delegate_t
{
	std::string out, err, html;
	int rc;
	std::string placement;
	output_format::type format;
	output_caret::type caret;

	delegate_t () : out(""), err(""), html(""), rc(-42), placement(as_str(output::discard)) { }

	ng::ranges_t write_unit_to_fd (int fd, input::type unit, input::type fallbackUnit, input_format::type format, scope::selector_t const& scopeSelector, std::map<std::string, std::string>& variables, bool* inputWasSelection)
	{
		close(fd);
		return { };
	}

	bool accept_html_data (command::runner_ptr runner, char const* data, size_t len)
	{
		rc = 0;
		return html.insert(html.end(), data, data + len), true;
	}

	bool accept_result (std::string const& out, output::type placement, output_format::type format, output_caret::type outputCaret, ng::ranges_t const& inputRanges, std::map<std::string, std::string> const& environment)
	{
		this->out       = out;
		this->placement = as_str(placement);
		this->format    = format;
		this->caret     = outputCaret;
		this->rc        = 0;

		fprintf(stderr, "output: ‘%s’\n", out.c_str());
		return true;
	}

	void show_document (std::string const& str)
	{
		out       = str;
		placement = as_str(output::new_window);
		rc        = 0;
	}

	void show_tool_tip (std::string const& str)
	{
		out       = str;
		placement = as_str(output::tool_tip);
		rc        = 0;
	}

	void show_error (bundle_command_t const& command, int rc, std::string const& out, std::string const& err)
	{
		this->out = out;
		this->err = err;
		this->rc  = rc;
	}

	void detach () { }
	void done ()   { }
};

typedef std::shared_ptr<delegate_t> delegate_ptr;

// Runs a command the way the application does, with the basic environment plus any variables given.
// A variable given as NULL_STR is removed, so a test can take away what the application would have set.
static delegate_ptr run_command (std::string const& cmd, std::string const& output = "discard", std::map<std::string, std::string> const& variables = { })
{
	static std::string const bashInit =
		"exit_discard ()               { echo -n \"$1\"; exit 200; }\n"
		"exit_replace_text ()          { echo -n \"$1\"; exit 201; }\n"
		"exit_replace_document ()      { echo -n \"$1\"; exit 202; }\n"
		"exit_insert_text ()           { echo -n \"$1\"; exit 203; }\n"
		"exit_insert_snippet ()        { echo -n \"$1\"; exit 204; }\n"
		"exit_show_html ()             { echo -n \"$1\"; exit 205; }\n"
		"exit_show_tool_tip ()         { echo -n \"$1\"; exit 206; }\n"
		"exit_create_new_document ()   { echo -n \"$1\"; exit 207; }\n"
	;

	plist::dictionary_t plist;
	plist["command"] = cmd.find("#!") == 0 ? cmd : bashInit + cmd;
	plist["name"]    = std::string("Test Command");
	plist["input"]   = std::string("none");
	plist["output"]  = output;

	std::map<std::string, std::string> environment = variables_for_path(oak::basic_environment());
	for(auto const& pair : variables)
	{
		if(pair.second == NULL_STR)
				environment.erase(pair.first);
		else	environment[pair.first] = pair.second;
	}

	delegate_ptr delegate(new delegate_t);
	command::runner_ptr runner = command::runner(parse_command(convert_command_from_v1(plist)), ng::buffer_t(), ng::ranges_t(), environment, delegate);
	runner->launch();
	runner->wait_for_command();
	return delegate;
}

void test_tool_tip ()
{
	delegate_ptr res = run_command("exit_show_tool_tip 'Hello'");
	OAK_ASSERT_EQ(res->placement, as_str(output::tool_tip));
	OAK_ASSERT_EQ(res->out, "Hello");
	OAK_ASSERT_EQ(res->err, "");
	OAK_ASSERT_EQ(res->rc, 0);
}

void test_new_document ()
{
	delegate_ptr res = run_command("exit_create_new_document 'Hello'");
	OAK_ASSERT_EQ(res->placement, as_str(output::new_window));
	OAK_ASSERT_EQ(res->out, "Hello");
	OAK_ASSERT_EQ(res->err, "");
	OAK_ASSERT_EQ(res->rc, 0);
}

void test_html_success ()
{
	delegate_ptr res = run_command("echo >&2 Error && echo Hello && true", "showAsHTML");
	OAK_ASSERT_EQ(res->html, "Hello\nError\n");
	OAK_ASSERT_EQ(res->out, "");
	OAK_ASSERT_EQ(res->err, "");
	OAK_ASSERT_EQ(res->rc, 0);
}

void test_html_error ()
{
	delegate_ptr res = run_command("echo >&2 Error && echo Hello && exit 1", "showAsHTML");
	OAK_ASSERT_EQ(res->html, "Hello\n");
	OAK_ASSERT_EQ(res->out, "");
	OAK_ASSERT_EQ(res->err, "Error\n");
	OAK_ASSERT_EQ(res->rc, 1);
}

// ==============================
// = The Ruby a command runs on =
// ==============================

// A stand in for a Ruby: a link to echo, so the kernel runs it as the shebang's interpreter with the script's path as its argument.
// It has to be a binary, since the kernel refuses a script as another script's interpreter.
// Whatever comes back is what the kernel ran, which is what the rewritten shebang named, and the command's own text is ignored.
static std::string fake_ruby (test::jail_t& jail)
{
	jail.mkdir("bin");
	symlink("/bin/echo", jail.path("bin/ruby").c_str());
	return jail.path("bin/ruby");
}

// echo prints the script's path, which the runner puts the command's name in place of.
static std::string const kFakeRubyOutput = "Test Command\n";

void test_a_ruby_command_runs_on_tm_ruby ()
{
	test::jail_t jail;
	delegate_ptr res = run_command("#!/usr/bin/env ruby\nputs RUBY_VERSION\n", "showAsTooltip", { { "TM_RUBY", fake_ruby(jail) }, { "TM_APPLICATION_RUBY", NULL_STR } });
	OAK_ASSERT_EQ(res->out, kFakeRubyOutput);
	OAK_ASSERT_EQ(res->err, "");
	OAK_ASSERT_EQ(res->rc, 0);
}

void test_a_ruby_command_falls_to_the_applications_ruby ()
{
	test::jail_t jail;
	delegate_ptr res = run_command("#!/usr/bin/ruby\nputs RUBY_VERSION\n", "showAsTooltip", { { "TM_RUBY", NULL_STR }, { "TM_APPLICATION_RUBY", fake_ruby(jail) } });
	OAK_ASSERT_EQ(res->out, kFakeRubyOutput);
	OAK_ASSERT_EQ(res->rc, 0);
}

// A Ruby on this machine that is not the system's, looked for where rv, chruby and Homebrew put theirs.
static std::string a_ruby_that_is_not_the_systems ()
{
	std::vector<std::string> candidates;
	for(std::string const& directory : { path::join(path::home(), ".local/share/rv/rubies"), path::join(path::home(), ".rubies"), std::string("/opt/rubies") })
	{
		for(auto const& entry : path::entries(directory))
			candidates.push_back(path::join(path::join(directory, entry->d_name), "bin/ruby"));
	}
	candidates.push_back("/opt/homebrew/opt/ruby/bin/ruby");
	candidates.push_back("/usr/local/opt/ruby/bin/ruby");

	for(std::string const& ruby : candidates)
	{
		if(access(ruby.c_str(), X_OK) == 0 && !ruby_runtime::is_system_ruby(ruby))
			return ruby;
	}
	return NULL_STR;
}

void test_a_ruby_command_reports_the_version_of_tm_ruby ()
{
	std::string const ruby = a_ruby_that_is_not_the_systems();
	if(ruby == NULL_STR)
	{
		fprintf(stderr, "no Ruby other than the system's on this machine, so the version round trip is not checked\n");
		return;
	}

	std::string const expected = io::exec(ruby, "-e", "print RUBY_VERSION", NULL);
	delegate_ptr res = run_command("#!/usr/bin/env ruby\nprint RUBY_VERSION\n", "showAsTooltip", { { "TM_RUBY", ruby }, { "TM_APPLICATION_RUBY", NULL_STR } });
	OAK_ASSERT_EQ(res->out, expected);
	OAK_ASSERT_EQ(res->err, "");
	OAK_ASSERT_EQ(res->rc, 0);
}

void test_a_ruby_command_with_only_the_system_ruby_does_not_run ()
{
	delegate_ptr res = run_command("#!/usr/bin/env ruby\nputs RUBY_VERSION\n", "showAsTooltip", { { "TM_RUBY", "/usr/bin/ruby" }, { "TM_APPLICATION_RUBY", NULL_STR } });
	OAK_ASSERT_EQ(res->rc, 1);
	OAK_ASSERT_EQ(res->out, "");
	OAK_ASSERT(res->err.find("no Ruby") != std::string::npos);
}
