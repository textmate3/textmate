#include <file/status.h>
#include <test/jail.h>
#include <sys/stat.h>
#include <unistd.h>

// file::status answers whether a path can be written, and if not, why. The
// user-owned cases are built in a temporary directory. The other-owner cases
// use files every macOS install has, since what matters is only that root owns
// them. The read-only volume case mounts a disk image, which takes a moment
// and touches the machine, so it runs only when asked for:
//
//   TM_TEST_READ_ONLY_VOLUME=1 script/test file

void test_status_user_owned ()
{
	if(getuid() == 0)
	{
		OAK_WARN("Skipping file::status user-owned tests: access() ignores permission bits for root");
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

void test_status_other_owner ()
{
	if(getuid() == 0)
	{
		OAK_WARN("Skipping file::status other-owner tests: access() ignores permission bits for root");
		return;
	}

	// /etc belongs to root and is not writable by anyone else. /etc/hosts is
	// mode 0644, so root could write it. /etc/sudoers is mode 0440, so nobody
	// writes it without changing the mode first. /tmp belongs to root but is
	// world writable.
	OAK_ASSERT_EQ(file::status("/etc/hosts"), kFileTestWritableByRoot);
	OAK_ASSERT_EQ(file::status("/etc/sudoers"), kFileTestNotWritable);
	OAK_ASSERT_EQ(file::status("/etc/textmate-file-status-test-does-not-exist"), kFileTestWritableByRoot);
	OAK_ASSERT_EQ(file::status("/tmp/textmate-file-status-test-does-not-exist"), kFileTestWritable);
}

void test_status_read_only_volume ()
{
	if(!getenv("TM_TEST_READ_ONLY_VOLUME"))
	{
		OAK_WARN("Skipping file::status read-only volume test: set TM_TEST_READ_ONLY_VOLUME=1 to mount a disk image for it");
		return;
	}

	test::jail_t jail;
	jail.touch("source/rw.txt");
	jail.mkdir("mount");

	std::string image = jail.path("ro.dmg");
	std::string mount = jail.path("mount");

	std::string create = "hdiutil create -quiet -ov -srcfolder \"" + jail.path("source") + "\" -volname textmate-test-ro \"" + image + "\"";
	OAK_ASSERT_EQ(system(create.c_str()), 0);

	std::string attach = "hdiutil attach -quiet -readonly -nobrowse -mountpoint \"" + mount + "\" \"" + image + "\"";
	OAK_ASSERT_EQ(system(attach.c_str()), 0);

	OAK_ASSERT_EQ(file::status(mount + "/rw.txt"), kFileTestReadOnly);
	OAK_ASSERT_EQ(file::status(mount + "/cr.txt"), kFileTestReadOnly);

	std::string detach = "hdiutil detach -quiet \"" + mount + "\"";
	OAK_ASSERT_EQ(system(detach.c_str()), 0);
}
