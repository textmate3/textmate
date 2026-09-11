#import "Preferences.h"
#import "Keys.h"
#import "Preferences-Swift.h"
#import <OakAppKit/OakTransitionViewController.h>

static NSString* const kUserDefaultsPreferencesWindowFrameTopLeftKey = @"preferencesWindowFrameTopLeft";
static NSString* const kUserDefaultsPreferencesSelectedPaneKey       = @"preferencesSelectedPane";

// =============================
// = PreferencesViewController =
// =============================

@interface PreferencesViewController : OakTransitionViewController
@property (nonatomic) NSString* selectedViewIdentifier;
@end

@implementation PreferencesViewController
- (void)viewWillAppear
{
	// A remembered pane that no longer exists, such as one renamed since, falls back to the first.
	NSString* viewIdentifier = [NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsPreferencesSelectedPaneKey];
	if(![self viewControllerForIdentifier:viewIdentifier])
		viewIdentifier = self.childViewControllers.firstObject.identifier;
	self.selectedViewIdentifier = viewIdentifier;
}

- (void)setSelectedViewIdentifier:(NSString*)viewIdentifier
{
	if(_selectedViewIdentifier == viewIdentifier || [_selectedViewIdentifier isEqual:viewIdentifier])
		return;

	NSViewController* oldViewController = [self viewControllerForIdentifier:_selectedViewIdentifier];
	if(oldViewController && ![oldViewController commitEditing])
	{
		self.view.window.toolbar.selectedItemIdentifier = oldViewController.identifier;
		return;
	}

	_selectedViewIdentifier = viewIdentifier;
	self.view.window.toolbar.selectedItemIdentifier = viewIdentifier;
	[NSUserDefaults.standardUserDefaults setObject:_selectedViewIdentifier forKey:kUserDefaultsPreferencesSelectedPaneKey];

	NSViewController* newViewController = [self viewControllerForIdentifier:viewIdentifier];
	self.title = newViewController.title ?: @"Preferences";

	self.subview = newViewController.view;

	BOOL setNewFirstResponder = self.view.window.firstResponder == self.view.window;
	[self.view.window recalculateKeyViewLoop];
	NSView* newKeyView = newViewController.view.nextValidKeyView;
	if(setNewFirstResponder && newKeyView && [newKeyView isDescendantOf:newViewController.view])
		[self.view.window makeFirstResponder:newKeyView];
}

- (NSViewController <PreferencesPaneProtocol>*)viewControllerForIdentifier:(NSString*)viewIdentifier
{
	for(NSViewController <PreferencesPaneProtocol>* viewController in self.childViewControllers)
	{
		if([viewController.identifier isEqual:viewIdentifier])
			return viewController;
	}
	return nil;
}
@end

// ===============================
// = PreferencesWindowController =
// ===============================

@interface Preferences () <NSToolbarDelegate, NSWindowDelegate>
@property (nonatomic) PreferencesViewController* preferencesViewController;
@end

@implementation Preferences
+ (instancetype)sharedInstance
{
	static Preferences* sharedInstance = [self new];
	return sharedInstance;
}

// The six panes, in the order both arrangements show them.
static NSArray<NSViewController<PreferencesPaneProtocol>*>* PreferencePaneControllers ()
{
	return @[
		[[TMFilesPaneController alloc] init],
		[[TMProjectsPaneController alloc] init],
		[[TMBundlesPaneController alloc] init],
		[[TMVariablesPaneController alloc] init],
		[[TMUpdatesPaneController alloc] init],
		[[TMTerminalPaneController alloc] init]
	];
}

// A spike: the panes in a sidebar, the way System Settings arranges them,
// rather than as a row of toolbar tabs. Off unless the default says otherwise.
//
//   defaults write com.textmate3.TextMate preferencesUsesSidebar -bool YES
static BOOL PreferencesUsesSidebar ()
{
	return [NSUserDefaults.standardUserDefaults boolForKey:@"preferencesUsesSidebar"];
}

- (instancetype)initWithSidebar
{
	NSArray<NSViewController<PreferencesPaneProtocol>*>* viewControllers = PreferencePaneControllers();
	TMPreferencesSidebarController* contentViewController = [[TMPreferencesSidebarController alloc] initWithPaneControllers:viewControllers selectedPaneDefault:kUserDefaultsPreferencesSelectedPaneKey];

	NSWindow* window = [NSPanel windowWithContentViewController:contentViewController];
	if(NSString* topLeft = [NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsPreferencesWindowFrameTopLeftKey])
		[window setFrameTopLeftPoint:NSPointFromString(topLeft)];

	if((self = [super initWithWindow:window]))
	{
		// A sidebar window is wider and taller than a tabbed one, since the
		// list takes a column of its own and the panes were laid out for the
		// narrower window.
		[window setContentSize:NSMakeSize(720, 460)];
		window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary;
		window.delegate           = self;
		window.hidesOnDeactivate  = NO;
		window.title              = @"Preferences";
	}
	return self;
}

