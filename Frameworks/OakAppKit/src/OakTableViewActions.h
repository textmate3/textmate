// Moving a table's selection from a key event or a text command, the way a
// chooser's search field hands arrow keys to the table under it. Plain
// Objective-C, apart from OakAppKit.h and its C++ default arguments, so that
// a chooser written in Swift can use it. The functions have C linkage for the
// same reason: Swift looks them up by their plain names.
//
// A guard by name rather than by file, since this header reaches a compile
// unit twice: from the include farm, and through a Swift header, which
// carries its bridging header's imports by their source path.
#ifndef OAK_TABLE_VIEW_ACTIONS_H_2D7F8A41
#define OAK_TABLE_VIEW_ACTIONS_H_2D7F8A41

typedef NS_ENUM(NSUInteger, OakPerformTableViewActionResult) {
	OakMoveMoveReturn,
	OakMoveAcceptReturn,
	OakMoveCancelReturn,
	OakMoveNoActionReturn,
};

#ifdef __cplusplus
extern "C" {
#endif

OakPerformTableViewActionResult OakPerformTableViewActionFromKeyEvent (NSTableView* tableView, NSEvent* event);
OakPerformTableViewActionResult OakPerformTableViewActionFromSelector (NSTableView* tableView, SEL selector);

#ifdef __cplusplus
}
#endif

#endif /* end of include guard: OAK_TABLE_VIEW_ACTIONS_H_2D7F8A41 */
