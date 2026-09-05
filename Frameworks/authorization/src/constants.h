#ifndef AUTH_CONSTANTS_H_7R7B65WN
#define AUTH_CONSTANTS_H_7R7B65WN

// The privileged helper: a launchd daemon that lives inside the application
// bundle and is registered with the system through SMAppService. The plist
// is the one under Contents/Library/LaunchDaemons, named after the label.
// launchd holds the socket and starts the daemon when something connects.
#define kAuthJobName     "com.textmate3.TextMate.PrivilegedTool"
#define kAuthPlistName   "com.textmate3.TextMate.PrivilegedTool.plist"
#define kAuthSocketPath  "/var/run/com.textmate3.TextMate.PrivilegedTool.sock"
#define kAuthRightName   "com.textmate3.TextMate.openfile"
#define kAuthServerMajor 4
#define kAuthServerMinor 0

#endif /* end of include guard: AUTH_CONSTANTS_H_7R7B65WN */
