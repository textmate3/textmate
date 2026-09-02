#include <buffer/buffer.h>
#include <selection/selection.h>

static std::string const Family = "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6";
static std::string const DecomposedE = "e\xCC\x81";

static size_t caret_after (ng::buffer_t const& buf, size_t caret, move_unit_type unit)
{
	return ng::move(buf, ng::ranges_t(caret), unit).first().min().index;
}

void test_caret_crosses_a_family_emoji_in_one_step ()
{
	ng::buffer_t buf(("a" + Family + "b").c_str());
	OAK_ASSERT_EQ(caret_after(buf, 1, kSelectionMoveRight), 1 + Family.size());
	OAK_ASSERT_EQ(caret_after(buf, 1 + Family.size(), kSelectionMoveLeft), 1);
}

void test_caret_crosses_a_decomposed_accent_in_one_step ()
{
	ng::buffer_t buf(("caf" + DecomposedE + "\n").c_str());
	OAK_ASSERT_EQ(caret_after(buf, 3, kSelectionMoveRight), 3 + DecomposedE.size());
	OAK_ASSERT_EQ(caret_after(buf, 3 + DecomposedE.size(), kSelectionMoveLeft), 3);
}

void test_caret_still_crosses_line_ends_one_byte_at_a_time ()
{
	ng::buffer_t buf("ab\ncd");
	OAK_ASSERT_EQ(caret_after(buf, 2, kSelectionMoveRight), 3);
	OAK_ASSERT_EQ(caret_after(buf, 3, kSelectionMoveLeft), 2);
}

void test_extend_selection_uses_the_same_steps ()
{
	ng::buffer_t buf(("a" + Family + "b").c_str());
	ng::ranges_t res = ng::extend(buf, ng::ranges_t(ng::range_t(1, 1)), kSelectionExtendRight);
	OAK_ASSERT_EQ(res.first().max().index, 1 + Family.size());
}
