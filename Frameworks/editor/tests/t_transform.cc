#include "../src/transform.h"

void test_transform ()
{
	OAK_ASSERT_EQ("dørgelbÆ",        transform::transpose("Æblegrød"));
	OAK_ASSERT_EQ("dørgelbÆ\n",      transform::transpose("Æblegrød\n"));
	OAK_ASSERT_EQ("bar, foo",        transform::transpose("foo, bar"));
	OAK_ASSERT_EQ("bar, (foo)",      transform::transpose("(foo), bar"));
	OAK_ASSERT_EQ("(bar), foo",      transform::transpose("foo, (bar)"));
	OAK_ASSERT_EQ("(bar, foo)",      transform::transpose("(foo, bar)"));
	OAK_ASSERT_EQ("bar + foo",       transform::transpose("foo + bar"));
	OAK_ASSERT_EQ("'bar', 'foo'",    transform::transpose("'foo', 'bar'"));
	OAK_ASSERT_EQ("bar() : foo()",   transform::transpose("foo() : bar()"));
	OAK_ASSERT_EQ("('bar', 'foo')",  transform::transpose("('foo', 'bar')"));
	OAK_ASSERT_EQ("bar < foo",       transform::transpose("foo < bar"));
	OAK_ASSERT_EQ("bar <= foo",      transform::transpose("foo <= bar"));
	OAK_ASSERT_EQ("bar == foo",      transform::transpose("foo == bar"));
	OAK_ASSERT_EQ("bar != foo",      transform::transpose("foo != bar"));
	OAK_ASSERT_EQ("bar > foo",       transform::transpose("foo > bar"));
	OAK_ASSERT_EQ("bar >= foo",      transform::transpose("foo >= bar"));
}

// Reversed a grapheme at a time, so a combining accent stays on its letter
// and a wide character's three bytes stay in order.
void test_transpose_keeps_graphemes_whole ()
{
	OAK_ASSERT_EQ("e\xCC\x81" "fac",                transform::transpose("cafe\xCC\x81"));
	OAK_ASSERT_EQ("\xE6\x9C\xAC\xE6\x97\xA5",       transform::transpose("\xE6\x97\xA5\xE6\x9C\xAC"));
}
