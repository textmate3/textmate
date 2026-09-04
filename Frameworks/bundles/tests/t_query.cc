#include <bundles/bundles.h>
#include <test/bundle_index.h>
#include <test/jail.h>

void setup_fixtures ()
{
	test::bundle_index_t bundleIndex;
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "BaseEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "BaseCommentEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "PathEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "DialogEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "TeXEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "CxxEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSettings, test::fixture(__FILE__, "RubyCommentEnvironment.tmPreferences"));
	bundleIndex.add(bundles::kItemTypeSnippet,  test::fixture(__FILE__, "BaseSnippet.tmSnippet"));
	bundleIndex.add(bundles::kItemTypeSnippet,  test::fixture(__FILE__, "CxxSnippet.tmSnippet"));
	bundleIndex.add(bundles::kItemTypeSnippet,  test::fixture(__FILE__, "DisabledCxxSnippet.tmSnippet"));

	bundleIndex.add(bundles::kItemTypeCommand,  test::fixture(__FILE__, "TrueWithLocation.tmCommand"));
	bundleIndex.add(bundles::kItemTypeCommand,  test::fixture(__FILE__, "TrueWithVariable.tmCommand"));
	bundleIndex.add(bundles::kItemTypeCommand,  test::fixture(__FILE__, "TrueWithLocationAndVariable.tmCommand"));
	bundleIndex.add(bundles::kItemTypeCommand,  test::fixture(__FILE__, "TrueWithBadLocation.tmCommand"));
	bundleIndex.add(bundles::kItemTypeCommand,  test::fixture(__FILE__, "TrueWithBadLocationAndVariable.tmCommand"));

	bundles::item_ptr dialogBundle = bundleIndex.add(bundles::kItemTypeBundle, plist::dictionary_t{ { "name", std::string("Dialog") }, { "uuid", std::string("B0B94C92-1870-491C-A928-9528387EEACA") } });

	static test::jail_t jail;
	bundles::set_locations(std::vector<std::string>(1, jail.path()));
	dialogBundle->save();
	jail.mkdir("Bundles/Dialog.tmbundle/Support");

	bundleIndex.commit();
}

#define OAK_ASSERT_STR_EQ(lhs, rhs) do { std::string _lhs = (lhs); std::string _rhs = (rhs); if(!(_lhs == _rhs)) oak_assertion_error(oak_format_bad_relation(#lhs, "==", #rhs, to_s(_lhs), "!=", to_s(_rhs)), __FILE__, __LINE__); } while(false)

void test_environment_format_strings ()
{
	std::map<std::string, std::string> base;

	OAK_ASSERT_EQ(bundles::scope_variables(base, "")["TEST"],                        "foo");
	OAK_ASSERT_EQ(bundles::scope_variables(base, "source.c++")["TEST"],              "foo:bar");
	OAK_ASSERT_EQ(bundles::scope_variables(base, "source.any")["TM_COMMENT_STYLE"],  "Base Environment");
	OAK_ASSERT_EQ(bundles::scope_variables(base, "source.ruby")["TM_COMMENT_STYLE"], "Ruby Environment");

	OAK_ASSERT_EQ(bundles::scope_variables(base, "text.plain")["PATH"], "/usr/bin:/bin:/sbin");
	OAK_ASSERT_EQ(bundles::scope_variables(base, "text.tex").find("PATH")->second,   "/usr/bin:/bin:/sbin:/usr/texbin");
	OAK_ASSERT_EQ(bundles::scope_variables(base, "text.tex")["PATH"], "/usr/bin:/bin:/sbin:/usr/texbin");
}

void test_v1_variable_shadowing ()
{
	auto baseEnv = bundles::scope_variables(std::map<std::string, std::string>(), "");
	OAK_ASSERT_EQ(baseEnv["TM_COMMENT_START"],   "/*");
	OAK_ASSERT_EQ(baseEnv["TM_COMMENT_STOP"],    "*/");
	OAK_ASSERT_EQ(baseEnv["TM_COMMENT_START_2"], "//");
	OAK_ASSERT(baseEnv.find("TM_COMMENT_STOP_2") == baseEnv.end());

	std::map<std::string, std::string> rubyEnv = bundles::scope_variables(std::map<std::string, std::string>(), "source.ruby");
	OAK_ASSERT_EQ(rubyEnv["TM_COMMENT_START"],   "# ");
	OAK_ASSERT(rubyEnv.find("TM_COMMENT_STOP") == rubyEnv.end());
	OAK_ASSERT_EQ(rubyEnv["TM_COMMENT_START_2"], "==begin");
	OAK_ASSERT_EQ(rubyEnv["TM_COMMENT_STOP_2"],  "==end");
}

void test_scope_query ()
{
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldKeyEquivalent, "^p", "source.c++").size(), 1);
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldKeyEquivalent, "^p", "source.c++", bundles::kItemTypeMenuTypes, oak::uuid_t(), false).size(), 2);
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldKeyEquivalent, "^p", "source.c++", bundles::kItemTypeMenuTypes, oak::uuid_t(), false, true).size(), 3);

	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.any").size(), 1);
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.any").front()->name(), "Base Snippet");
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.c++").size(), 1);
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.c++").front()->name(), "C++ Snippet");

	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.c++", bundles::kItemTypeMenuTypes, oak::uuid_t(), false).size(), 2);
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.c++", bundles::kItemTypeMenuTypes, oak::uuid_t(), false).front()->name(), "C++ Snippet");
	OAK_ASSERT_EQ(bundles::query(bundles::kFieldTabTrigger, "bla", "source.c++", bundles::kItemTypeMenuTypes, oak::uuid_t(), false).back()->name(),  "Base Snippet");
}

void test_require ()
{
	std::string dialogPath = bundles::scope_variables(std::map<std::string, std::string>(), "text")["DialogPath"];
	std::string pathSuffix = "/Bundles/Dialog.tmbundle/Support/bin";
	OAK_ASSERT_EQ(dialogPath.find(pathSuffix) + pathSuffix.size(), dialogPath.size());
}
