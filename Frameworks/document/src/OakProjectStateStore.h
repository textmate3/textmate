// Per-project session state, keyed by project path: open documents, window frame, file browser
// state, and the last-used date that orders the Open Recent Project window. Values are property
// list dictionaries and the whole store persists as one binary property list in Application
// Support. All access is from the main thread.
//
// A guard by name rather than by file, since this header reaches a compile unit twice: from the
// include farm, and through a Swift header, which carries its bridging header's imports by their
// source path.
#ifndef OAK_PROJECT_STATE_STORE_H_1C5D7E93
#define OAK_PROJECT_STATE_STORE_H_1C5D7E93

NS_ASSUME_NONNULL_BEGIN

@interface OakProjectStateStore : NSObject
@property (class, readonly) OakProjectStateStore* sharedInstance;

// Entries as @{ @"key": path, @"value": info } pairs, so callers can sort on key paths into both.
@property (nonatomic, readonly) NSArray<NSDictionary*>* allEntries;

- (nullable NSDictionary*)valueForProjectAtPath:(NSString*)path NS_SWIFT_NAME(state(forProjectAtPath:));
- (void)setValue:(NSDictionary*)value forProjectAtPath:(NSString*)path NS_SWIFT_NAME(setState(_:forProjectAtPath:));
- (void)removeValueForProjectAtPath:(NSString*)path NS_SWIFT_NAME(removeState(forProjectAtPath:));
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: OAK_PROJECT_STATE_STORE_H_1C5D7E93 */
