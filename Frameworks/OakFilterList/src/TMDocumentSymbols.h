// What the symbol chooser, in Swift, needs from a document: its symbols with
// their positions, and the start of each range in a selection string. The document class is declared with C++
// types, which the Swift cannot see, so it stands behind this plain
// Objective-C and travels as an untyped object.
#ifndef TM_DOCUMENT_SYMBOLS_H_9B3E5F12
#define TM_DOCUMENT_SYMBOLS_H_9B3E5F12

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// A place in a document. The string is the one based form the editor writes
// into selection strings, "12:5", or "12" when the column is the first.
@interface TMTextPosition : NSObject
@property (nonatomic, readonly) NSUInteger line;
@property (nonatomic, readonly) NSUInteger column;
@property (nonatomic, readonly) NSString* string;
- (NSComparisonResult)compare:(TMTextPosition*)other;
@end

@interface TMDocumentSymbol : NSObject
@property (nonatomic, readonly) TMTextPosition* position;
@property (nonatomic, readonly) NSString* name;
@end

@interface TMDocumentSymbols : NSObject
// The document's symbols in order, as the grammar marked them. Empty for a
// document that is not loaded.
+ (NSArray<TMDocumentSymbol*>*)symbolsInDocument:(id)document;
// Where each range in the selection string begins.
+ (NSArray<TMTextPosition*>*)rangeStartsInSelectionString:(NSString*)selectionString;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: TM_DOCUMENT_SYMBOLS_H_9B3E5F12 */
