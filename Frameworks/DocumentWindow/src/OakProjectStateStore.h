// Per-project session state, keyed by project path: open documents, window frame, file browser
// state, and the last-used date that orders the Open Recent Project window. Values are property
// list dictionaries and the whole store persists as one binary property list in Application
// Support. All access is from the main thread.
@interface OakProjectStateStore : NSObject
@property (class, readonly) OakProjectStateStore* sharedInstance;

// Entries as @{ @"key": path, @"value": info } pairs, so callers can sort on key paths into both.
@property (nonatomic, readonly) NSArray<NSDictionary*>* allEntries;

- (NSDictionary*)valueForProjectAtPath:(NSString*)path;
- (void)setValue:(NSDictionary*)value forProjectAtPath:(NSString*)path;
- (void)removeValueForProjectAtPath:(NSString*)path;
@end