- (instancetype)init
{
	if(PreferencesUsesSidebar())
		return [self initWithSidebar];

	PreferencesViewController* contentViewController = [[PreferencesViewController alloc] init];

	NSWindow* window = [NSPanel windowWithContentViewController:contentViewController];
	if(NSString* topLeft = [NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsPreferencesWindowFrameTopLeftKey])
		[window setFrameTopLeftPoint:NSPointFromString(topLeft)];

	if((self = [super initWithWindow:window]))
	{
		_preferencesViewController = contentViewController;

		NSArray<NSViewController <PreferencesPaneProtocol>*>* viewControllers = PreferencePaneControllers();

		for(NSViewController* viewController in viewControllers)
			[contentViewController addChildViewController:viewController];

		NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"Preferneces"];
		toolbar.allowsUserCustomization = NO;
		toolbar.delegate                = self;

		BOOL hasToolbarImages = NO;
		for(NSViewController* viewController in viewControllers)
			hasToolbarImages = hasToolbarImages || [viewController respondsToSelector:@selector(toolbarItemImage)];
		toolbar.displayMode = hasToolbarImages ? NSToolbarDisplayModeIconAndLabel : NSToolbarDisplayModeLabelOnly;

		window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary;
		window.delegate           = self;
		window.hidesOnDeactivate  = NO;
		window.toolbar            = toolbar;
		window.toolbarStyle       = NSWindowToolbarStylePreference;
	}
	return self;
}

- (void)windowDidMove:(NSNotification*)aNotification
{
   [NSUserDefaults.standardUserDefaults setObject:NSStringFromPoint(NSMakePoint(NSMinX(self.window.frame), NSMaxY(self.window.frame))) forKey:kUserDefaultsPreferencesWindowFrameTopLeftKey];
}

- (void)selectViewAtRelativeOffset:(NSInteger)offset
{
	NSArray* identifiers = [self toolbarSelectableItemIdentifiers:self.window.toolbar];
	NSUInteger index = [identifiers indexOfObject:_preferencesViewController.selectedViewIdentifier];
	if(index != NSNotFound)
			_preferencesViewController.selectedViewIdentifier = identifiers[(index + identifiers.count + offset) % identifiers.count];
	else	_preferencesViewController.selectedViewIdentifier = offset < 0 ? identifiers.lastObject : identifiers.firstObject;
}

- (void)selectNextTab:(id)sender     { [self selectViewAtRelativeOffset:+1]; }
- (void)selectPreviousTab:(id)sender { [self selectViewAtRelativeOffset:-1]; }

- (void)updateShowTabMenu:(NSMenu*)aMenu
{
	if(!self.isWindowLoaded || !self.window.isKeyWindow)
		return;

	NSString* const selectedIdentifier = _preferencesViewController.selectedViewIdentifier;

	int i = 0;
	for(NSViewController* viewController in _preferencesViewController.childViewControllers)
	{
		NSMenuItem* item = [aMenu addItemWithTitle:viewController.title action:@selector(takeSelectedViewControllerIdentifierFrom:) keyEquivalent:i < 9 ? [NSString stringWithFormat:@"%c", '1' + i] : @""];
		item.representedObject = viewController.identifier;
		item.target = self;
		if([viewController.identifier isEqual:selectedIdentifier])
			item.state = NSControlStateValueOn;
		++i;
	}
}

- (void)takeSelectedViewControllerIdentifierFrom:(id)sender
{
	if([sender respondsToSelector:@selector(itemIdentifier)])
		_preferencesViewController.selectedViewIdentifier = [sender itemIdentifier];
	else if([sender respondsToSelector:@selector(representedObject)])
		_preferencesViewController.selectedViewIdentifier = [sender representedObject];
}

// ====================
// = Toolbar Delegate =
// ====================

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem* res = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	res.action = @selector(takeSelectedViewControllerIdentifierFrom:);
	res.target = self;

	if(NSViewController <PreferencesPaneProtocol>* viewController = [_preferencesViewController viewControllerForIdentifier:itemIdentifier])
	{
		res.label = viewController.title;
		if([viewController respondsToSelector:@selector(toolbarItemImage)])
			res.image = viewController.toolbarItemImage;
	}

	return res;
}

- (NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	NSMutableArray* res = [NSMutableArray array];
	for(NSViewController* viewController in _preferencesViewController.childViewControllers)
	{
		if(viewController.identifier)
			[res addObject:viewController.identifier];
	}
	return res;
}

- (NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray<NSToolbarItemIdentifier>*)toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
}
@end
