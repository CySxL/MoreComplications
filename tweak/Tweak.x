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
// the lock screen row is four grid units on every iPhone this targets
#define ELEMENTS_PER_ROW 4

static BOOL enabled = YES;
static int rows = 2;
// tenths of the system's own spacing, so 10 is untouched
static int rowSpacing = 10;
static int elementSpacing = 10;

%hook CSGraphicComplicationLayoutProvider

// allow adding more elements to the complication
+ (bool)canAddElement:(CSComplicationLayoutElement *)element toElements:(NSArray<CSComplicationLayoutElement *> *)elements {
	// one row is what the system already does
	if (!enabled || rows == 1) return %orig;
	long long totalWidth = 0;
	for (CSComplicationLayoutElement *e in elements) {
		totalWidth += e.gridWidth;
	}
	return totalWidth + element.gridWidth <= rows * ELEMENTS_PER_ROW;
}

// change the height of the complication container to fit more rows
+ (double)complicationContainerHeight {
	double complicationContainerHeight = %orig;
	if (!enabled || rows == 1) return complicationContainerHeight;
	double rowGap = [self complicationEdgeInset] * (rowSpacing / 10.0);
	return complicationContainerHeight * rows + rowGap * (rows - 1);
}

// handle the positions of the complications
// the dragged-element layout enters here too, so keep the work bounded
+ (NSDictionary<CSComplicationLayoutElement *, NSValue *> *)_framesForLayoutElements:(NSArray<CSComplicationLayoutElement *> *)elements containerSize:(CGSize)containerSize {
	if (!enabled || elements.count == 0) return %orig;
	// one row with untouched spacing is what the system already does
	if (rows == 1 && elementSpacing == 10) return %orig;

	// a preference change can move rows mid-layout, so work off one snapshot
	int rowCount = rows;

	// an element never needs more than a row to itself, which bounds the growth
	int groupWidths[rowCount + elements.count];
	memset(groupWidths, 0, sizeof(groupWidths));

	NSMutableArray *groups = [[NSMutableArray alloc] initWithCapacity:rowCount];
	for (int i = 0; i < rowCount; ++i) {
		[groups addObject:[[NSMutableArray alloc] initWithCapacity:ELEMENTS_PER_ROW]];
	}

	// put each element in the first group that can fit it
	for (CSComplicationLayoutElement *element in elements) {
		int target = -1;
		for (int i = 0; i < rowCount; i++) {
			if (groupWidths[i] + element.gridWidth <= ELEMENTS_PER_ROW) {
				target = i;
				break;
			}
		}
		// the saved complications can outlast a drop in rows, so add a row rather
		// than overfill one and spill off both edges of the screen
		if (target < 0) {
			target = rowCount++;
			[groups addObject:[[NSMutableArray alloc] initWithCapacity:ELEMENTS_PER_ROW]];
		}
		groupWidths[target] += element.gridWidth;
		[groups[target] addObject:element];
	}

	// get the original container size so we can reuse the original function
	double rowGap = [self complicationEdgeInset] * (rowSpacing / 10.0);
	CGSize smallContainerSize = containerSize;
	smallContainerSize.height -= rowGap * (rowCount - 1);
	smallContainerSize.height /= rowCount;

	NSMutableDictionary<CSComplicationLayoutElement *, NSValue *> *newFrames = [[NSMutableDictionary alloc] initWithCapacity:elements.count];

	for (int i = 0; i < rowCount; i++) {
		NSArray<CSComplicationLayoutElement *> *group = groups[i];
		if (group.count == 0) continue;

		NSDictionary<CSComplicationLayoutElement *, NSValue *> *frames = %orig(group, smallContainerSize);
		double rowOffset = i * (smallContainerSize.height + rowGap);

		// nothing to respace with an untouched gap or a single element
		if (elementSpacing == 10 || group.count < 2) {
			[frames enumerateKeysAndObjectsUsingBlock:^(CSComplicationLayoutElement *element, NSValue *value, BOOL *stop) {
				NSRect frame = [value CGRectValue];
				frame.origin.y += rowOffset;
				newFrames[element] = [NSValue valueWithCGRect:frame];
			}];
			continue;
		}

		NSArray<CSComplicationLayoutElement *> *ordered = [group sortedArrayUsingComparator:^NSComparisonResult(CSComplicationLayoutElement *a, CSComplicationLayoutElement *b) {
			double xa = [frames[a] CGRectValue].origin.x;
			double xb = [frames[b] CGRectValue].origin.x;
			if (xa < xb) return NSOrderedAscending;
			return xa > xb ? NSOrderedDescending : NSOrderedSame;
		}];

		// rebuild the row around our own gap, at the widths the system gave
		double totalWidth = 0;
		for (CSComplicationLayoutElement *element in ordered) {
			totalWidth += [frames[element] CGRectValue].size.width;
		}
		NSRect first = [frames[ordered[0]] CGRectValue];
		double naturalGap = [frames[ordered[1]] CGRectValue].origin.x - (first.origin.x + first.size.width);

		double gap = naturalGap * (elementSpacing / 10.0);
		double maxGap = (smallContainerSize.width - totalWidth) / (ordered.count - 1);
		if (gap > maxGap) gap = maxGap;
		if (gap < 0) gap = 0;

		double x = (smallContainerSize.width - (totalWidth + gap * (ordered.count - 1))) / 2;

		for (CSComplicationLayoutElement *element in ordered) {
			NSRect frame = [frames[element] CGRectValue];
			frame.origin.x = x;
			frame.origin.y += rowOffset;
			newFrames[element] = [NSValue valueWithCGRect:frame];
			x += frame.size.width + gap;
		}
	}

	return newFrames;
}

%end

// Preference updates
static void refreshPrefs(void) {
	NSDictionary *settings = nil;
	CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		settings = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keyList);
	}
	if (!settings) {
		NSString *settingsPath = JBROOT_NS(@"/var/mobile/Library/Preferences/");
		settings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@%@.plist", settingsPath, BUNDLE_ID]];
	}

	enabled = settings[@"enabled"] ? [settings[@"enabled"] boolValue] : YES;
	rows = settings[@"rows"] ? [settings[@"rows"] intValue] : 2;
	if (rows < 1) rows = 1;
	if (rows > 8) rows = 8;
	rowSpacing = settings[@"rowSpacing"] ? [settings[@"rowSpacing"] intValue] : 10;
	if (rowSpacing < 0) rowSpacing = 0;
	if (rowSpacing > 20) rowSpacing = 20;
	elementSpacing = settings[@"elementSpacing"] ? [settings[@"elementSpacing"] intValue] : 10;
	if (elementSpacing < 0) elementSpacing = 0;
	if (elementSpacing > 20) elementSpacing = 20;
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  refreshPrefs();
}

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, (CFStringRef)[NSString stringWithFormat:@"%@.prefschanged", BUNDLE_ID], NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	refreshPrefs();
}
