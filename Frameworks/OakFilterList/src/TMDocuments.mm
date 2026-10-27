#import "TMDocuments.h"
#import <document/OakDocument.h>
#import <document/OakDocumentController.h>
#import <settings/settings.h>
#import <ns/ns.h>

static OakDocument* AsDocument (id document)
{
	return [document isKindOfClass:OakDocument.class] ? document : nil;
}

// The globs the search takes, from the settings that apply to the directory.
// Each setting key names the search option it feeds, and the file chooser's
// own keys sit beside the general ones so that a project can narrow the
// chooser without narrowing the file browser. With no include at all,
// everything is included.
static NSDictionary* SearchOptionsForPath (std::string const& path)
{
	static std::map<std::string, NSString*> const map = {
		{ kSettingsExcludeDirectoriesInFileChooserKey, kSearchExcludeDirectoryGlobsKey },
		{ kSettingsExcludeDirectoriesKey,              kSearchExcludeDirectoryGlobsKey },
		{ kSettingsExcludeFilesInFileChooserKey,       kSearchExcludeFileGlobsKey      },
		{ kSettingsExcludeFilesKey,                    kSearchExcludeFileGlobsKey      },
		{ kSettingsExcludeInFileChooserKey,            kSearchExcludeGlobsKey          },
		{ kSettingsExcludeKey,                         kSearchExcludeGlobsKey          },
		{ kSettingsBinaryKey,                          kSearchExcludeGlobsKey          },
		{ kSettingsIncludeDirectoriesKey,              kSearchDirectoryGlobsKey        },
		{ kSettingsIncludeFilesInFileChooserKey,       kSearchFileGlobsKey             },
		{ kSettingsIncludeFilesKey,                    kSearchFileGlobsKey             },
		{ kSettingsIncludeInFileChooserKey,            kSearchGlobsKey                 },
		{ kSettingsIncludeKey,                         kSearchGlobsKey                 },
	};

	NSMutableDictionary* res = [NSMutableDictionary dictionary];

	settings_t const settings = settings_for_path(NULL_STR, "", path);
	for(auto const& pair : map)
	{
		if(NSString* glob = to_ns(settings.get(pair.first)))
		{
			if(!res[pair.second])
				res[pair.second] = [NSMutableArray array];
			[res[pair.second] addObject:glob];
		}
	}

	if(!res[kSearchDirectoryGlobsKey] && !res[kSearchGlobsKey])
		res[kSearchDirectoryGlobsKey] = @[ @"*" ];
	if(!res[kSearchFileGlobsKey] && !res[kSearchGlobsKey])
		res[kSearchFileGlobsKey] = @[ @"*" ];

	res[kSearchFollowDirectoryLinksKey] = @(settings.get(kSettingsFollowSymbolicLinksKey, false));
	res[kSearchIgnoreOrderingKey]       = @YES;

	return res;
}

@implementation TMDocuments
+ (NSString*)pathOfDocument:(id)document        { return AsDocument(document).path; }
+ (NSString*)displayNameOfDocument:(id)document { return AsDocument(document).displayName ?: @""; }
+ (NSString*)identifierOfDocument:(id)document  { return AsDocument(document).identifier.UUIDString ?: @""; }
+ (NSImage*)iconOfDocument:(id)document         { return AsDocument(document).icon; }
+ (BOOL)isDocumentOpen:(id)document             { return AsDocument(document).isOpen; }

+ (id)documentWithPath:(NSString*)path
{
	return [OakDocument documentWithPath:path];
}

+ (NSArray<NSObject*>*)openDocuments
{
	return OakDocumentController.sharedInstance.openDocuments;
}

+ (NSInteger)lruRankForDocument:(id)document
{
	return [OakDocumentController.sharedInstance lruRankForDocument:AsDocument(document)];
}

+ (void)enumerateDocumentsAtPath:(NSString*)directory usingBlock:(void(^)(id document, BOOL* stop))block
{
	NSDictionary* options = SearchOptionsForPath(to_s(directory));
	[OakDocumentController.sharedInstance enumerateDocumentsAtPath:directory options:options usingBlock:^(OakDocument* document, BOOL* stop){
		block(document, stop);
	}];
}
@end
