#include "IOAlertPanel.h"
#include "OakTableViewActions.h"
extern NSNotificationName const OakCursorDidHideNotification;

BOOL OakIsAlternateKeyOrMouseEvent (NSUInteger flags = NSEventModifierFlagOption, NSEvent* anEvent = [NSApp currentEvent]);
