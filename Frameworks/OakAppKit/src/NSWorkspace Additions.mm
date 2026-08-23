#import "NSWorkspace Additions.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation NSWorkspace (OakFilenameExtensionIcon)
- (NSImage*)iconForFilenameExtension:(NSString*)extension
{
	UTType* type = [UTType typeWithFilenameExtension:extension];
	if(type && !type.isDeclared)
	{
		// Package types such as tmbundle do not resolve through the plain
		// extension lookup. That returns a synthesised dynamic type, which
		// carries no icon of its own, so asking for a package type by name
		// is the only way to reach the declared icon.
		UTType* packageType = [UTType typeWithFilenameExtension:extension conformingToType:UTTypePackage];
		if(packageType.isDeclared)
			type = packageType;
	}
	return [self iconForContentType:type ?: UTTypeItem];
}
@end
