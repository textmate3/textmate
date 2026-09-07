#import "../src/CommonAncestor.h"
#import <ns/ns.h>

// The folder that stands for a set of paths when Find in Project searches the
// file browser's selection. None of these paths exist on disk, so the check
// at the end that steps up from a file to its folder never fires and the
// prefix logic is what is under test.

void test_siblings_share_their_folder ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar/one.rb", @"/foo/bar/two.rb" ])), "/foo/bar");
}

void test_cousins_share_the_folder_above ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar/one.rb", @"/foo/baz/two.rb" ])), "/foo");
}

void test_a_shared_name_prefix_is_not_a_shared_folder ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar", @"/foo/barn" ])), "/foo");
}

void test_nothing_in_common_is_the_root ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/one", @"/bar/two" ])), "/");
}

void test_one_path_is_itself ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar" ])), "/foo/bar");
}

void test_no_paths_is_nothing ()
{
	OAK_ASSERT(CommonAncestor(@[ ]) == nil);
}

// A folder selected together with something inside it. The character walk
// reaches the end of the shorter path without meeting a difference, and the
// last separator it passed is the one before the folder's own name, so today
// the answer is the folder's parent. This test records that.
void test_a_folder_and_something_inside_it_currently_answers_the_parent ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar", @"/foo/bar/baz" ])), "/foo");
}

// What it should answer: the folder itself, since everything selected is in
// it. This fails until the prefix is taken by path component rather than by
// character.
void test_a_folder_and_something_inside_it_should_answer_the_folder ()
{
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar", @"/foo/bar/baz" ])), "/foo/bar");
	OAK_ASSERT_EQ(to_s(CommonAncestor(@[ @"/foo/bar/baz", @"/foo/bar" ])), "/foo/bar");
}
