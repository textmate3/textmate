// Plain Objective-C, so that a chooser written in Swift can subclass it.
// The marked up row text, which deals in C++ ranges, is in ui/MarkedUpString.h.
//
// A guard by name rather than by file, since this header reaches a compile
// unit twice: from the include farm, and through the Swift header, which
// carries the bridging header's imports by their source path.
#ifndef OAK_CHOOSER_H_6A91F2C8
#define OAK_CHOOSER_H_6A91F2C8

NS_ASSUME_NONNULL_BEGIN

@interface OakFileTableCellView : NSTableCellView
- (instancetype)initWithCloseButton:(NSButton*)closeButton;
@end

@interface OakChooser : NSWindowController
// The one way to make a chooser: it builds its own panel. Declared designated
// so that a Swift subclass can override it and call up to it. The window and
// coder initializers of the superclass are not for choosers.
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithWindow:(nullable NSWindow*)window NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder*)coder NS_UNAVAILABLE;

@property (nonatomic, nullable) SEL action;
@property (nonatomic, weak, nullable) id target;

@property (nonatomic, nullable) NSString* filterString;
@property (nonatomic, readonly) NSArray* selectedItems;

- (void)showWindowRelativeToFrame:(NSRect)parentFrame;

// For subclasses
@property (nonatomic) NSArray* items;
@property (nonatomic, readonly) NSSearchField*      searchField;
@property (nonatomic, readonly) NSScrollView*       scrollView;
@property (nonatomic, readonly) NSTableView*        tableView;
@property (nonatomic, readonly) NSVisualEffectView* footerView;
@property (nonatomic, readonly) NSTextField*        statusTextField;
@property (nonatomic, readonly) NSTextField*        itemCountTextField;
- (void)addTitlebarAccessoryView:(NSView*)titlebarView;
- (void)updateScrollViewInsets;

@property (nonatomic) BOOL drawTableViewAsHighlighted;
- (void)updateFilterString:(NSString*)aString;
- (NSUInteger)removeItemsAtIndexes:(NSIndexSet*)anIndexSet;
- (void)performDefaultButtonClick:(id)sender;
- (void)accept:(id)sender;
- (void)cancel:(id)sender;

// Overridden by each chooser: the first rebuilds the items from the filter
// string, the second the status text from the selected row.
- (void)updateItems:(id)sender;
- (void)updateStatusText:(id)sender;
@end

NS_ASSUME_NONNULL_END

#endif /* end of include guard: OAK_CHOOSER_H_6A91F2C8 */
