// What the framework's Swift sees of its Objective-C. Plain Objective-C only:
// the Swift compiler cannot read Objective-C++ headers. Cocoa comes first
// because the headers below count on the prelude, which this file has none of.
// It sits beside the first Swift source because rave looks for it there.
#import <Cocoa/Cocoa.h>
#import <OakAppKit/NSColor Additions.h>
#import "OakChooser.h"
#import "TMDocumentSymbols.h"
#import "TMRanker.h"
