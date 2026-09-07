#import "CommonAncestor.h"

// The deepest folder every path is under,
// taken by path component rather than by character,
// so a folder selected with something inside it answers the folder,
// and a name that merely begins the same way as another is not a shared folder.
// Nothing in common is the root.
// One path is itself.
static NSString* helper (NSArray<NSString*>* paths)
{
	if(paths.count < 2)
		return paths.firstObject;

	NSArray<NSString*>* common = paths.firstObject.stringByStandardizingPath.pathComponents;
	for(NSString* path in paths)
	{
		NSArray<NSString*>* components = path.stringByStandardizingPath.pathComponents;
		NSUInteger shared = 0;
		while(shared < common.count && shared < components.count && [common[shared] isEqualToString:components[shared]])
			++shared;
		common = [common subarrayWithRange:NSMakeRange(0, shared)];
	}
	return common.count ? [NSString pathWithComponents:common] : @"/";
}

NSString* CommonAncestor (NSArray<NSString*>* paths)
{
	NSString* path = helper(paths);
	BOOL isDirectory = NO;
	if([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory)
		path = [path stringByDeletingLastPathComponent];
	return path;
}
