#import <Foundation/Foundation.h>
#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#define JBROOT_NS(p) jbroot(p)
#else
#import <rootless.h>
#define JBROOT_NS(p) ROOT_PATH_NS(p)
#endif
#import "Tweak.h"

#define BUNDLE_ID @"xyz.skitty.morecomplications"
#define ELEMENTS_PER_ROW 4

static NSDictionary *settings;
static BOOL enabled = YES;
static int rows = 2;

%hook CSGraphicComplicationLayoutProvider

// allow adding more elements to the complication
+ (bool)canAddElement:(CSComplicationLayoutElement *)element toElements:(NSArray<CSComplicationLayoutElement *> *)elements {
	if (!enabled) return %orig;
	long long totalWidth = 0;
	for (CSComplicationLayoutElement *e in elements) {
		totalWidth += e.gridWidth;
	}
	return totalWidth + element.gridWidth <= rows * ELEMENTS_PER_ROW;
}

// change the height of the complication container to fit more rows
+ (double)complicationContainerHeight {
	double complicationContainerHeight = %orig;
	if (!enabled) return complicationContainerHeight;
	double spacing = [%c(CSGraphicComplicationLayoutProvider) complicationEdgeInset];
	return complicationContainerHeight * rows + spacing * (rows - 1);
}

// handle the positions of the complications
+ (NSDictionary<CSComplicationLayoutElement *, NSValue *> *)_framesForLayoutElements:(NSArray<CSComplicationLayoutElement *> *)elements containerSize:(CGSize)containerSize {
	if (!enabled || elements.count == 0) return %orig;

	int groupWidths[rows];
	memset(groupWidths, 0, sizeof(groupWidths));

	NSMutableArray *groups = [[NSMutableArray alloc] initWithCapacity:rows];
	for (int i = 0; i < rows; ++i) {
		[groups addObject:[[NSMutableArray alloc] initWithCapacity:ELEMENTS_PER_ROW]];
	}

	// put each element in the first group that can fit it
	for (CSComplicationLayoutElement *element in elements) {
		for (int i = 0; i < rows; i++) {
			if (groupWidths[i] + element.gridWidth <= ELEMENTS_PER_ROW) {
				groupWidths[i] += element.gridWidth;
				[groups[i] addObject:element];
				break;
			}
		}
	}

	// get the original container size so we can reuse the original function
	double spacing = [%c(CSGraphicComplicationLayoutProvider) complicationEdgeInset];
	CGSize smallContainerSize = containerSize;
	smallContainerSize.height -= spacing * (rows - 1);
	smallContainerSize.height /= rows;

	NSMutableDictionary<CSComplicationLayoutElement *, NSValue *> *newFrames = [[NSMutableDictionary alloc] initWithCapacity:elements.count];

	for (int i = 0; i < rows; i++) {
		NSArray<CSComplicationLayoutElement *> *group = groups[i];
		if (group.count == 0) break;

		NSDictionary<CSComplicationLayoutElement *, NSValue *> *frames = %orig(group, smallContainerSize);

		[frames enumerateKeysAndObjectsUsingBlock:^(CSComplicationLayoutElement *element, NSValue *value, BOOL *stop) {
			NSRect frame = [value CGRectValue];
			frame.origin.y += i * (smallContainerSize.height + spacing);
			newFrames[element] = [NSValue valueWithCGRect:frame];
		}];
	}

	return newFrames;
}

%end

// Preference updates
void refreshPrefs() {
	CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		settings = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keyList);
	} else {
		settings = nil;
	}
	if (!settings) {
		NSString *settingsPath = JBROOT_NS(@"/var/mobile/Library/Preferences/");
		settings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@%@.plist", settingsPath, BUNDLE_ID]];
	}

	enabled = settings[@"enabled"] ? [settings[@"enabled"] boolValue] : YES;
	rows = settings[@"rows"] ? [settings[@"rows"] intValue] : 2;
	if (rows < 1) rows = 1;
	if (rows > 8) rows = 8;
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  refreshPrefs();
}

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, (CFStringRef)[NSString stringWithFormat:@"%@.prefschanged", BUNDLE_ID], NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	refreshPrefs();
}
