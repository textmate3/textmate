// What the choosers, in Swift, need from documents and the document
// controller. The document class is declared with C++ types, which the Swift
// cannot see, so a document travels as an untyped object and this plain
// Objective-C answers for it.
#ifndef TM_DOCUMENTS_H_3A8C1F57
#define TM_DOCUMENTS_H_3A8C1F57

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMDocuments : NSObject
+ (nullable NSString*)pathOfDocument:(id)document;
+ (NSString*)displayNameOfDocument:(id)document;
+ (NSString*)identifierOfDocument:(id)document;
+ (nullable NSImage*)iconOfDocument:(id)document;
+ (BOOL)isDocumentOpen:(id)document;

// The document for the path, open or not.
+ (id)documentWithPath:(NSString*)path;
+ (NSArray<NSObject*>*)openDocuments NS_SWIFT_NAME(openDocuments());
// Where the document stands in the order of recent use, higher being more recent.
+ (NSInteger)lruRankForDocument:(id)document;

// Every file under the directory as a document, by the include and exclude
// settings that apply to the directory, each handed to the block on the
// calling thread as it is found, until the block sets stop.
+ (void)enumerateDocumentsAtPath:(NSString*)directory usingBlock:(void(^)(id document, BOOL* stop))block NS_SWIFT_NAME(enumerateDocuments(atPath:using:));
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_DOCUMENTS_H_3A8C1F57 */
