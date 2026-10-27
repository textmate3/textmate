// What the framework's Swift sees of its Objective-C. Plain Objective-C only:
// the Swift compiler cannot read Objective-C++ headers. Cocoa comes first
// because the headers below count on the prelude, which this file has none of.
// It sits beside the first Swift source because rave looks for it there.
#import <Cocoa/Cocoa.h>
#import <OakAppKit/NSColor Additions.h>
#import <OakAppKit/NSImage Additions.h>
#import <OakAppKit/OakKeyEquivalentView.h>
#import <OakAppKit/OakRolloverButton.h>
#import <OakAppKit/OakScopeBarView.h>
#import <OakAppKit/OakTableViewActions.h>
#import <document/OakProjectStateStore.h>
#import "OakChooser.h"
#import "TMBundleItems.h"
#import "TMDocumentSymbols.h"
#import "TMDocuments.h"
#import "TMGlob.h"
#import "TMPaths.h"
#import "TMRanker.h"
#import "TMScopeContext.h"
#import "TMSourceControlStatus.h"
