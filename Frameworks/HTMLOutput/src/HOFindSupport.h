// What find in an output window, in Swift, needs from the rest of the
// application: the find server behind the Find window, the find and replace
// pasteboards, the find preferences, and the document controller that shows
// a page's source. Each of those is declared with C++ types, which the Swift
// cannot see, so they stand behind this plain Objective-C.
#ifndef HO_FIND_SUPPORT_H_5D2A9E71
#define HO_FIND_SUPPORT_H_5D2A9E71

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// One search asked for by the Find window: what to look for, which way, and
// where to report what was found.
@interface HOFindRequest : NSObject
// The server behind performFindOperation:, or nil when what it asks for is
// not a search, since a page can be searched but not counted or replaced in.
+ (nullable instancetype)requestForFindServer:(id)findServer;
@property (nonatomic, readonly) NSString* findString;
@property (nonatomic, readonly) BOOL backwards;
@property (nonatomic, readonly) BOOL ignoresCase;
@property (nonatomic, readonly) BOOL wrapsAround;
// Tells the Find window whether anything was found and what the match reads
// as, which it shows in its status line. A page has no line and column.
- (void)reportFound:(BOOL)found text:(NSString*)text;
@end

@interface HOFindSupport : NSObject
+ (nullable NSString*)currentFindString;
+ (BOOL)findIgnoresCase;
+ (BOOL)findWrapsAround;
+ (void)addFindPasteboardEntry:(NSString*)string;
+ (void)addReplacePasteboardEntry:(NSString*)string;
// Opens the markup as a new HTML document in the front project.
+ (void)showHTMLSource:(NSString*)html named:(nullable NSString*)name;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: HO_FIND_SUPPORT_H_5D2A9E71 */
