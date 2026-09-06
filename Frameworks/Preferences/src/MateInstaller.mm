#import "MateInstaller.h"
#import "Keys.h"
#import <OakFoundation/NSString Additions.h>
#import <SoftwareUpdate/OakCompareVersionStrings.h>
#import <io/path.h>
#import <io/exec.h>
#import <ns/ns.h>
#import <regexp/regexp.h>
#import <authorization/server.h>

// Asks the privileged helper to do what this process cannot: one action
// with its arguments, answered by what went wrong or nothing.
static bool run_privileged (osx::authorization_t& auth, std::string const& action, std::vector<std::string> const& arguments)
{
	if(connection_t conn = connect_to_auth_server(auth))
	{
		conn << action;
		for(auto const& argument : arguments)
			conn << argument;

		std::string error;
		conn >> error;
		if(error == NULL_STR)
			return true;
		fprintf(stderr, "MateInstaller: privileged helper: %s\n", error.c_str());
	}
	errno = EPERM;
	return false;
}

static bool mk_dir (std::string const& path, osx::authorization_t& auth)
{
	struct stat buf;
	if(stat(path.c_str(), &buf) == 0)
	{
		if(S_ISDIR(buf.st_mode))
			return true;
	}
	else if(path != "/" && mk_dir(path::parent(path), auth))
	{
		if(access(path::parent(path).c_str(), W_OK) == 0)
		{
			if(mkdir(path.c_str(), S_IRWXU|S_IRWXG|S_IRWXO) == 0)
				return true;
			perrorf("MateInstaller: mkdir(\"%s\")", path.c_str());
		}
		else
		{
			if(run_privileged(auth, "mkdir", { path }))
				return true;
			perrorf("MateInstaller: privileged mkdir \"%s\"", path.c_str());
		}
	}
	return false;
}

static bool rm_path (std::string const& path, osx::authorization_t& auth)
{
	struct stat buf;
	if(lstat(path.c_str(), &buf) != 0)
		return true;

	if(access(path::parent(path).c_str(), W_OK) == 0)
	{
		if(unlink(path.c_str()) == 0)
			return true;
		perrorf("MateInstaller: unlink \"%s\"", path.c_str());
	}
	else
	{
		if(run_privileged(auth, "remove", { path }))
			return true;
		perrorf("MateInstaller: privileged remove \"%s\"", path.c_str());
	}
	return false;
}

static bool cp_requires_admin (std::string const& dst)
{
	return access(dst.c_str(), W_OK) != 0 && (access(dst.c_str(), X_OK) == 0 || access(path::parent(dst).c_str(), W_OK) != 0);
}

static bool cp_path (std::string const& src, std::string const& dst, osx::authorization_t& auth)
{
	if(!cp_requires_admin(dst))
	{
		if(copyfile(src.c_str(), dst.c_str(), NULL, COPYFILE_ALL | COPYFILE_NOFOLLOW_SRC) == 0)
			return true;
		perrorf("MateInstaller: copyfile(\"%s\", \"%s\", NULL, COPYFILE_ALL | COPYFILE_NOFOLLOW_SRC)", src.c_str(), dst.c_str());
	}
	else
	{
		if(run_privileged(auth, "copy", { src, dst }))
			return true;
		perrorf("MateInstaller: privileged copy \"%s\" \"%s\"", src.c_str(), dst.c_str());
	}
	return false;
}

static bool install_mate (std::string const& src, std::string const& dst)
{
	osx::authorization_t auth;
	if(mk_dir(path::parent(dst), auth))
	{
		struct stat buf;
		if(lstat(dst.c_str(), &buf) == 0 && !S_ISREG(buf.st_mode) && !rm_path(dst, auth))
			return false;
		return cp_path(src, dst, auth);
	}
	return false;
}

static bool uninstall_mate (std::string const& path)
{
	osx::authorization_t auth;
	return access(path.c_str(), F_OK) != 0 || rm_path(path, auth);
}

// What the bundled mate says it is, or nil.
static NSString* bundled_mate_version (NSString* matePath)
{
	std::string res = io::exec(to_s(matePath), "--version", NULL);
	if(regexp::match_t const& m = regexp::search("\\Amate ([\\d.]+)", res))
		return [NSString stringWithCxxString:m[1]];
	return nil;
}

@implementation MateInstaller
+ (NSString*)bundledMatePath
{
	return [NSBundle.mainBundle pathForAuxiliaryExecutable:@"mate"];
}

+ (BOOL)bundledMateExists
{
	return self.bundledMatePath != nil;
}

+ (NSString*)installedPath
{
	NSString* path = [[NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsMateInstallPathKey] stringByExpandingTildeInPath];
	if(path && access([path fileSystemRepresentation], F_OK) != 0)
	{
		[NSUserDefaults.standardUserDefaults removeObjectForKey:kUserDefaultsMateInstallPathKey];
		[NSUserDefaults.standardUserDefaults removeObjectForKey:kUserDefaultsMateInstallVersionKey];
		path = nil;
	}
	return path;
}

+ (BOOL)installAtPath:(NSString*)path
{
	NSString* source = self.bundledMatePath;
	if(!source || !install_mate(to_s(source), to_s(path)))
		return NO;

	[NSUserDefaults.standardUserDefaults setObject:path forKey:kUserDefaultsMateInstallPathKey];
	if(NSString* version = bundled_mate_version(source))
		[NSUserDefaults.standardUserDefaults setObject:version forKey:kUserDefaultsMateInstallVersionKey];
	return YES;
}

+ (BOOL)uninstall
{
	NSString* path = self.installedPath;
	if(path && !uninstall_mate(to_s(path)))
		return NO;

	[NSUserDefaults.standardUserDefaults removeObjectForKey:kUserDefaultsMateInstallPathKey];
	[NSUserDefaults.standardUserDefaults removeObjectForKey:kUserDefaultsMateInstallVersionKey];
	return YES;
}

+ (void)updateIfRequired
{
	NSString* oldMate    = [[NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsMateInstallPathKey] stringByExpandingTildeInPath];
	NSString* oldVersion = [NSUserDefaults.standardUserDefaults stringForKey:kUserDefaultsMateInstallVersionKey];
	NSString* newMate    = self.bundledMatePath;
	if(!oldMate || !newMate)
		return;

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSString* newVersion = bundled_mate_version(newMate);
		if(!newVersion || OakCompareVersionStrings(oldVersion, newVersion) != NSOrderedAscending)
			return;

		if(cp_requires_admin(to_s(oldMate)))
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert* alert        = [[NSAlert alloc] init];
				alert.messageText     = @"Update Shell Support";
				alert.informativeText = [NSString stringWithFormat:@"Would you like to update the installed version of mate to version %@?", newVersion];
				[alert addButtonWithTitle:@"Update"];
				[alert addButtonWithTitle:@"Cancel"];
				if([alert runModal] == NSAlertFirstButtonReturn)
				{
					if(!install_mate(to_s(newMate), to_s(oldMate)))
						return;
				}

				// Avoid asking again by storing the new version number
				[NSUserDefaults.standardUserDefaults setObject:newVersion forKey:kUserDefaultsMateInstallVersionKey];
			});
		}
		else
		{
			if(install_mate(to_s(newMate), to_s(oldMate)))
				[NSUserDefaults.standardUserDefaults setObject:newVersion forKey:kUserDefaultsMateInstallVersionKey];
		}
	});
}
@end
