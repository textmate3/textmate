#include "support.h"
#include <test/bundle_index.h>

static bundles::item_ptr AnchorTestGrammarItem;
static bundles::item_ptr AnchorInCapturesTestGrammarItem;

void setup_fixtures ()
{
	test::bundle_index_t bundleIndex;
	AnchorTestGrammarItem           = bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "AnchorTestLanguageGrammar.tmLanguage"));
	AnchorInCapturesTestGrammarItem = bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "AnchorInCapturesTestLanguageGrammar.tmLanguage"));
}

void test_anchors ()
{
	auto grammar = parse::parse_grammar(AnchorTestGrammarItem);

	OAK_ASSERT_EQ(markup(grammar, "xy xy\nxy xy\n[xy xy\nxy xy]\nxy xy"), "«test»«bof»xy«/bof» xy\nxy xy\n[«bom»xy«/bom» xy\nxy xy]\nxy «eof»xy«/eof»«/test»");
	OAK_ASSERT_EQ(markup(grammar, "xy xy"),                               "«test»«bof»xy«/bof» «eof»xy«/eof»«/test»");
	OAK_ASSERT_EQ(markup(grammar, "xy xy\n"),                             "«test»«bof»xy«/bof» xy\n«/test»");
	OAK_ASSERT_EQ(markup(grammar, "[xy xy]"),                             "«test»[«bom»xy«/bom» xy]«/test»");
}

void test_anchor_in_captures ()
{
	auto grammar = parse::parse_grammar(AnchorInCapturesTestGrammarItem);
	OAK_ASSERT_EQ(markup(grammar, "foo\n"),        "«test»«head»«b-buf»foo«/b-buf»«/head»\n«/test»");
	OAK_ASSERT_EQ(markup(grammar, "> foo\n"),      "«test»«gt»> «b-cap»foo«/b-cap»«/gt»\n«/test»");
	OAK_ASSERT_EQ(markup(grammar, "foo <\n"),      "«test»«lt»«b-buf»foo«/b-buf» <«/lt»\n«/test»");
	OAK_ASSERT_EQ(markup(grammar, "\nfoo\n"),      "«test»\n«line»«b-line»foo«/b-line»«/line»\n«/test»");
	OAK_ASSERT_EQ(markup(grammar, "\nfoo"),        "«test»\n«tail»«b-line»foo«/b-line»«/tail»«/test»");
	OAK_ASSERT_EQ(markup(grammar, "\nfoo bar"),    "«test»\n«tail»«b-line»foo«/b-line» «e-buf»bar«/e-buf»«/tail»«/test»");

	// OAK_ASSERT_EQ(markup(grammar, "foo bar\n"),    "«test»«head»«b-buf»foo«/b-buf» «e-line»bar«/e-line»«/head»\n«/test»");
	// OAK_ASSERT_EQ(markup(grammar, "> foo bar\n"),  "«test»«gt»> «b-cap»foo«/b-cap» «e-line»bar«/e-line»«/gt»\n«/test»");
	// OAK_ASSERT_EQ(markup(grammar, "foo bar <\n"),  "«test»«lt»«b-buf»foo«/b-buf» «e-cap»bar«/e-cap» <«/lt»\n«/test»");
	// OAK_ASSERT_EQ(markup(grammar, "\nfoo bar\n"),  "«test»\n«line»«b-line»foo«/b-line» «e-line»bar«/e-line»«/line»\n«/test»");
}
