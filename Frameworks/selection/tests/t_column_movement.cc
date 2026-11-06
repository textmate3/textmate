#include <buffer/buffer.h>
#include <selection/selection.h>

void test_column_movement ()
{
	ng::buffer_t buf(
		"  lorem\n"  // 1:  0-08
		"  sit\n"    // 2:  8-14
		"  ipsum\n"  // 3: 14-22
		"\n"         // 4: 22-23
		"  dollar\n" // 5: 23-32
		"  it\n"     // 6: 32-37
	);

	OAK_ASSERT_EQ(ng::to_s(buf, ng::move(buf, ng::ranges_t( 2), kSelectionMoveToEndOfColumn)), "3:3");
	OAK_ASSERT_EQ(ng::to_s(buf, ng::move(buf, ng::ranges_t( 5), kSelectionMoveToEndOfColumn)), "3:6");
	OAK_ASSERT_EQ(ng::to_s(buf, ng::move(buf, ng::ranges_t( 7), kSelectionMoveToEndOfColumn)), "3:8");
	OAK_ASSERT_EQ(ng::to_s(buf, ng::move(buf, ng::ranges_t(21), kSelectionMoveToEndOfColumn)), "5:8");
}

// Up and down keep the caret's column, counting a wide character as two
// columns and a letter with a combining accent as one.
void test_column_movement_over_wide_and_decomposed_characters ()
{
	ng::buffer_t buf(
		"\xE6\x97\xA5\xE6\x9C\xAC" "x\n" // 1:  0-08, two wide characters, x at column 4
		"abcdef\n"                       // 2:  8-15
		"cafe\xCC\x81g\n"                // 3: 15-23, e and a combining accent
	);

	OAK_ASSERT_EQ(ng::move(buf, ng::ranges_t( 6), kSelectionMoveDown).last().last.index, 12); // column 4, after the wide characters, to d|e
	OAK_ASSERT_EQ(ng::move(buf, ng::ranges_t(12), kSelectionMoveUp).last().last.index,    6); // and back
	OAK_ASSERT_EQ(ng::move(buf, ng::ranges_t(13), kSelectionMoveDown).last().last.index, 22); // column 5, to after the g
	OAK_ASSERT_EQ(ng::move(buf, ng::ranges_t(21), kSelectionMoveUp).last().last.index,   12); // column 4, before the g, to d|e
}
