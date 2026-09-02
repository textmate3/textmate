#include <file/status.h>
#include <test/jail.h>
#include <sys/stat.h>
#include <unistd.h>

// The cases a normal user can set up are built in a temporary directory and
// asserted here. Two groups still need privileges the test does not have:
// files owned by root, and a read-only volume. Those are checked only when the
// operator has created them by hand:
//
//   mkdir -p /tmp/x/o_{rw,ro}
//   touch /tmp/x/o_{rw,ro}/{rw,ro}.txt
//   chmod u-w /tmp/x/o_{rw,ro}/ro.txt /tmp/x/o_ro
//   chmod a+w /tmp/x/o_rw
//   sudo chown -R root /tmp/x
//
// and a read-only volume mounted at /Volumes/ro holding rw.txt.

void test_status_user_owned ()
{
	if(getuid() == 0)
	{
		OAK_WARN("Skipping file::status user tests: access() ignores permission bits for root");
		return;
	}

	test::jail_t jail;

	jail.touch("u_rw/rw.txt");
	jail.touch("u_rw/ro.txt");
	jail.touch("u_ro/rw.txt");
	jail.touch("u_ro/ro.txt");

	chmod(jail.path("u_rw/ro.txt").c_str(), 0444);
	chmod(jail.path("u_ro/ro.txt").c_str(), 0444);
	chmod(jail.path("u_ro").c_str(), 0555);

	OAK_ASSERT_EQ(file::status(jail.path("u_cr/cr.txt")), kFileTestNoParent);
	OAK_ASSERT_EQ(file::status(jail.path("u_rw/cr.txt")), kFileTestWritable);
	OAK_ASSERT_EQ(file::status(jail.path("u_rw/rw.txt")), kFileTestWritable);
	OAK_ASSERT_EQ(file::status(jail.path("u_rw/ro.txt")), kFileTestNotWritableButOwner);
	OAK_ASSERT_EQ(file::status(jail.path("u_ro/cr.txt")), kFileTestWritableByRoot);
	OAK_ASSERT_EQ(file::status(jail.path("u_ro/rw.txt")), kFileTestWritable);
	OAK_ASSERT_EQ(file::status(jail.path("u_ro/ro.txt")), kFileTestNotWritableButOwner);

	// The jail removes its tree when it goes out of scope, which needs the
	// directory writable again.
	chmod(jail.path("u_ro").c_str(), 0755);
}

void test_status_root_owned ()
{
	if(access("/tmp/x/o_rw", F_OK) != 0)
	{
		OAK_WARN("Skipping file::status root-owned tests: no /tmp/x fixtures, see the recipe at the top of t_status.cc");
		return;
	}

	OAK_ASSERT_EQ(file::status("/tmp/x/o_rw/cr.txt"), kFileTestWritable);
	OAK_ASSERT_EQ(file::status("/tmp/x/o_rw/rw.txt"), kFileTestWritableByRoot);
	OAK_ASSERT_EQ(file::status("/tmp/x/o_rw/ro.txt"), kFileTestNotWritable);
	OAK_ASSERT_EQ(file::status("/tmp/x/o_ro/cr.txt"), kFileTestWritableByRoot);
	OAK_ASSERT_EQ(file::status("/tmp/x/o_ro/rw.txt"), kFileTestWritableByRoot);
	OAK_ASSERT_EQ(file::status("/tmp/x/o_ro/ro.txt"), kFileTestNotWritable);
}

void test_status_read_only_volume ()
{
	if(access("/Volumes/ro", F_OK) != 0)
	{
		OAK_WARN("Skipping file::status read-only volume tests: nothing mounted at /Volumes/ro");
		return;
	}

	OAK_ASSERT_EQ(file::status("/Volumes/ro/cr.txt"), kFileTestReadOnly);
	OAK_ASSERT_EQ(file::status("/Volumes/ro/rw.txt"), kFileTestReadOnly);
}
