#ifndef IO_SOCKET_H_TNW4NXOL
#define IO_SOCKET_H_TNW4NXOL

#include <oak/debug.h>

struct socket_t
{
	socket_t ()                     { }
	socket_t (int fd)               { helper = std::make_shared<helper_t>(fd); }
	operator int () const           { ASSERT(helper); return helper->fd; }
	explicit operator bool () const { return helper ? helper->fd != -1 : false; }

private:
	struct helper_t
	{
		helper_t (int fd) : fd(fd) { if(fd != -1) fcntl(fd, F_SETFD, FD_CLOEXEC); }
		~helper_t ()               { if(fd != -1) close(fd); }
		int fd;
	};

	std::shared_ptr<helper_t> helper;
};

// Calls f on the main queue whenever the descriptor becomes readable. Returning false from f stops
// the watching and destroys the callback, so a handler that has reached end of stream simply says so
// rather than having to unregister itself.
struct socket_callback_t
{
	socket_callback_t (std::function<bool(socket_t const&)> const& f, socket_t const& fd)
	{
		helper = std::make_shared<helper_t>(f, fd, this);

		if(_dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (int)fd, 0, dispatch_get_main_queue()))
		{
			dispatch_source_set_event_handler(_dispatchSource, ^{
				(*helper)();
			});
			dispatch_resume(_dispatchSource);
		}
	}

	~socket_callback_t ()
	{
		if(_dispatchSource)
			dispatch_source_cancel(_dispatchSource);
	}

private:
	struct helper_t
	{
		helper_t (std::function<bool(socket_t const&)> const& f, socket_t const& socket, socket_callback_t* parent) : f(f), socket(socket), parent(parent) { }
		void operator() () { if(!f(socket)) delete parent; }

	private:
		std::function<bool(socket_t const&)> f;
		socket_t socket;
		socket_callback_t* parent;
	};

	std::shared_ptr<helper_t> helper;
	dispatch_source_t _dispatchSource;
};

typedef std::shared_ptr<socket_callback_t> socket_callback_ptr;

#endif /* end of include guard: IO_SOCKET_H_TNW4NXOL */
