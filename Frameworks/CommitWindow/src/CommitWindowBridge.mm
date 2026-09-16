#import "CommitWindowBridge.h"
#import "CommitWindow.h"
#import <io/io.h>
#import <ns/ns.h>
#import <regexp/format_string.h>
#import <text/tokenize.h>
#import <plist/uuid.h>

static std::map<std::string, std::string> convert (NSDictionary* dictionary)
{
	std::map<std::string, std::string> res;
	for(NSString* key in dictionary)
		res[to_s(key)] = to_s(dictionary[key]);
	return res;
}

@implementation CommitWindowBridge
+ (NSString*)runShellCommand:(NSString*)command environment:(NSDictionary<NSString*, NSString*>*)environment
{
	std::string const res = io::exec(convert(environment), "/bin/sh", "-c", to_s(command).c_str(), NULL);
	return res == NULL_STR ? nil : to_ns(res);
}

+ (NSString*)absolutePathForTool:(NSString*)tool environment:(NSDictionary<NSString*, NSString*>*)environment
{
	std::string const name = to_s(tool);
	if(path::is_executable(name))
		return tool;

	if(NSString* searchPath = environment[@"PATH"])
	{
		std::string const list = to_s(searchPath);
		for(auto const& dir : text::tokenize(list.begin(), list.end(), ':'))
		{
			if(path::is_executable(path::join(dir, name)))
				return to_ns(path::join(dir, name));
		}
	}
	return tool;
}

+ (NSString*)escapedPath:(NSString*)path            { return to_ns(path::escape(to_s(path))); }
+ (NSString*)displayNameForPath:(NSString*)path     { return to_ns(path::display_name(to_s(path))); }
+ (NSString*)newProjectIdentifier                   { return to_ns(oak::uuid_t().generate()); }

+ (NSString*)expandedString:(NSString*)string withVariables:(NSDictionary<NSString*, NSString*>*)variables
{
	return to_ns(format_string::expand(to_s(string), convert(variables)));
}
@end

@implementation CommitWindowReply
{
	socket_t _socket;
}

- (instancetype)initWithFileDescriptor:(int)fileDescriptor
{
	if(self = [super init])
		_socket = fileDescriptor == -1 ? socket_t() : socket_t(fileDescriptor);
	return self;
}

- (BOOL)isOpen { return (bool)_socket; }

- (void)sendStandardOutput:(NSString*)output shouldContinue:(BOOL)shouldContinue
{
	[self send:@{
		kOakCommitWindowStandardOutput: output ?: @"",
		kOakCommitWindowReturnCode:     @0,
		kOakCommitWindowContinue:       @(shouldContinue),
	}];
}

- (void)sendCancelled
{
	[self send:@{ kOakCommitWindowReturnCode: @1 }];
}

- (void)send:(NSDictionary*)reply
{
	if(!_socket)
		return; // Already answered.

	NSError* error;
	if(NSData* data = [NSPropertyListSerialization dataWithPropertyList:reply format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error])
	{
		char const* bytes = (char const*)data.bytes;
		size_t left = data.length;
		while(left)
		{
			ssize_t len = write(_socket, bytes, left);
			if(len == -1)
			{
				if(errno == EINTR)
					continue;
				os_log_error(OS_LOG_DEFAULT, "Failed writing commit window reply: %{public}s", strerror(errno));
				break;
			}
			bytes += len;
			left  -= len;
		}
	}
	else
	{
		os_log_error(OS_LOG_DEFAULT, "Failed serializing commit window reply: %{public}@", error.localizedDescription);
	}

	// Closing is what releases the waiting tool, so it happens even when the
	// write above did not.
	_socket = socket_t();
}
@end
