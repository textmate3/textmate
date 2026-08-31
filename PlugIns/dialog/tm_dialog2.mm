//
//  client.mm
//  Created by Allan Odgaard on 2007-09-22.
//

#import "Dialog2.h"

static double const AppVersion = 2.0;

int connect_to_server ()
{
	char const* socketPath = getenv("DIALOG_SOCKET_PATH");
	if(!socketPath)
	{
		fprintf(stderr, "DIALOG_SOCKET_PATH is not set, so there is no editor to talk to.\n");
		return -1;
	}

	int fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if(fd == -1)
	{
		perror("socket");
		return -1;
	}

	struct sockaddr_un addr = { 0, AF_UNIX };
	if(strlcpy(addr.sun_path, socketPath, sizeof(addr.sun_path)) >= sizeof(addr.sun_path))
	{
		fprintf(stderr, "socket path is too long: %s\n", socketPath);
		close(fd);
		return -1;
	}
	addr.sun_len = SUN_LEN(&addr);

	if(connect(fd, (sockaddr*)&addr, sizeof(addr)) == -1)
	{
		fprintf(stderr, "unable to reach ‘%s’: %s\n", socketPath, strerror(errno));
		close(fd);
		return -1;
	}

	return fd;
}

// Sends the request and waits for the editor to say it has it. Waiting matters: the caller opens its
// FIFOs immediately afterwards, and opening one blocks until the other end does too, so a request
// that never arrived would hang here rather than report anything.
bool send_request (int fd, NSDictionary* request)
{
	NSData* data = [NSPropertyListSerialization dataWithPropertyList:request format:NSPropertyListBinaryFormat_v1_0 options:0 error:nullptr];
	if(!data)
		return fprintf(stderr, "unable to serialize request\n"), false;

	char const* bytes = (char const*)data.bytes;
	size_t left       = data.length;
	while(left)
	{
		ssize_t len = write(fd, bytes, left);
		if(len == -1)
		{
			if(errno == EINTR)
				continue;
			perror("write");
			return false;
		}
		bytes += len;
		left  -= len;
	}

	shutdown(fd, SHUT_WR);

	char answer = 0;
	while(read(fd, &answer, 1) == -1 && errno == EINTR)
		continue;

	if(answer != kDialogRequestAccepted)
		return fprintf(stderr, "the editor did not accept the request\n"), false;

	return true;
}

char const* create_pipe (char const* name)
{
	char* filename;
	asprintf(&filename, "%s/dialog_fifo_%d_%s", getenv("TMPDIR") ?: "/tmp", getpid(), name);
	int res = mkfifo(filename, 0666);
	if((res == -1) && (errno != EEXIST))
	{
		perror("Error creating the named pipe");
		exit(EX_OSERR);
   }
	return filename;
}

int open_pipe (char const* name, int oflag)
{
	int fd = open(name, oflag);
	if(fd == -1)
	{
		perror("Error opening the named pipe");
		exit(EX_IOERR);
	}
	return fd;
}

int main (int argc, char const* argv[])
{
	if(argc == 2 && strcmp(argv[1], "--version") == 0)
	{
		fprintf(stderr, "%1$s %2$.1f (" __DATE__ ")\n", getprogname(), AppVersion);
		return EX_OK;
	}

	// A leading switch is the TextMate 1 dialog syntax, which this tool does not implement. Say so
	// rather than failing somewhere further in with nothing to go on.
	if(argc > 1 && *argv[1] == '-')
	{
		fprintf(stderr, "%1$s: ‘%2$s’ is TextMate 1 dialog syntax, which is no longer supported.\n", getprogname(), argv[1]);
		fprintf(stderr, "%1$s: Run ‘%1$s help’ for the commands this version accepts.\n", getprogname());
		return EX_USAGE;
	}

	@autoreleasepool{
		int serverFd = connect_to_server();
		if(serverFd == -1)
			exit(EX_UNAVAILABLE);

		char const* stdinName  = create_pipe("stdin");
		char const* stdoutName = create_pipe("stdout");
		char const* stderrName = create_pipe("stderr");

		NSMutableArray* args = [NSMutableArray array];
		for(size_t i = 0; i < argc; ++i)
			[args addObject:@(argv[i])];

		NSDictionary* dict = @{
			@"stdin":       @(stdinName),
			@"stdout":      @(stdoutName),
			@"stderr":      @(stderrName),
			@"cwd":         @(getcwd(NULL, 0)),
			@"environment": [[NSProcessInfo processInfo] environment],
			@"arguments":   args,
		};

		bool sent = send_request(serverFd, dict);
		close(serverFd);

		if(!sent)
		{
			unlink(stdinName);
			unlink(stdoutName);
			unlink(stderrName);
			exit(EX_UNAVAILABLE);
		}

		int inputFd  = open_pipe(stdinName, O_WRONLY);
		int outputFd = open_pipe(stdoutName, O_RDONLY);
		int errorFd = open_pipe(stderrName, O_RDONLY);

		std::map<int, int> fdMap;
		fdMap[STDIN_FILENO] = inputFd;
		fdMap[outputFd]     = STDOUT_FILENO;
		fdMap[errorFd]      = STDERR_FILENO;

		if(isatty(STDIN_FILENO) != 0)
		{
			fdMap.erase(fdMap.find(STDIN_FILENO));
			close(inputFd);
		}

		while(fdMap.size() > 1 || (fdMap.size() == 1 && fdMap.find(STDIN_FILENO) == fdMap.end()))
		{
			fd_set readfds, writefds;
			FD_ZERO(&readfds); FD_ZERO(&writefds);

			int fdCount = 0;
			for(auto const& pair : fdMap)
			{
				FD_SET(pair.first, &readfds);
				fdCount = std::max(fdCount, pair.first + 1);
			}

			int i = select(fdCount, &readfds, &writefds, NULL, NULL);
			if(i == -1)
			{
				perror("Error from select");
				continue;
			}

			std::vector<int> toRemove;
			for(auto const& pair : fdMap)
			{
				if(FD_ISSET(pair.first, &readfds))
				{
					char buf[1024];
					ssize_t len = read(pair.first, buf, sizeof(buf));

					if(len == 0)
							toRemove.push_back(pair.first); // we can’t remove as long as we need the iterator for the ++
					else	write(pair.second, buf, len);
				}
			}

			for(int key : toRemove)
			{
				if(fdMap[key] == inputFd)
					close(inputFd);
				fdMap.erase(key);
			}
		}

		close(outputFd);
		close(errorFd);
		unlink(stdinName);
		unlink(stdoutName);
		unlink(stderrName);
	}

	return EX_OK;
}
