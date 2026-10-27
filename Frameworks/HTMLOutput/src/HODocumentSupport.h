// What a page, through the bridge in Swift, needs from the document controller:
// opening a file at a line or a range. The controller is declared with C++
// types, which the Swift cannot see, so it stands behind this plain Objective-C.
#ifndef HO_DOCUMENT_SUPPORT_H_7C3E0B92
#define HO_DOCUMENT_SUPPORT_H_7C3E0B92

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HODocumentSupport : NSObject
// Shows the file in the front project. The options are what the page passed
// to TextMate.openFile: a line number, a range such as "3:4-5:6", or nothing.
+ (void)openFile:(NSString*)path withOptions:(nullable id)options;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: HO_DOCUMENT_SUPPORT_H_7C3E0B92 */
