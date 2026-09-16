// The commit message field is TextMate's own editor, so the window gets syntax
// highlighting, bundle items and every key binding a person already knows.
//
// `OakDocumentView` cannot be handed to Swift directly, because its header
// reaches Objective-C++ and the Swift compiler reads plain Objective-C only.
// This is the narrow face over it, and it is the only thing the Swift side
// needs to know about the editor.

NS_ASSUME_NONNULL_BEGIN

@interface CommitMessageView : NSView
// The grammar to highlight with, as a scope name. `text.plain` when the source
// control system has no commit grammar in any installed bundle.
+ (NSString*)fileTypeForSCMName:(NSString*)scmName;

@property (nonatomic, copy) NSString* content;

// Where the document claims to be, so `.tm_properties` in the project applies
// to the commit message the way it would to a file there.
- (void)setContent:(NSString*)content fileType:(NSString*)fileType virtualPath:(NSString*)virtualPath;
- (void)makeFirstResponder;
@end

NS_ASSUME_NONNULL_END
