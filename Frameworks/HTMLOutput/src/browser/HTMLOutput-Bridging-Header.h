// What the framework's Swift sees of its Objective-C. Plain Objective-C only:
// the Swift compiler cannot read Objective-C++ headers. Cocoa comes first
// because the headers below count on the prelude, which this file has none of.
// It sits in browser/ because rave looks for it beside the first Swift source.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "../HOFileHandleSchemeHandler.h"
#import "../helpers/HOJSBridge.h"
