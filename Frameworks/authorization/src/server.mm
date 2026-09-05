#import "server.h"
#import "constants.h"
#import <ServiceManagement/ServiceManagement.h>
#import <oak/debug.h>

static os_log_t const kLogHelper = os_log_create("com.textmate3.TextMate", "PrivilegedTool");

// The helper is a launchd daemon inside the application bundle, registered
// with the system the first time it is needed. Registering a daemon is the
// person's to approve, in System Settings under Login Items, and until they
// have the helper cannot be reached. Their approval is asked for once and
// remembered by the system.
static bool helper_is_registered ()
{
	SMAppService* service = [SMAppService daemonServiceWithPlistName:@kAuthPlistName];
	if(service.status == SMAppServiceStatusEnabled)
		return true;

	if(service.status != SMAppServiceStatusRequiresApproval)
	{
		NSError* error;
		if([service registerAndReturnError:&error] && service.status == SMAppServiceStatusEnabled)
			return true;
		if(error)
			os_log_error(kLogHelper, "Registering the privileged helper: %{public}@", error.localizedDescription);
	}

	if(service.status == SMAppServiceStatusRequiresApproval)
	{
		os_log(kLogHelper, "The privileged helper needs approval under Login Items in System Settings");
		[SMAppService openSystemSettingsLoginItems];
	}
	return false;
}

connection_t connect_to_auth_server (osx::authorization_t const& auth, bool retry)
{
	if(!helper_is_registered())
		return connection_t();

	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if(fd == -1)
	{
		perror("PrivilegedTool: socket");
		return connection_t();
	}

	struct sockaddr_un addr = { 0, AF_UNIX, kAuthSocketPath };
	addr.sun_len = SUN_LEN(&addr);
	if(connect(fd, (sockaddr*)&addr, sizeof(addr)) == -1)
	{
		perror("PrivilegedTool: connect");
		close(fd);
		return connection_t();
	}

	connection_t res(fd);
	std::string server;
	int major, minor;
	res >> server >> major >> minor;
	if(major != kAuthServerMajor)
	{
		// A daemon from an earlier build is still running. It quits on request,
		// launchd starts the one in this bundle on the next connection, and
		// one more try is all it takes.
		res << "quit";
		return retry ? connection_t() : connect_to_auth_server(auth, true);
	}

	// The right is defined by the daemon on its first start, which the
	// connection above has caused, so it exists by the time it is asked for.
	if(!auth.obtain_right(kAuthRightName))
		return connection_t();

	res << "auth" << (std::string)auth;
	return res;
}
