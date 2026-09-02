#include "../src/helpers/asset_policy.h"
#include <test/jail.h>

void test_asset_inside_root_is_allowed ()
{
	test::jail_t jail;
	jail.touch("root/style.css");
	jail.touch("root/images/header.png");

	std::vector<std::string> roots = { jail.path("root") };
	OAK_ASSERT(html_output::is_asset_allowed(jail.path("root/style.css"), roots));
	OAK_ASSERT(html_output::is_asset_allowed(jail.path("root/images/header.png"), roots));
}

void test_asset_outside_root_is_refused ()
{
	test::jail_t jail;
	jail.touch("root/style.css");
	jail.touch("elsewhere/secret.txt");

	std::vector<std::string> roots = { jail.path("root") };
	OAK_ASSERT(!html_output::is_asset_allowed(jail.path("elsewhere/secret.txt"), roots));
	OAK_ASSERT(!html_output::is_asset_allowed("/etc/hosts", roots));
}

void test_asset_cannot_climb_out_with_dot_dot ()
{
	test::jail_t jail;
	jail.touch("root/style.css");
	jail.touch("elsewhere/secret.txt");

	std::vector<std::string> roots = { jail.path("root") };
	OAK_ASSERT(!html_output::is_asset_allowed(jail.path("root/../elsewhere/secret.txt"), roots));
}

// A link inside a root is the user's placement, the way a bundle repository
// checked out elsewhere is linked into the bundles directory, so the path is
// judged as written and the link is honored.
void test_symbolic_link_inside_root_is_honored ()
{
	test::jail_t jail;
	jail.touch("root/style.css");
	jail.touch("elsewhere/style.css");
	jail.ln("elsewhere", "root/link");

	std::vector<std::string> roots = { jail.path("root") };
	OAK_ASSERT(html_output::is_asset_allowed(jail.path("root/link/style.css"), roots));
	OAK_ASSERT(!html_output::is_asset_allowed(jail.path("elsewhere/style.css"), roots));
}

void test_root_containment_is_by_path_component ()
{
	test::jail_t jail;
	jail.touch("root/style.css");
	jail.touch("rootling/style.css");

	std::vector<std::string> roots = { jail.path("root") };
	OAK_ASSERT(!html_output::is_asset_allowed(jail.path("rootling/style.css"), roots));
}

void test_any_of_several_roots_admits ()
{
	test::jail_t jail;
	jail.touch("bundles/support/style.css");
	jail.touch("project/notes/pic.png");
	jail.touch("elsewhere/x.png");

	std::vector<std::string> roots = { jail.path("bundles"), NULL_STR, "", jail.path("project") };
	OAK_ASSERT(html_output::is_asset_allowed(jail.path("bundles/support/style.css"), roots));
	OAK_ASSERT(html_output::is_asset_allowed(jail.path("project/notes/pic.png"), roots));
	OAK_ASSERT(!html_output::is_asset_allowed(jail.path("elsewhere/x.png"), roots));
}
