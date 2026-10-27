#import "AboutWindowController.h"
#import "TextMate-Swift.h"
#import <OakAppKit/OakUIConstructionFunctions.h>
#import <OakAppKit/OakAppKit-Swift.h>
#import <OakFoundation/OakFoundation.h>
#import <OakFoundation/NSString Additions.h>
#import <BundlesManager/BundlesManager.h>
#import <BundlesManager/BundlesManager-Swift.h>
#import <ns/ns.h>

static NSString* const kUserDefaultsReleaseNotesDigestKey = @"releaseNotesDigest";

static NSData* Digest (NSString* someString)
{
	char const* str = [someString UTF8String];
	char md[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1((unsigned char*)str, strlen(str), (unsigned char*)md);
	return [NSData dataWithBytes:md length:sizeof(md)];
}

// The release notes as shipped, the Markdown itself, which is what the
// Changes page renders and what the digest below is taken over.
static NSURL* ReleaseNotesURL ()
{
	return [NSBundle.mainBundle URLForResource:@"Changes" withExtension:@"md" subdirectory:@"About"];
}

@interface AboutWindowController () <NSWindowDelegate, NSToolbarDelegate>
@property (nonatomic, readonly) NSArray<NSString*>* segmentLabels;
@property (nonatomic) NSToolbar* toolbar;
@property (nonatomic) NSSegmentedControl* segmentedControl;
@property (nonatomic) TMAboutViewController* aboutViewController;
@property (nonatomic) OakMarkdownPageViewController* changesViewController;
@property (nonatomic) OakMarkdownPageViewController* legalViewController;
@property (nonatomic) BundleChangesViewController* bundlesViewController;
@property (nonatomic) TMContributionsViewController* contributionsViewController;
@property (nonatomic) NSString* selectedPage;
@end

@implementation AboutWindowController
+ (instancetype)sharedInstance
{
	static AboutWindowController* sharedInstance = [self new];
	return sharedInstance;
}

+ (void)showChangesIfUpdated
{
	NSURL* url = ReleaseNotesURL();
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		if(NSString* releaseNotes = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nullptr])
		{
			NSData* lastDigest    = [NSUserDefaults.standardUserDefaults dataForKey:kUserDefaultsReleaseNotesDigestKey];
			NSData* currentDigest = Digest(releaseNotes);
			dispatch_async(dispatch_get_main_queue(), ^{
				if(lastDigest && ![lastDigest isEqualToData:currentDigest])
					[AboutWindowController.sharedInstance showChangesWindow:self];
				[NSUserDefaults.standardUserDefaults setObject:currentDigest forKey:kUserDefaultsReleaseNotesDigestKey];
			});
		}
	});
}

- (id)init
{
	NSRect visibleRect = [[NSScreen mainScreen] visibleFrame];
	NSRect rect = NSMakeRect(0, 0, std::min<CGFloat>(700, NSWidth(visibleRect)), std::min<CGFloat>(800, NSHeight(visibleRect)));

	CGFloat dy = NSHeight(visibleRect) - NSHeight(rect);

	rect.origin.y = round(NSMinY(visibleRect) + dy*3/4);
	rect.origin.x = NSMaxY(visibleRect) - NSMaxY(rect);

	NSWindow* win = [[NSPanel alloc] initWithContentRect:rect styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskFullSizeContentView) backing:NSBackingStoreBuffered defer:NO];
	if((self = [super initWithWindow:win]))
	{
		_segmentLabels    = @[ @"About", @"Changes", @"Bundles", @"Legal", @"Contributions" ];
		_segmentedControl = [NSSegmentedControl segmentedControlWithLabels:_segmentLabels trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(takeSelectedSegmentFrom:)];

		self.toolbar = [[NSToolbar alloc] initWithIdentifier:@"About TextMate"];
		[self.toolbar setAllowsUserCustomization:NO];
		[self.toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
		[self.toolbar setDelegate:self];
		[win setToolbar:self.toolbar];

		[win setFrameAutosaveName:@"BundlesReleaseNotes"];
		[win setDelegate:self];
		[win setAutorecalculatesKeyViewLoop:YES];
		[win setHidesOnDeactivate:NO];
		[win setTitleVisibility:NSWindowTitleHidden];

		// The window takes its minimum size from whichever content view is in
		// it, so every page declares the same 560 by 200.
		self.selectedPage = @"About";
	}
	return self;
}

- (void)showAboutWindow:(id)sender
{
	self.selectedPage = @"About";
	[self showWindow:self];
}

- (void)showChangesWindow:(id)sender
{
	self.selectedPage = @"Changes";
	[self showWindow:self];

	if(NSString* releaseNotes = [NSString stringWithContentsOfURL:ReleaseNotesURL() encoding:NSUTF8StringEncoding error:nullptr])
		[NSUserDefaults.standardUserDefaults setObject:Digest(releaseNotes) forKey:kUserDefaultsReleaseNotesDigestKey];
}

