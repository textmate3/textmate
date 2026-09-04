#import <Cocoa/Cocoa.h>

// The attribute a rendered run carries: the scope, as text, of the rule that
// matched there.
extern NSAttributedStringKey const TMGrammarPreviewScopeAttributeName;

// Runs sample text through the parser with a grammar that exists only in
// memory, the one being edited, and colors the result with the current
// theme. Nothing is saved or looked up by identifier: the grammar goes in as
// the dictionary the editor holds, and includes of other grammars resolve
// through the bundle index as they would for a real document.
@interface TMGrammarPreviewRenderer : NSObject
- (NSAttributedString*)render:(NSString*)text grammar:(NSDictionary*)grammar;
@end
