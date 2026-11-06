#include "../src/drivers/api.h"
#include <scm/scm.h>
#include <settings/settings.h>
#include <test/jail.h>
#include <io/path.h>
#include <io/exec.h>

void test_basic_status ()
{
	test::jail_t jail;

	std::string const svn = scm::find_executable("svn", "TM_SVN");
	OAK_MASSERT("\n\n  Unable to test subversion driver (svn executable not found).\n\n  To skip this test:\n    ninja scm/coerce\n\n  To install it, the Brewfile lists it:\n    brew bundle\n", svn != NULL_STR);

	std::string const repoName = "tm-test-repo";
	std::string const wcName = "tm-test-wc";
	std::string const jailPath = jail.path();
	std::string const script = std::format("{{ cd '{0}' && '{1}admin' create '{2}' && '{1}' co 'file://{0}/{2}' {3} && cd '{3}' && touch {{clean,ignored,modified,added,missing,untracked}}.txt && '{1}' propset svn:ignore 'ignored.txt' . && '{1}' add {{clean,modified,missing}}.txt && '{1}' commit -m 'Initial commit' && '{1}' add added.txt && '{1}' rm missing.txt && echo foo > modified.txt; }} >/dev/null", jailPath.c_str(), svn.c_str(), repoName.c_str(), wcName.c_str());

	if(io::exec("/bin/sh", "-c", script.c_str(), nullptr) == NULL_STR)
		OAK_FAIL("error in setup: " + script);

	if(auto info = scm::info(jail.path(wcName)))
	{
		wait_for_status(info);

		std::string expectedBranch = std::format("file://{}/{}", jailPath.c_str(), repoName.c_str());

		auto vars = info->scm_variables();
		OAK_ASSERT_EQ(vars["TM_SCM_NAME"],   "svn");
		OAK_ASSERT_EQ(vars["TM_SCM_BRANCH"], expectedBranch);

		OAK_ASSERT_EQ(info->status(jail.path(path::join(wcName, "clean.txt"))),     scm::status::none);
		OAK_ASSERT_EQ(info->status(jail.path(path::join(wcName, "ignored.txt"))),   scm::status::ignored);
		OAK_ASSERT_EQ(info->status(jail.path(path::join(wcName, "modified.txt"))),  scm::status::modified);
		OAK_ASSERT_EQ(info->status(jail.path(path::join(wcName, "added.txt"))),     scm::status::added);
		OAK_ASSERT_EQ(info->status(jail.path(path::join(wcName, "missing.txt"))),   scm::status::deleted);
		OAK_ASSERT_EQ(info->status(jail.path(path::join(wcName, "untracked.txt"))), scm::status::unversioned);
	}
	else
	{
		OAK_FAIL("error getting wc: " + jailPath);
	}
}
