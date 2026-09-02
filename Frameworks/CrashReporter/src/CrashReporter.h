@interface CrashReporter : NSObject
@property (class, readonly) CrashReporter* sharedInstance;
- (void)logNewCrashReports;
@end
