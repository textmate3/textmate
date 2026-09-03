#include <editor/editor.h>
#include <command/runner.h>

void test_replace_selection_command ()
{
	struct delegate_t : command::delegate_t
	{
		delegate_t (ng::editor_t& editor) : _editor(editor) { }

		ng::ranges_t write_unit_to_fd (int fd, input::type unit, input::type fallbackUnit, input_format::type format, scope::selector_t const& scopeSelector, std::map<std::string, std::string>& variables, bool* inputWasSelection) { close(fd); return { }; }

		void show_document (std::string const& str) { }
		void show_tool_tip (std::string const& str) { }
		void show_error (bundle_command_t const& command, int rc, std::string const& out, std::string const& err) { }

		bool accept_result (std::string const& out, output::type placement, output_format::type format, output_caret::type outputCaret, ng::ranges_t const& inputRanges, std::map<std::string, std::string> const& environment)
		{
			return _editor.handle_result(out, placement, format, outputCaret, inputRanges, environment);
		}

	private:
		ng::editor_t& _editor;
	};

	static std::string const plistSrc =
		"{ command = '#!/bin/sh\necho Hello';"
		"  input = 'document';"
		"  output = 'insertAsSnippet';"
		"}";

	ng::buffer_t buf;
	ng::editor_t editor(buf);
	editor.insert("to be replaced");
	editor.perform(ng::kSelectAll);
	editor.execute_dispatch(plist::get_ref<plist::dictionary_t>(plist::parse(plistSrc)), std::map<std::string, std::string>(), [&editor](bundle_command_t const& cmd, ng::buffer_api_t const& buf, ng::ranges_t const& sel, std::map<std::string, std::string> const& env){
		command::runner_ptr runner = command::runner(cmd, buf, sel, env, std::make_shared<delegate_t>(editor));
		runner->launch();
		runner->wait_for_command();
	});
	OAK_ASSERT_EQ(editor.as_string(), "Hello\n");
}

// The caret is carried across a replacement by code point, not by byte, so a
// character that grows from one byte to two keeps the caret on its far side.
void test_caret_carried_by_code_point_across_a_replacement ()
{
	ng::buffer_t buf;
	ng::editor_t editor(buf);
	editor.insert("say a");
	ng::ranges_t line(ng::range_t(0, 5));
	editor.handle_result("say \xC3\xA1", output::replace_input, output_format::text, output_caret::interpolate_by_char, line, std::map<std::string, std::string>());
	OAK_ASSERT_EQ(editor.as_string(), "say \xC3\xA1");
	OAK_ASSERT_EQ(editor.ranges().last().last.index, 6);
}

void test_caret_before_a_replaced_character_stays_before_it ()
{
	ng::buffer_t buf;
	ng::editor_t editor(buf);
	editor.insert("say a");
	editor.perform(ng::kMoveBackward);
	ng::ranges_t line(ng::range_t(0, 5));
	editor.handle_result("say \xC3\xA1", output::replace_input, output_format::text, output_caret::interpolate_by_char, line, std::map<std::string, std::string>());
	OAK_ASSERT_EQ(editor.ranges().last().last.index, 4);
}
