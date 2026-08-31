#import "OakProjectStateStore.h"
#import <sqlite3.h>

// The store lives at RecentProjects.plist. RecentProjects.db beside it is a SQLite database written
// by earlier versions of the application, one row per project, each value a keyed archive. The first
// launch that finds no plist but does find the database migrates every row, so nobody loses their
// per-project tabs and window state. The database file itself is left untouched, so going back to an
// earlier version of the application loses nothing either.
static NSString* ApplicationSupportPath ()
{
	return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"TextMate"];
}

static NSDictionary* MigratedEntriesFromDatabase (NSString* databasePath)
{
	sqlite3* db = nullptr;
	if(sqlite3_open_v2(databasePath.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY, nullptr) != SQLITE_OK)
	{
		sqlite3_close(db);
		return nil;
	}

	NSMutableDictionary* res = [NSMutableDictionary dictionary];

	sqlite3_stmt* stmt = nullptr;
	if(sqlite3_prepare_v2(db, "SELECT key, value FROM kvdb", -1, &stmt, nullptr) == SQLITE_OK)
	{
		NSSet* propertyListClasses = [NSSet setWithObjects:NSDictionary.class, NSArray.class, NSString.class, NSNumber.class, NSDate.class, NSData.class, nil];
		while(sqlite3_step(stmt) == SQLITE_ROW)
		{
			char const* keyText = (char const*)sqlite3_column_text(stmt, 0);
			void const* blob    = sqlite3_column_blob(stmt, 1);
			int blobLength      = sqlite3_column_bytes(stmt, 1);
			if(!keyText || !blob || blobLength == 0)
				continue;

			NSData* data = [NSData dataWithBytes:blob length:blobLength];
			NSDictionary* value = [NSKeyedUnarchiver unarchivedObjectOfClasses:propertyListClasses fromData:data error:nullptr];
			if([value isKindOfClass:[NSDictionary class]] && [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0])
				res[@(keyText)] = value;
		}
		sqlite3_finalize(stmt);
	}

	sqlite3_close(db);
	return res;
}

@interface OakProjectStateStore ()
{
	NSMutableDictionary* _entries;
	NSString* _path;
}
@end

@implementation OakProjectStateStore
+ (OakProjectStateStore*)sharedInstance
{
	static OakProjectStateStore* sharedInstance = [self new];
	return sharedInstance;
}

- (id)init
{
	if(self = [super init])
	{
		_path = [ApplicationSupportPath() stringByAppendingPathComponent:@"RecentProjects.plist"];

		if(NSDictionary* stored = [NSDictionary dictionaryWithContentsOfFile:_path])
		{
			_entries = [stored mutableCopy];
		}
		else
		{
			NSString* databasePath = [ApplicationSupportPath() stringByAppendingPathComponent:@"RecentProjects.db"];
			if([NSFileManager.defaultManager fileExistsAtPath:databasePath])
			{
				_entries = [MigratedEntriesFromDatabase(databasePath) mutableCopy];
				if(_entries.count)
					[self save];
			}
			_entries = _entries ?: [NSMutableDictionary dictionary];
		}
	}
	return self;
}

- (void)save
{
	NSError* error;
	NSData* data = [NSPropertyListSerialization dataWithPropertyList:_entries format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
	if(!data || ![data writeToFile:_path options:NSDataWritingAtomic error:&error])
		os_log_error(OS_LOG_DEFAULT, "Failed writing %{public}@: %{public}@", _path, error.localizedDescription);
}

- (NSArray<NSDictionary*>*)allEntries
{
	NSMutableArray* res = [NSMutableArray arrayWithCapacity:_entries.count];
	[_entries enumerateKeysAndObjectsUsingBlock:^(NSString* path, NSDictionary* info, BOOL* stop){
		[res addObject:@{ @"key": path, @"value": info }];
	}];
	return res;
}

- (NSDictionary*)valueForProjectAtPath:(NSString*)path
{
	return path ? _entries[path] : nil;
}

- (void)setValue:(NSDictionary*)value forProjectAtPath:(NSString*)path
{
	if(!path || !value)
		return;
	_entries[path] = value;
	[self save];
}

- (void)removeValueForProjectAtPath:(NSString*)path
{
	if(!path)
		return;
	[_entries removeObjectForKey:path];
	[self save];
}
@end
