#include <io/rv.h>
#include <io/path.h>

static std::string fixture (std::string const& name)
{
	return path::join(path::join(__FILE__, ".."), "fixtures/rv/" + name);
}

void test_the_first_candidate_that_exists_and_runs_is_the_rv ()
{
	std::vector<std::string> const candidates = { fixture("missing/rv"), fixture("not_executable/rv"), fixture("present/rv"), fixture("also_present/rv") };
	OAK_ASSERT_EQ(rv::executable(candidates), fixture("present/rv"));
}

void test_no_candidate_gives_nothing ()
{
	OAK_ASSERT_EQ(rv::executable({ fixture("missing/rv"), NULL_STR }), NULL_STR);
}

void test_the_series_the_application_asks_for ()
{
	OAK_ASSERT_EQ(rv::kApplicationRubySeries, "4.0");
}
