#import "RubyRuntimeManager.h"
#import <OakFoundation/NSString Additions.h>
#import <OakSystem/application.h>
#import <SoftwareUpdate/OakDownloadManager.h>
#import <io/environment.h>
#import <io/path.h>
#import <ns/ns.h>
#import <os/log.h>

static NSString* const kRuntimesDirectory = @"Ruby";

@implementation RubyRuntimeManager
+ (instancetype)sharedInstance
{
	static RubyRuntimeManager* sharedInstance = [self new];
	return sharedInstance;
}

- (NSString*)runtimesDirectory
{
	return [NSString stringWithCxxString:oak::application_t::support(to_s(kRuntimesDirectory))];
}

// The newest version directory holding a bin/ruby, by version rather than by name.
- (NSString*)installedRuntimeDirectory
{
	NSString* newest = nil;
	NSArray<NSString*>* versions = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.runtimesDirectory error:nil];
	for(NSString* version in [versions sortedArrayUsingSelector:@selector(localizedStandardCompare:)])
	{
		NSString* directory = [self.runtimesDirectory stringByAppendingPathComponent:version];
		if([NSFileManager.defaultManager isExecutableFileAtPath:[directory stringByAppendingPathComponent:@"bin/ruby"]])
			newest = directory;
	}

	oak::set_downloaded_ruby_directory(to_s(newest));
	return newest;
}

- (void)installNewestRuntimeWithCompletionHandler:(void(^)(NSString*, NSError*))handler
{
	NSURL* indexURL   = [NSURL URLWithString:@REST_API "/ruby"];
	NSString* cache   = [NSString stringWithCxxString:oak::application_t::cache("ruby-runtimes.plist")];
	NSURL* localIndex = [NSURL fileURLWithPath:cache];

	[OakDownloadManager.sharedInstance downloadFileAtURL:indexURL replacingFileAtURL:localIndex detachedSignatureURL:[indexURL URLByAppendingPathExtension:@"sig"] publicKey:@BUNDLE_PUBLIC_ED_KEY completionHandler:^(BOOL wasUpdated, NSError* error){
		NSDictionary* index = [NSDictionary dictionaryWithContentsOfURL:localIndex];
		NSDictionary* runtime = [index[@"runtimes"] firstObject];
		if(!runtime)
		{
			os_log_error(OS_LOG_DEFAULT, "No Ruby runtime in the index at %{public}@: %{public}@", indexURL, error.localizedDescription);
			return handler(nil, error ?: [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{ NSLocalizedDescriptionKey: @"The runtime index lists no Ruby." }]);
		}

		NSString* version     = runtime[@"version"];
		NSURL* archiveURL     = [NSURL URLWithString:runtime[@"url"]];
		NSString* destination = [self.runtimesDirectory stringByAppendingPathComponent:version];
		NSURL* destinationURL = [NSURL fileURLWithPath:destination isDirectory:YES];
		[NSFileManager.defaultManager createDirectoryAtPath:self.runtimesDirectory withIntermediateDirectories:YES attributes:nil error:nil];

		os_log(OS_LOG_DEFAULT, "Downloading Ruby %{public}@ from %{public}@", version, archiveURL);
		[OakDownloadManager.sharedInstance downloadArchiveAtURL:archiveURL forReplacingURL:destinationURL signature:runtime[@"signature"] publicKey:@BUNDLE_PUBLIC_ED_KEY completionHandler:^(NSURL* extractedURL, NSError* downloadError){
			if(!extractedURL)
			{
				os_log_error(OS_LOG_DEFAULT, "Failed to download Ruby %{public}@: %{public}@", version, downloadError.localizedDescription);
				return handler(nil, downloadError);
			}

			NSError* replaceError;
			if(![NSFileManager.defaultManager replaceItemAtURL:destinationURL withItemAtURL:extractedURL backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:nil error:&replaceError])
			{
				os_log_error(OS_LOG_DEFAULT, "Failed to install Ruby %{public}@ at %{public}@: %{public}@", version, destination, replaceError.localizedDescription);
				return handler(nil, replaceError);
			}

			// The environment every command gets was made at launch, before this Ruby existed.
			NSString* installed = self.installedRuntimeDirectory;
			oak::set_basic_environment(oak::setup_basic_environment());
			os_log(OS_LOG_DEFAULT, "Installed Ruby %{public}@ at %{public}@", version, installed);
			handler(installed, nil);
		}];
	}];
}
@end
