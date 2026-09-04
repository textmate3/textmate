#import <Cocoa/Cocoa.h>

// The attribute a rendered run carries: the scope, as text, of the rule that
// matched there.
extern NSAttributedStringKey const TMGrammarPreviewScopeAttributeName;

// Runs sample text through the parser with a grammar that exists only in
// memory, the one being edited, and colors the result with the theme a
// document would get: the one chosen for dark or light appearance, or the
// one a scoped setting names. Nothing is saved or looked up by identifier:
// the grammar goes in as the dictionary the editor holds, and includes of
// other grammars resolve through the bundle index as they would for a real
// document.
NS_ASSUME_NONNULL_BEGIN

@interface TMGrammarPreviewRenderer : NSObject
- (instancetype)initWithDarkAppearance:(BOOL)darkAppearance;

// The theme's page colors, for the view showing the rendered text.
@property (nonatomic, readonly) NSColor* backgroundColor;
@property (nonatomic, readonly) NSColor* foregroundColor;

- (NSAttributedString*)render:(NSString*)text grammar:(NSDictionary*)grammar;
@end

NS_ASSUME_NONNULL_END
