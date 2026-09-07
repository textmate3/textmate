#include <buffer/buffer.h>

// A mark type that ends in a slash names a family.
// Removing "error/" removes "error/syntax" and "error/type" and leaves "bookmark" alone.

void test_remove_all_marks_of_one_type ()
{
	ng::buffer_t buffer("one\ntwo\nthree\n");
	buffer.set_mark(0, "bookmark");
	buffer.set_mark(4, "error/syntax", "unexpected end");
	buffer.set_mark(8, "error/type", "not a number");

	buffer.remove_all_marks("error/syntax");

	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "bookmark").size(), 1);
	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "error/syntax").size(), 0);
	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "error/type").size(), 1);
}

void test_remove_all_marks_of_a_family ()
{
	ng::buffer_t buffer("one\ntwo\nthree\n");
	buffer.set_mark(0, "bookmark");
	buffer.set_mark(4, "error/syntax", "unexpected end");
	buffer.set_mark(8, "error/type", "not a number");

	buffer.remove_all_marks("error/");

	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "bookmark").size(), 1);
	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "error/syntax").size(), 0);
	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "error/type").size(), 0);
}

void test_remove_all_marks_of_a_family_leaves_lookalikes ()
{
	ng::buffer_t buffer("one\ntwo\nthree\n");
	buffer.set_mark(0, "error/syntax");
	buffer.set_mark(4, "errors");
	buffer.set_mark(8, "error");

	buffer.remove_all_marks("error/");

	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "error/syntax").size(), 0);
	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "errors").size(), 1);
	OAK_ASSERT_EQ(buffer.get_marks(0, buffer.size(), "error").size(), 1);
}
