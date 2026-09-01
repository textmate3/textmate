#import "OakDownloadManager.h"
#import <network/ed25519.h>
#import <oak/misc.h>

// Returns nil when the data verifies, otherwise the reason it does not.
static NSString* Ed25519VerificationError (NSData* data, NSString* signatureBase64, NSString* publicKeyBase64)
{
	std::string error;
	std::string const payload((char const*)data.bytes, data.length);
	if(network::verify_ed25519_signature(payload, signatureBase64 ? signatureBase64.UTF8String : "", publicKeyBase64 ? publicKeyBase64.UTF8String : "", error))
		return nil;
	return [NSString stringWithUTF8String:error.c_str()];
}

static NSString* GetHardwareInfo (int field, BOOL isInteger = NO)
{
	char buf[1024];
	size_t bufSize = sizeof(buf);
	int request[] = { CTL_HW, field };

	if(sysctl(request, sizeofA(request), buf, &bufSize, nullptr, 0) != -1)
	{
		if(isInteger && bufSize == 4)
			return [NSString stringWithFormat:@"%d", *(int*)buf];
		return [[NSString alloc] initWithUTF8String:buf];
	}

	return @"???";
}

// ==========================
// = OakDownloadArchiveTask =
// ==========================

@interface OakDownloadArchiveTask : NSObject <NSProgressReporting, NSURLSessionDataDelegate>
{
	NSString*                           _signatureBase64;
	NSString*                           _publicKeyBase64;

	void(^_completionHandler)(NSURL* extractedArchiveURL, NSError* error);

	NSMutableData*                      _data;

	NSURL*                              _fileURLToReplace;
	NSURL*                              _temporaryFileURL;

	NSTask*                             _extractorTask;
	NSFileHandle*                       _extractorFileHandle;
	dispatch_group_t                    _extractorDispatchGroup;
	NSError*                            _extractorError;

	NSDate*                             _sampleStartDate;
	int64_t                             _sampleCountOfBytesReceived;
}
@property (nonatomic) NSProgress* progress;
@property (nonatomic) NSData* extractorTaskOutputData;
@property (nonatomic) NSData* extractorTaskErrorData;
@end

@implementation OakDownloadArchiveTask
- (instancetype)initWithURL:(NSURL*)url forReplacingURL:(NSURL*)localURL signature:(NSString*)signatureBase64 publicKey:(NSString*)publicKeyBase64 completionHandler:(void(^)(NSURL* extractedArchiveURL, NSError* error))completionHandler
{
	if(self = [super init])
	{
		_fileURLToReplace       = localURL;
		_signatureBase64        = signatureBase64;
		_publicKeyBase64        = publicKeyBase64;
		_completionHandler      = completionHandler;
		_progress               = [NSProgress discreteProgressWithTotalUnitCount:-1];
		_data                   = [NSMutableData data];
		_extractorDispatchGroup = dispatch_group_create();

		_progress.kind = NSProgressKindFile;
		_progress.fileOperationKind = NSProgressFileOperationKindDownloading;
		_progress.localizedDescription = [NSString stringWithFormat:@"Downloading %@…", url.lastPathComponent];

		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
		[request setValue:OakDownloadManager.sharedInstance.userAgentString forHTTPHeaderField:@"User-Agent"];

		NSURLSession* session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:self delegateQueue:NSOperationQueue.mainQueue];
		[[session dataTaskWithRequest:request] resume];
		[session finishTasksAndInvalidate];
	}
	return self;
}

- (void)dealloc
{
	NSError* error;
	if(_temporaryFileURL && ![NSFileManager.defaultManager removeItemAtURL:_temporaryFileURL error:&error])
		os_log_error(OS_LOG_DEFAULT, "Unable to remove %{public}@: %{public}@", _temporaryFileURL.path, error.localizedDescription);
}

