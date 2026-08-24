#import "HOFileHandleSchemeHandler.h"
#import <OakSystem/process.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <oak/debug.h>

NSString* const HOFileHandleURLScheme = @"x-txmt-filehandle";

void SchemeTrace (NSString* format, ...)
{
	va_list ap;
	va_start(ap, format);
	NSString* line = [[NSString alloc] initWithFormat:format arguments:ap];
	va_end(ap);
	if(FILE* fp = fopen("/tmp/tm_wk.log", "a"))
	{
		fprintf(fp, "%s\n", line.UTF8String);
		fclose(fp);
	}
}

@interface HOJob : NSObject
@property (nonatomic) NSFileHandle* fileHandle;
@property (nonatomic) pid_t processIdentifier;
@property (nonatomic) BOOL stopped;
@end

@implementation HOJob
@end

@implementation HOFileHandleSchemeHandler
{
	NSMutableSet<id <WKURLSchemeTask>>* _activeTasks;
}

// Keyed by absolute URL string. One registry for the process, because the content
// process may ask through any web view that has this handler installed.
// Registration happens on whichever queue the command's output handler runs on,
// while lookup happens on the main thread when the content process asks. An
// unsynchronised dictionary gives no visibility guarantee across that boundary,
// which showed up as a job registered and then not found, and a frame load
// interrupted error in its place. Every access takes the lock.
+ (NSMutableDictionary<NSString*, HOJob*>*)jobs
{
	static NSMutableDictionary* jobs = [NSMutableDictionary new];
	return jobs;
}

+ (NSLock*)jobsLock
{
	static NSLock* lock = [NSLock new];
	return lock;
}

+ (void)registerFileHandle:(NSFileHandle*)fileHandle processIdentifier:(pid_t)processIdentifier forURL:(NSURL*)url
{
	HOJob* job = [HOJob new];
	job.fileHandle        = fileHandle;
	job.processIdentifier = processIdentifier;

	[[self jobsLock] lock];
	[self jobs][url.absoluteString] = job;
	[[self jobsLock] unlock];
}

+ (HOJob*)jobForURL:(NSURL*)url
{
	[[self jobsLock] lock];
	HOJob* job = [self jobs][url.absoluteString];
	[[self jobsLock] unlock];
	return job;
}

+ (void)unregisterURL:(NSURL*)url
{
	[[self jobsLock] lock];
	[[self jobs] removeObjectForKey:url.absoluteString];
	[[self jobsLock] unlock];
}

- (instancetype)init
{
	if(self = [super init])
		_activeTasks = [NSMutableSet new];
	return self;
}

- (void)webView:(WKWebView*)webView startURLSchemeTask:(id <WKURLSchemeTask>)task
{
	[_activeTasks addObject:task];

	if(HOJob* job = [[self class] jobForURL:task.request.URL])
		return [self startJob:job forTask:task];

	// No job for this URL, so it is one of the page's own assets: a style sheet,
	// a script, an image. Those cannot be file:// URLs, because a page served from
	// a custom scheme is not permitted to load them, so they come back through this
	// scheme and are read from disk here.
	if(NSString* path = task.request.URL.path)
	{
		if(NSData* data = [NSData dataWithContentsOfFile:path])
		{
			UTType* type = [UTType typeWithFilenameExtension:path.pathExtension];
			NSURLResponse* response = [[NSURLResponse alloc] initWithURL:task.request.URL MIMEType:(type.preferredMIMEType ?: @"application/octet-stream") expectedContentLength:data.length textEncodingName:nil];
			[self finishTask:task withResponse:response data:data];
			return;
		}
	}

	NSURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:task.request.URL statusCode:404 HTTPVersion:@"HTTP/1.1" headerFields:nil];
	[self finishTask:task withResponse:response data:nil];
}

- (void)startJob:(HOJob*)job forTask:(id <WKURLSchemeTask>)task
{
	NSURLResponse* response = [[NSURLResponse alloc] initWithURL:task.request.URL MIMEType:@"text/html" expectedContentLength:NSURLResponseUnknownLength textEncodingName:@"utf-8"];
	if(![self isTaskActive:task])
		return;
	[task didReceiveResponse:response];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		int len;
		char buf[8192];
		while((len = read(job.fileHandle.fileDescriptor, buf, sizeof(buf))) > 0)
		{
			NSData* data = [NSData dataWithBytes:buf length:len];
			__block BOOL keepGoing = YES;
			dispatch_sync(dispatch_get_main_queue(), ^{
				if(keepGoing = [self isTaskActive:task])
					[task didReceiveData:data];
			});
			if(!keepGoing)
				break;
		}

		if(len == -1)
			perror("HTMLOutput: read");

		[job.fileHandle closeFile];
		dispatch_sync(dispatch_get_main_queue(), ^{
			if([self isTaskActive:task])
			{
				[task didFinish];
				[self->_activeTasks removeObject:task];
			}
		});
	});
}

// WebKit raises if a task is messaged after it has been stopped, so every
// completion goes through this check.
- (BOOL)isTaskActive:(id <WKURLSchemeTask>)task
{
	return [_activeTasks containsObject:task];
}

- (void)finishTask:(id <WKURLSchemeTask>)task withResponse:(NSURLResponse*)response data:(NSData*)data
{
	if(![self isTaskActive:task])
		return;
	[task didReceiveResponse:response];
	if(data)
		[task didReceiveData:data];
	[task didFinish];
	[_activeTasks removeObject:task];
}

- (void)webView:(WKWebView*)webView stopURLSchemeTask:(id <WKURLSchemeTask>)task
{
	[_activeTasks removeObject:task];

	if(HOJob* job = [[self class] jobForURL:task.request.URL])
	{
		job.stopped = YES;
		if(job.processIdentifier)
			oak::kill_process_group_in_background(job.processIdentifier);
	}
}
@end
