#include <test/bundle_index.h>

void setup_fixtures ()
{
	test::bundle_index_t bundleIndex;
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "TextLanguageGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "CLanguageGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "XMLPlistGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "RubyLanguageGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "RSpecLanguageGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "CMakeListsLanguageGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "GitConfigGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "ASCIIPlistGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeCommand, test::fixture(__FILE__, "ExportSHA1Command.tmCommand"));
	bundleIndex.commit();
}