- (void)takeSelectedSegmentFrom:(id)sender
{
	if(sender == _segmentedControl)
		self.selectedPage = _segmentLabels[_segmentedControl.selectedSegment];
	else if([sender respondsToSelector:@selector(representedObject)])
		self.selectedPage = [sender representedObject];
}

// The Changes.json at the top of each installed bundle, which the catalog
// writes into every archive. A bundle from elsewhere has none and is skipped
// on the Swift side.
- (NSArray<NSURL*>*)bundleChangesFiles
{
	NSMutableArray<NSURL*>* files = [NSMutableArray array];
	for(Bundle* bundle in BundlesManager.sharedInstance.bundles)
	{
		if(bundle.installed && bundle.path)
			[files addObject:[NSURL fileURLWithPath:[bundle.path stringByAppendingPathComponent:@"Changes.json"]]];
	}
	return files;
}

- (void)setSelectedPage:(NSString*)pageName
{
	if(_selectedPage == pageName || [_selectedPage isEqualToString:pageName])
		return;
	_selectedPage = pageName;

	// Every page is native. The pages over files shipped with the application
	// are built once, since those files do not change while it runs. The
	// Bundles page is built each time it is shown, so that a bundle installed
	// since the last look is in the list.
	if([pageName isEqualToString:@"About"])
	{
		if(!self.aboutViewController)
			self.aboutViewController = [[TMAboutViewController alloc] init];
		self.window.contentView = self.aboutViewController.view;
	}
	else if([pageName isEqualToString:@"Changes"])
	{
		if(!self.changesViewController)
			self.changesViewController = [[OakMarkdownPageViewController alloc] initWithFileURL:ReleaseNotesURL()];
		self.window.contentView = self.changesViewController.view;
	}
	else if([pageName isEqualToString:@"Legal"])
	{
		if(!self.legalViewController)
			self.legalViewController = [[OakMarkdownPageViewController alloc] initWithFileURL:[NSBundle.mainBundle URLForResource:@"Legal" withExtension:@"md" subdirectory:@"About"]];
		self.window.contentView = self.legalViewController.view;
	}
	else if([pageName isEqualToString:@"Bundles"])
	{
		self.bundlesViewController = [[BundleChangesViewController alloc] initWithChangesFiles:[self bundleChangesFiles]];
		self.window.contentView = self.bundlesViewController.view;
	}
	else if([pageName isEqualToString:@"Contributions"])
	{
		if(!self.contributionsViewController)
			self.contributionsViewController = [[TMContributionsViewController alloc] init];
		self.window.contentView = self.contributionsViewController.view;
	}
	else
	{
		return;
	}

	_segmentedControl.selectedSegment = [_segmentLabels indexOfObject:pageName];
}

- (void)selectPageAtRelativeOffset:(NSInteger)offset
{
	NSUInteger index = [_segmentLabels indexOfObject:self.selectedPage];
	if(index != NSNotFound)
		self.selectedPage = _segmentLabels[(index + _segmentLabels.count + offset) % _segmentLabels.count];
}

- (IBAction)selectNextTab:(id)sender     { [self selectPageAtRelativeOffset:+1]; }
- (IBAction)selectPreviousTab:(id)sender { [self selectPageAtRelativeOffset:-1]; }

// ====================
// = Toolbar Delegate =
// ====================

- (NSToolbarItem*)toolbar:(NSToolbar*)aToolbar itemForItemIdentifier:(NSString*)anIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem* res = [[NSToolbarItem alloc] initWithItemIdentifier:anIdentifier];
	if(![anIdentifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier])
		res.view = _segmentedControl;
	return res;
}

- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)aToolbar
{
	return [self toolbarDefaultItemIdentifiers:aToolbar];
}

- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)aToolbar
{
	return @[ NSToolbarFlexibleSpaceItemIdentifier, @"TMSegmentedControlIdentifier", NSToolbarFlexibleSpaceItemIdentifier ];
}

- (void)updateShowTabMenu:(NSMenu*)aMenu
{
	if(![[self window] isKeyWindow])
	{
		[aMenu addItemWithTitle:@"No Tabs" action:@selector(nop:) keyEquivalent:@""];
		return;
	}

	for(NSUInteger i = 0; i < _segmentLabels.count; ++i)
	{
		NSString* label = _segmentLabels[i];
		NSMenuItem* item = [aMenu addItemWithTitle:label action:@selector(takeSelectedSegmentFrom:) keyEquivalent:i < 9 ? [NSString stringWithFormat:@"%c", '1' + (char)i] : @""];
		[item setRepresentedObject:label];
		[item setTarget:self];
		[item setState:i == _segmentedControl.selectedSegment ? NSControlStateValueOn : NSControlStateValueOff];
	}
}
@end
