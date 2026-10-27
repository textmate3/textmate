#include <test/jail.h>
#include <io/events.h>
#include <condition_variable>
#include <mutex>

#ifndef BSTR
#define BSTR(b) ((b)?"YES":"NO")
#endif

// The watcher calls back on the main queue, while the test runs on a worker
// thread of the runner, so what the two share is behind a mutex, and the test
// waits on a condition rather than spinning. A spin on an unguarded set is
// what used to be here, and it corrupted the set now and then: a hang when a
// path was lost, or a crash on whichever thread touched the broken tree, the
// main thread's crash being the one the runner reported as no test running.
struct callback_t : fs::event_callback_t
{
	callback_t (test::jail_t const& jail, bool log = false) : _jail(jail), _in_replay(false), _log(log) { }
	void set_replaying_history (bool flag, std::string const& observedPath, uint64_t eventId) { _in_replay = flag; }

	void did_change (std::string const& path, std::string const& observedPath, uint64_t eventId, bool recursive)
	{
		std::lock_guard<std::mutex> lock(_mutex);

		if(_log)
			fprintf(stderr, "\t%s, allowed %s, must see %s\n", path::relative_to(path, _jail.path()).c_str(), BSTR(_allowed.find(path) != _allowed.end()), BSTR(_must_see.find(path) != _must_see.end()));

		OAK_MASSERT(path::relative_to(path, _jail.path()).c_str(), _allowed.find(path) != _allowed.end());

		_must_see.erase(path);
		if(_must_see.empty())
			_seen_it_all.notify_all();
	}

	void allowed (char const* firstPath, ...)
	{
		std::lock_guard<std::mutex> lock(_mutex);
		va_list ap;
		va_start(ap, firstPath);
		do {
			_allowed.insert(_jail.path(firstPath));
		} while(firstPath = va_arg(ap, char const*));
		va_end(ap);
	}

	void must_see (char const* firstPath, ...)
	{
		std::lock_guard<std::mutex> lock(_mutex);
		va_list ap;
		va_start(ap, firstPath);
		do {
			_must_see.insert(_jail.path(firstPath));
			_allowed.insert(_jail.path(firstPath));
		} while(firstPath = va_arg(ap, char const*));
		va_end(ap);
	}

	void event_loop (std::string const& observedPath)
	{
		std::unique_lock<std::mutex> lock(_mutex);

		if(_log)
		{
			fprintf(stderr, "observing ‘%s’\n", observedPath.c_str());
			for(auto const& path : _must_see)
				fprintf(stderr, "\tmust see: %s\n", path::relative_to(path, _jail.path()).c_str());
			fprintf(stderr, "waiting for events:\n");
		}

		while(!_must_see.empty())
		{
			if(_seen_it_all.wait_for(lock, std::chrono::seconds(5)) == std::cv_status::timeout)
			{
				for(auto const& path : _must_see)
					fprintf(stderr, "*** waiting: %s\n", path::relative_to(path, _jail.path()).c_str());
			}
		}

		if(_log)
			fprintf(stderr, "seen it all\n\n");
	}

	// A callback that is running on the main queue when the test unwatches
	// would go on into a jail the test has removed, so the test waits for the
	// main queue to come around before its jail and this callback go.
	static void drain_main_queue ()
	{
		dispatch_sync(dispatch_get_main_queue(), ^{ });
	}

private:
	test::jail_t const& _jail;
	std::mutex _mutex;
	std::condition_variable _seen_it_all;
	std::set<std::string> _must_see, _allowed;
	bool _in_replay, _log;
};

void test_simple ()
{
	test::jail_t jail;
	callback_t cb(jail/*, true*/);
	cb.must_see("foo/bar", "foo/bar/baz/fud", nullptr);
	cb.allowed("", "foo", "foo/bar/baz", nullptr);

	fs::watch(jail.path(), &cb, FSEventsGetCurrentEventId(), 0.1);
	jail.touch("foo/bar/baz/fud/dummy.txt");
	jail.touch("foo/bar/dummy.txt");
	cb.event_loop("");

	fs::unwatch(jail.path(), &cb);
	callback_t::drain_main_queue();
}

void test_file_watch ()
{
	test::jail_t jail;
	callback_t cb(jail/*, true*/);
	cb.must_see("foo/bar/dummy.txt", nullptr);

	jail.touch("foo/bar/dummy.txt");
	fs::watch(jail.path("foo/bar/dummy.txt"), &cb, FSEventsGetCurrentEventId(), 0.1);
	sleep(1);

	jail.touch("foo/dummy.txt");
	jail.touch("foo/bar/dummy.txt");
	jail.touch("foo/bar/other.txt");
	cb.event_loop("foo/bar/dummy.txt");

	fs::unwatch(jail.path("foo/bar/dummy.txt"), &cb);
	callback_t::drain_main_queue();
}

void test_initially_missing ()
{
	test::jail_t jail;
	callback_t cb(jail/*, true*/);
	cb.must_see("foo/bar", "foo/bar/baz", "foo/bar/fud", nullptr);

	fs::watch(jail.path("foo/bar"), &cb, FSEventsGetCurrentEventId(), 0.1);

	jail.mkdir("foo/bar/baz/fud");
	jail.touch("dummy.txt");     // should be ignored
	jail.touch("foo/dummy.txt"); // should be ignored
	jail.mkdir("foo/bar/fud/dummy.txt");
	cb.event_loop("foo/bar");

	jail.touch("dummy.txt");     // should be ignored
	jail.touch("foo/dummy.txt"); // should be ignored
	jail.touch("foo/bar/baz/fud/dummy.txt");
	cb.must_see("foo/bar/baz/fud", nullptr);
	cb.event_loop("foo/bar");

	fs::unwatch(jail.path("foo/bar"), &cb);
	callback_t::drain_main_queue();
}

void test_initially_missing_file ()
{
	test::jail_t jail;
	callback_t cb(jail/*, true*/);
	cb.must_see("foo/bar/dummy.txt", nullptr);

	fs::watch(jail.path("foo/bar/dummy.txt"), &cb, FSEventsGetCurrentEventId(), 0.1);

	jail.mkdir("foo/bar/baz/fud");
	jail.touch("dummy.txt");
	jail.touch("foo/dummy.txt");
	jail.touch("foo/bar/other.txt");
	jail.touch("foo/bar/dummy.txt");
	cb.event_loop("foo/bar/dummy.txt");

	sleep(1);
	jail.touch("dummy.txt");
	jail.touch("foo/dummy.txt");
	jail.touch("foo/bar/other.txt");
	jail.touch("foo/bar/dummy.txt");
	cb.must_see("foo/bar/dummy.txt", nullptr);
	cb.event_loop("foo/bar/dummy.txt");

	fs::unwatch(jail.path("foo/bar/dummy.txt"), &cb);
	callback_t::drain_main_queue();
}
