#import "MCSettingsController.h"
#import "Preferences.h"
#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#define JBROOT_STR(p) jbroot(p)
#else
#import <rootless.h>
#define JBROOT_STR(p) ROOT_PATH(p)
#endif
#import <spawn.h>
#import <sys/wait.h>
extern char **environ;

@implementation MCSettingsController

- (void)respring {
	// kill PostBoard too
	pid_t pid;
	const char *argv[] = {JBROOT_STR("/usr/bin/killall"), "-9", "PosterBoard", NULL};
	if (posix_spawn(&pid, argv[0], NULL, NULL, (char* const*)argv, environ) == 0) {
		waitpid(pid, NULL, 0);
	}

	// respring
	SBSRelaunchAction *restartAction = [NSClassFromString(@"SBSRelaunchAction") actionWithReason:@"RestartRenderServer" options:SBSRelaunchOptionsFadeToBlack targetURL:[NSURL URLWithString:@"prefs:root=MoreComplications"]];
	NSSet *actions = [NSSet setWithObject:restartAction];
	FBSSystemService *frontBoardService = [NSClassFromString(@"FBSSystemService") sharedService];
	[frontBoardService sendActions:actions withResult:nil];
}

@end
