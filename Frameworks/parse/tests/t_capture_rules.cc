#include "support.h"
#include <test/bundle_index.h>

static bundles::item_ptr CaptureTestGrammarItem;

void setup_fixtures ()
{
	test::bundle_index_t bundleIndex;
	CaptureTestGrammarItem = bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "CaptureTestLanguageGrammar.tmLanguage"));
}

void test_captures ()
{
	auto grammar = parse::parse_grammar(CaptureTestGrammarItem);
	OAK_ASSERT_EQ(markup(grammar, "Lorem ipsum."),                       "«test»Lorem ipsum.«/test»");
	OAK_ASSERT_EQ(markup(grammar, "fixup! Lorem ipsum."),                "«test»«fixup»fixup!«/fixup» Lorem ipsum.«/test»");
	OAK_ASSERT_EQ(markup(grammar, "Lorem ipsum dolor sit amet."),        "«test»«warn»Lorem ipsum dolor sit amet.«/warn»«/test»");
	OAK_ASSERT_EQ(markup(grammar, "fixup! Lorem ipsum dolor sit amet."), "«test»«fixup»«warn»fixup!«/warn»«/fixup»«warn» Lorem ipsum dolor sit amet.«/warn»«/test»");
	OAK_ASSERT_EQ(markup(grammar, "leaking"), "«test»«main»«capture»leak«/capture»«/main»ing«/test»");
}
