#import "CrashReporter.h"
#import <Preferences/Keys.h>

// Crash reports the application has already logged, so each is reported once.
static NSString* const kUserDefaultsCrashReportsLoggedKey = @"CrashReportsLogged";

@implementation CrashReporter
+ (instancetype)sharedInstance
{
	static CrashReporter* sharedInstance = [self new];
	return sharedInstance;
}

// Crash reports go nowhere but the unified log. There is no server to receive
// them: the catalog host is static files and cannot accept an upload. What is
// worth knowing is that the previous session crashed and where macOS put the
// report, so each new report from the last week is logged once at launch.
- (void)logNewCrashReports
{
	if([NSUserDefaults.standardUserDefaults boolForKey:kUserDefaultsDisableCrashReportingKey])
		return;

	NSDate* cutOff = [NSDate dateWithTimeIntervalSinceNow:-7*24*60*60];
	NSArray<NSString*>* recent = [self reportsForProcessName:NSProcessInfo.processInfo.processName notBeforeDate:cutOff];

	NSMutableSet<NSString*>* logged = [NSMutableSet set];
	if(NSArray<NSString*>* previouslyLogged = [NSUserDefaults.standardUserDefaults stringArrayForKey:kUserDefaultsCrashReportsLoggedKey])
		[logged addObjectsFromArray:previouslyLogged];

	for(NSString* reportPath in recent)
	{
		if([logged containsObject:reportPath])
			continue;
		os_log_error(OS_LOG_DEFAULT, "A previous session crashed. The report is at %{public}@", reportPath);
		[logged addObject:reportPath];
	}

	// Forget reports that macOS has since removed, so the list cannot grow forever.
	[logged intersectSet:[NSSet setWithArray:recent]];
	[NSUserDefaults.standardUserDefaults setObject:logged.allObjects forKey:kUserDefaultsCrashReportsLoggedKey];
}

- (NSArray<NSString*>*)reportsForProcessName:(NSString*)processName notBeforeDate:(NSDate*)cutOffDate
{
	NSString* const directory  = @"~/Library/Logs/DiagnosticReports".stringByExpandingTildeInPath;
	NSString* const timeFormat = [processName stringByAppendingString:@"_%F-%H%M%S"];

	NSMutableArray<NSString*>* res = [NSMutableArray array];
	for(NSString* fileName in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil])
	{
		if([fileName hasPrefix:processName])
		{
			struct tm bsdDate = { };
			if(strptime(fileName.UTF8String, timeFormat.UTF8String, &bsdDate))
			{
				time_t seconds = mktime(&bsdDate);
				if(seconds != -1 && seconds >= cutOffDate.timeIntervalSince1970)
					[res addObject:[directory stringByAppendingPathComponent:fileName]];
			}
		}
	}
	return res;
}
@end
