#include "support.h"
#include <test/bundle_index.h>

static bundles::item_ptr BeginWhileTestGrammarItem;

void setup_fixtures ()
{
	test::bundle_index_t bundleIndex;
	BeginWhileTestGrammarItem = bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "TestLanguageGrammar.tmLanguage"));
}

void test_begin_while ()
{
	auto grammar = parse::parse_grammar(BeginWhileTestGrammarItem);

	std::string const buf =
		"# Heading\n"
		"\n"
		"> Quoted\n"
		"> \n"
		"> > Double Quoted\n"
		"> >  * First item\n"
		"> >    still first\n"
		"> >  * Second item\n"
		"> >  * Third item\n"
		"> >  * Fourth item\n"
		"> >    \n"
		"> >        Raw _in_ item\n"
		"> >        More raw\n"
		"> >    \n"
		"> >    same _item_.\n"
		"> >    \n"
		"> >    # Heading in _that_ item\n"
		"> > # Heading in quote\n"
		"> Back to _quote_.\n"
		"And normal text.\n"
	;

	std::string const res =
		"«mdown»«hn»# Heading\n"
		"«/hn»\n"
		"«q»> «p»Quoted«/p»\n"
		"> \n"
		"> «q»> «p»Double Quoted«/p»\n"
		"«/q»> «q»> «li» * «p»First item«/p»\n"
		"«/li»«/q»> «q»> «li»   «p»still first«/p»\n"
		"«/li»«/q»> «q»> «li» * «p»Second item«/p»\n"
		"«/li»«/q»> «q»> «li» * «p»Third item«/p»\n"
		"«/li»«/q»> «q»> «li» * «p»Fourth item«/p»\n"
		"«/li»«/q»> «q»> «li»   \n"
		"«/li»«/q»> «q»> «li»   «pre»    Raw _in_ item\n"
		"«/pre»«/li»«/q»> «q»> «li»   «pre»    More raw\n"
		"«/pre»«/li»«/q»> «q»> «li»   \n"
		"«/li»«/q»> «q»> «li»   «p»same «em»_item_«/em».«/p»\n"
		"«/li»«/q»> «q»> «li»   \n"
		"«/li»«/q»> «q»> «li»   «hn»# Heading in «em»_that_«/em» item\n"
		"«/hn»«/li»«/q»> «q»> «hn»# Heading in quote\n"
		"«/hn»«/q»> «p»Back to «em»_quote_«/em».«/p»\n"
		"«/q»«p»And normal text.«/p»\n"
		"«/mdown»"
	;

	OAK_ASSERT_EQ(markup(grammar, buf), res);
	OAK_ASSERT_EQ(markup(grammar, "> _first\n> second_\n> third\nfourth"),       "«mdown»«q»> «p»«em»_first\n> second_«/em»«/p»\n> «p»third«/p»\n«/q»«p»fourth«/p»«/mdown»");
	OAK_ASSERT_EQ(markup(grammar, "> > _first\n> > second_\n> > third\nfourth"), "«mdown»«q»> «q»> «p»«em»_first\n> > second_«/em»«/p»\n«/q»> «q»> «p»third«/p»\n«/q»«/q»«p»fourth«/p»«/mdown»");
}
