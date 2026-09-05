#import <Foundation/Foundation.h>

// The first launch of an application with its own identity on a machine
// that has TextMate 2's: copies the preferences from TextMate 2's defaults
// domain when this application's is empty, and copies TextMate 2's
// Application Support directory when this application's does not exist.
// After that the two applications no longer see each other. Runs before
// anything reads either, so it is called first thing in main.
void ImportFromTextMate2IfNeeded ();
