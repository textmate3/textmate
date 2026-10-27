// The source control status of a directory, for the file chooser's list of
// uncommitted documents. The status comes from C++ in scm/scm.h, which
// watches the repository and calls back when it changes, and this plain
// Objective-C stands in front of it for the Swift.
#ifndef TM_SOURCE_CONTROL_STATUS_H_8D4F2B16
#define TM_SOURCE_CONTROL_STATUS_H_8D4F2B16

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMSourceControlStatus : NSObject
// nil when the path is not under source control.
+ (nullable instancetype)statusForPath:(NSString*)path;
// The files with local changes: modified, added, deleted or conflicted.
@property (nonatomic, readonly) NSArray<NSString*>* uncommittedPaths;
// Called whenever the status changes, on the main thread.
@property (nonatomic, copy, nullable) void(^updateHandler)(void);
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_SOURCE_CONTROL_STATUS_H_8D4F2B16 */
