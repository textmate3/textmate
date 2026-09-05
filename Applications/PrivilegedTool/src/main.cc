#include "launchd.h"
#include "CFxx.h"
#include <authorization/connection.h>
#include <authorization/constants.h>
#include <authorization/authorization.h>
#include <io/io.h>
#include <text/format.h>
#include <oak/debug.h>

// The privileged helper. launchd starts it as root when the application
// connects to its socket, and it answers requests to read, write, copy,
// make and remove what the application itself is not allowed to touch. Each
// request carries the application's authorization, which must hold the
// right the daemon defines, and the right asks for an administrator's
// password. The daemon quits after a while with nothing to do, so a newer
// build is picked up on the next connection.

static double const AppVersion = 2.0;

// Seconds without a connection before the daemon exits.
static int const kIdleSeconds = 120;

extern char* optarg;
extern int optind;

static bool running = true;

static void handle_signal (int theSignal)
{
	running = false;
}

static void version ()
{
	fprintf(stdout, "%1$s %2$.1f (" __DATE__ ")\n", getprogname(), AppVersion);
}

static void usage (FILE* io = stdout)
{
	fprintf(io,
		"%1$s %2$.1f (" __DATE__ ")\n"
		"Usage: %1$s [-shv]\n"
		"Description:\n"
		" Server for authenticated file system operations, normally started by launchd.\n"
		"Options:\n"
		" -s, --server    Run the server on its own socket rather than launchd's.\n"
		" -h, --help      Show this information.\n"
		" -v, --version   Print version information.\n"
		"\n", getprogname(), AppVersion
	);
}

// The right an authorization must hold, in the policy database: an
// administrator's password, remembered for a quarter of an hour. Defined
// here, by root, so nothing has to be installed for it to exist.
static void ensure_right ()
{
	AuthorizationRef authRef;
	if(noErr != AuthorizationCreate(nullptr, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef))
		return;

	CFDictionaryRef existing = nullptr;
	if(AuthorizationRightGet(kAuthRightName, &existing) == errAuthorizationSuccess && existing)
	{
		CFRelease(existing);
	}
	else
	{
		cf::dictionary rightDefinition;
		rightDefinition["class"]      = cf::string("user");
		rightDefinition["group"]      = cf::string("admin");
		rightDefinition["allow-root"] = CFRetain(kCFBooleanTrue);
		rightDefinition["timeout"]    = cf::number(900);

		int errStatus = AuthorizationRightSet(authRef, kAuthRightName, rightDefinition, nullptr, nullptr, nullptr);
		if(errStatus != noErr)
			fprintf(stderr, "*** error defining right ‘%s’: %d\n", kAuthRightName, errStatus);
	}
	AuthorizationFree(authRef, kAuthorizationFlagDefaults);
}

static int setup_socket ()
{
	unlink(kAuthSocketPath);

	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	struct sockaddr_un addr = { 0, AF_UNIX, kAuthSocketPath };
	addr.sun_len = SUN_LEN(&addr);
	if(bind(fd, (sockaddr*)&addr, sizeof(addr)) == -1)
	{
		perror("PrivilegedTool: bind");
		exit(EXIT_FAILURE);
	}

	chmod(kAuthSocketPath, S_IRWXU|S_IRWXG|S_IRWXO);

	if(listen(fd, SOMAXCONN) == -1)
	{
		perror("PrivilegedTool: listen");
		exit(EXIT_FAILURE);
	}

	return fd;
}

// What was wrong, as text, or the no string marker when nothing was.
static std::string failure (char const* what)
{
	return text::format("%s: %s", what, strerror(errno));
}

static void handle_connection (int fd)
{
	connection_t conn(fd);
	conn << "PrivilegedTool" << kAuthServerMajor << kAuthServerMinor;

	std::string command;
	conn >> command;
	if(command == "quit")
	{
		running = false;
		return;
	}
	else if(command != "auth")
	{
		return;
	}

	std::string authString;
	conn >> authString;

	osx::authorization_t auth(authString);
	if(!auth.check_right(kAuthRightName))
		return;

	std::string action;
	conn >> action;

	if(action == "read")
	{
		std::string path;
		conn >> path;
		conn << path::content(path) << path::attributes(path);
	}
	else if(action == "write")
	{
		std::string path, content, error = NULL_STR;
		std::map<std::string, std::string> attributes;
		conn >> path >> content >> attributes;

		if(!path::set_content(path, content))
			error = failure("set_content() failed");
		else if(!path::set_attributes(path, attributes))
			error = failure("set_attributes() failed");

		conn << error;
	}
	else if(action == "mkdir")
	{
		std::string path, error = NULL_STR;
		conn >> path;
		if(!path::make_dir(path))
			error = failure("mkdir");
		conn << error;
	}
	else if(action == "copy")
	{
		std::string src, dst, error = NULL_STR;
		conn >> src >> dst;
		if(copyfile(src.c_str(), dst.c_str(), nullptr, COPYFILE_ALL | COPYFILE_NOFOLLOW_SRC) != 0)
			error = failure("copyfile");
		conn << error;
	}
	else if(action == "remove")
	{
		std::string path, error = NULL_STR;
		conn >> path;
		if(unlink(path.c_str()) != 0 && errno != ENOENT)
			error = failure("unlink");
		conn << error;
	}
}

int main (int argc, char const* argv[])
{
	signal(SIGINT,  &handle_signal);
	signal(SIGTERM, &handle_signal);
	signal(SIGPIPE, SIG_IGN);

	static struct option const longopts[] = {
		{ "server",           no_argument,         0,      's'   },
		{ "help",             no_argument,         0,      'h'   },
		{ "version",          no_argument,         0,      'v'   },
		{ 0,                  0,                   0,      0     }
	};

	bool server = false;

	unsigned int ch;
	while((ch = getopt_long(argc, (char* const*)argv, "shv", longopts, nullptr)) != -1)
	{
		switch(ch)
		{
			case 's': server = true;    break;
			case 'h': usage();          return EX_OK;
			case 'v': version();        return EX_OK;
			default:  usage(stderr);    return EX_USAGE;
		}
	}

	if(geteuid() != 0)
	{
		fprintf(stderr, "PrivilegedTool: must run as root\n");
		return EX_NOPERM;
	}

	ensure_right();

	int fd = server ? setup_socket() : launchd_sockets();

	while(running)
	{
		fd_set readfds;
		FD_ZERO(&readfds);
		FD_SET(fd, &readfds);
		struct timeval idle = { kIdleSeconds, 0 };
		int rc = select(fd+1, &readfds, nullptr, nullptr, &idle);
		if(rc == -1)
			continue;
		if(rc == 0)
			break;

		if(FD_ISSET(fd, &readfds))
		{
			char dummy[256];
			socklen_t len = sizeof(dummy);
			int newFd = accept(fd, (sockaddr*)&dummy[0], &len);
			handle_connection(newFd);
		}
	}

	// launchd keeps the socket, so it is closed and not removed.
	close(fd);
	return EX_OK;
}
