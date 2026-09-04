#include <test/bundle_index.h>
#include <file/type.h>

void setup_fixtures ()
{
	test::bundle_index_t bundleIndex;
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "TextLanguageGrammar.tmLanguage"));
	bundleIndex.add(bundles::kItemTypeGrammar, test::fixture(__FILE__, "CLanguageGrammar.tmLanguage"));
	bundleIndex.commit();
}

void test_file_type ()
{
	std::string path = "/tmp/utf32-be.txt";
	OAK_ASSERT_EQ(file::type_from_path(path), "text.plain");
}

void test_scope_query ()
{
	std::vector<bundles::item_ptr> items = bundles::query(bundles::kFieldGrammarScope, "text.plain");
	OAK_ASSERT_EQ(items.size(), 1);
	OAK_ASSERT_EQ(items[0]->name(), "Plain Text");
}