- (NSFileHandle*)extractorFileHandle
{
	if(!_extractorFileHandle)
	{
		NSError* error;
		if(!(_temporaryFileURL = [NSFileManager.defaultManager URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:_fileURLToReplace create:YES error:&error]))
		{
			os_log_error(OS_LOG_DEFAULT, "Failed to obtain NSItemReplacementDirectory: %{public}@", error.localizedDescription);
			_extractorError = error;
			return nil;
		}

		NSPipe* inputPipe  = [NSPipe pipe];
		NSPipe* outputPipe = [NSPipe pipe];
		NSPipe* errorPipe  = [NSPipe pipe];

		_extractorTask = [[NSTask alloc] init];
		_extractorTask.launchPath     = @"/usr/bin/tar";
		_extractorTask.arguments      = @[ @"-jxmkC", _temporaryFileURL.filePathURL.path, @"--strip-components", @"1", @"--disable-copyfile", @"--exclude", @"._*" ];
		_extractorTask.standardInput  = inputPipe;
		_extractorTask.standardOutput = outputPipe;
		_extractorTask.standardError  = errorPipe;

		dispatch_group_async(_extractorDispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			self.extractorTaskOutputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
			[outputPipe.fileHandleForReading closeFile];
		});

		dispatch_group_async(_extractorDispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			self.extractorTaskErrorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
			[errorPipe.fileHandleForReading closeFile];
		});

		dispatch_group_t group = _extractorDispatchGroup; // Avoid capturing ‘self’ in terminationHandler

		dispatch_group_enter(group);
		_extractorTask.terminationHandler = ^(NSTask* theTask){
			dispatch_group_leave(group);
		};

		if(![_extractorTask launchAndReturnError:&error])
		{
			os_log_error(OS_LOG_DEFAULT, "Failed to launch tar: %{public}@", error.localizedDescription);

			dispatch_group_leave(_extractorDispatchGroup); // Completion handler will never be called
			[outputPipe.fileHandleForWriting closeFile];
			[errorPipe.fileHandleForWriting closeFile];

			_extractorTask  = nil;
			_extractorError = error;

			return nil;
		}
		_extractorFileHandle = inputPipe.fileHandleForWriting;
	}
	return _extractorFileHandle;
}

- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)dataTask didReceiveData:(NSData*)data
{
	NSFileHandle* fileHandle = self.extractorFileHandle;
	if(fileHandle && !_progress.isCancelled)
	{
		[fileHandle writeData:data];
		[_data appendData:data];

		if(dataTask.countOfBytesExpectedToReceive != NSURLSessionTransferSizeUnknown)
		{
			if(!_sampleStartDate)
			{
				_sampleStartDate = [NSDate date];
			}
			else
			{
				if(int64_t bytesLeft = dataTask.countOfBytesExpectedToReceive - dataTask.countOfBytesReceived)
				{
					NSTimeInterval secondsSampled = -_sampleStartDate.timeIntervalSinceNow;
					if(secondsSampled > 0.9)
					{
						int64_t bytesReceivedSinceLastSample = dataTask.countOfBytesReceived - _sampleCountOfBytesReceived;
						[_progress setUserInfoObject:@(ceil(bytesLeft * secondsSampled / bytesReceivedSinceLastSample)) forKey:NSProgressEstimatedTimeRemainingKey];

						_sampleStartDate            = [NSDate date];
						_sampleCountOfBytesReceived = dataTask.countOfBytesReceived;
					}
				}
				else
				{
					[_progress setUserInfoObject:nil forKey:NSProgressEstimatedTimeRemainingKey];
				}
			}
		}

		_progress.totalUnitCount     = dataTask.countOfBytesExpectedToReceive;
		_progress.completedUnitCount = dataTask.countOfBytesReceived;
	}
	else
	{
		[dataTask cancel];
	}
}

- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)dataTask didCompleteWithError:(NSError*)downloadError
{
	[_extractorFileHandle closeFile];
	_progress.totalUnitCount = dataTask.countOfBytesReceived;

	if(NSError* error = _extractorError ?: (_extractorTask ? downloadError : [NSError errorWithDomain:@"OakDownloadManager" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Unable to launch tar." }]))
	{
		os_log_error(OS_LOG_DEFAULT, "Failed to download %{public}@: %{public}@", dataTask.originalRequest.URL, error.localizedDescription);
		_completionHandler(nil, error);
	}
	else if(NSString* verificationError = Ed25519VerificationError(_data, _signatureBase64, _publicKeyBase64))
	{
		os_log_error(OS_LOG_DEFAULT, "Unable to verify signature for %{public}@: %{public}@", dataTask.originalRequest.URL, verificationError);
		_completionHandler(nil, [NSError errorWithDomain:@"OakDownloadManager" code:0 userInfo:@{ NSLocalizedDescriptionKey: verificationError }]);
	}
	else
	{
		dispatch_group_notify(_extractorDispatchGroup, dispatch_get_main_queue(), ^{
			if(_extractorTask.terminationStatus == 0)
			{
				NSURL* url = _temporaryFileURL;
				_temporaryFileURL = nil;
				_completionHandler(url, nil);
			}
			else
			{
				NSString* errorString  = _extractorTaskErrorData.length  ? [[NSString alloc] initWithData:_extractorTaskErrorData  encoding:NSUTF8StringEncoding] : nil;
				NSString* outputString = _extractorTaskOutputData.length ? [[NSString alloc] initWithData:_extractorTaskOutputData encoding:NSUTF8StringEncoding] : nil;

				os_log_error(OS_LOG_DEFAULT, "Abnormal exit from tar: %d", _extractorTask.terminationStatus);
				if(errorString)
					os_log_error(OS_LOG_DEFAULT, "%{public}@", errorString);
				if(outputString)
					os_log_error(OS_LOG_DEFAULT, "%{public}@", outputString);

				NSString* description = errorString ?: outputString ?: [NSString stringWithFormat:@"Abnormal exit from tar: %d", _extractorTask.terminationStatus];
				description = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
				description = [description stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
				_completionHandler(nil, [NSError errorWithDomain:@"OakDownloadManager" code:0 userInfo:@{ NSLocalizedDescriptionKey: description }]);
			}
		});
	}
}
@end

// ======================
// = OakDownloadManager =
// ======================

@interface OakDownloadManager ()
{
	NSString* _userAgentString;
}
@end

@implementation OakDownloadManager
+ (instancetype)sharedInstance
{
	static OakDownloadManager* sharedInstance = [self new];
	return sharedInstance;
}

- (NSString*)userAgentString
{
	if(!_userAgentString)
	{
		uuid_t uuidBytes;
		timespec wait = { };
		gethostuuid(uuidBytes, &wait);

		NSString* appName    = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
		NSString* appVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSUUID* uuid         = [[NSUUID alloc] initWithUUIDBytes:uuidBytes];

		NSOperatingSystemVersion osVersion = NSProcessInfo.processInfo.operatingSystemVersion;

		NSString* res = [NSString stringWithFormat:@"%@/%@/%@ %ld.%ld.%ld/%@/%@/%@",
			appName, appVersion, uuid.UUIDString,
			osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion,
			GetHardwareInfo(HW_MACHINE),
			GetHardwareInfo(HW_MODEL),
			GetHardwareInfo(HW_NCPU, YES)
		];
		_userAgentString = res;
	}
	return _userAgentString;
}

- (void)downloadFileAtURL:(NSURL*)serverURL replacingFileAtURL:(NSURL*)localFileURL detachedSignatureURL:(NSURL*)signatureURL publicKey:(NSString*)publicKeyBase64 completionHandler:(void(^)(BOOL wasUpdated, NSError* error))completionHandler
{
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:serverURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
	[request setValue:self.userAgentString forHTTPHeaderField:@"User-Agent"];

	ssize_t size = getxattr(localFileURL.fileSystemRepresentation, "org.w3.http.etag", nullptr, 0, 0, 0);
	if(size != -1)
	{
		if(NSMutableData* tempData = [NSMutableData dataWithLength:size])
		{
			getxattr(localFileURL.fileSystemRepresentation, "org.w3.http.etag", tempData.mutableBytes, tempData.length, 0, 0);
			if(NSString* entityTag = [[NSString alloc] initWithData:tempData encoding:NSUTF8StringEncoding])
			{
				[request setValue:entityTag forHTTPHeaderField:@"If-None-Match"];
				os_log(OS_LOG_DEFAULT, "GET %{public}@ using entity tag %{public}@", serverURL.absoluteString, entityTag);
			}
		}
	}

	NSURLSessionDataTask* dataTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error){
		NSInteger statusCode = ((NSHTTPURLResponse*)response).statusCode;
		if(error || statusCode != 200)
		{
			if(!error && statusCode != 304)
				error = [NSError errorWithDomain:@"OakDownloadManager" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Server returned %ld for %@", statusCode, serverURL.absoluteString] }];
			completionHandler(NO, error);
			return;
		}

		// The index signature is a sibling resource: base64 Ed25519 over the
		// exact bytes just downloaded. Fetch it, then verify before writing.
		NSMutableURLRequest* signatureRequest = [NSMutableURLRequest requestWithURL:signatureURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
		[signatureRequest setValue:self.userAgentString forHTTPHeaderField:@"User-Agent"];

		NSURLSessionDataTask* signatureTask = [NSURLSession.sharedSession dataTaskWithRequest:signatureRequest completionHandler:^(NSData* signatureData, NSURLResponse* signatureResponse, NSError* signatureError){
			BOOL wasUpdated = NO;
			NSError* resultError = signatureError;

			NSInteger signatureStatusCode = ((NSHTTPURLResponse*)signatureResponse).statusCode;
			if(!resultError && signatureStatusCode != 200)
				resultError = [NSError errorWithDomain:@"OakDownloadManager" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Server returned %ld for %@", signatureStatusCode, signatureURL.absoluteString] }];

			if(!resultError)
			{
				NSString* signature = [[[NSString alloc] initWithData:signatureData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
				if(NSString* verificationError = Ed25519VerificationError(data, signature, publicKeyBase64))
				{
					os_log_error(OS_LOG_DEFAULT, "Unable to verify signature for %{public}@: %{public}@", serverURL.absoluteString, verificationError);
					resultError = [NSError errorWithDomain:@"OakDownloadManager" code:0 userInfo:@{ NSLocalizedDescriptionKey: verificationError }];
				}
				else if([data writeToURL:localFileURL options:NSDataWritingAtomic error:&resultError])
				{
					wasUpdated = YES;

					if(NSString* newETag = ((NSHTTPURLResponse*)response).allHeaderFields[@"ETag"])
					{
						char const* str = newETag.UTF8String;
						if(setxattr(localFileURL.fileSystemRepresentation, "org.w3.http.etag", str, strlen(str), 0, 0) == -1)
							os_log_error(OS_LOG_DEFAULT, "setxattr(%{public}@): %{darwin.errno}d", localFileURL.path, errno);
					}
					else
					{
						os_log_error(OS_LOG_DEFAULT, "No ETag: %{public}@", serverURL.absoluteString);
					}
				}
			}

			completionHandler(wasUpdated, resultError);
		}];
		[signatureTask resume];
	}];
	[dataTask resume];
}

- (id <NSProgressReporting>)downloadArchiveAtURL:(NSURL*)serverURL forReplacingURL:(nullable NSURL*)localURL signature:(NSString*)signatureBase64 publicKey:(NSString*)publicKeyBase64 completionHandler:(void(^)(NSURL* extractedArchiveURL, NSError* error))completionHandler
{
	return [[OakDownloadArchiveTask alloc] initWithURL:serverURL forReplacingURL:localURL signature:signatureBase64 publicKey:publicKeyBase64 completionHandler:completionHandler];
}
@end
