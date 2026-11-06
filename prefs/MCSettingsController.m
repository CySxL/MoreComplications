#import "MCSettingsController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
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

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PACKAGE_SCHEME "roothide"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#define PACKAGE_SCHEME "rootless"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTFUL)
#define PACKAGE_SCHEME "rootful"
#else
#error theos defined no package scheme
#endif

static const CGFloat kMCIconSide = 80.0;
static const CGFloat kMCHeaderGap = 16.0;
// 28 pt measures 256 pt wide, past the 254 pt beside the icon on a 14 Pro Max
static const CGFloat kMCNameSize = 27.0;
static const CGFloat kMCVersionSize = 15.0;
static const CGFloat kMCSchemeSize = 13.0;
static const CGFloat kMCNameToVersion = 24.0;
static const CGFloat kMCVersionToScheme = 19.0;

static UIFont *MCHeaderNameFont(CGFloat size) {
	UIFontDescriptor *bold = [[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleLargeTitle] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
	return [UIFont fontWithDescriptor:bold size:size];
}

// the name's baseline against the icon's middle, with the block centred on it
static CGFloat MCNameBaselineOffset(CGFloat scale) {
	UIFont *name = MCHeaderNameFont(kMCNameSize * scale);
	UIFont *scheme = [UIFont systemFontOfSize:kMCSchemeSize * scale];
	CGFloat height = name.ascender + (kMCNameToVersion + kMCVersionToScheme) * scale - scheme.descender;
	return name.ascender - height / 2.0;
}

@interface MCHeaderCell : PSTableCell
@end

@implementation MCHeaderCell {
	UILabel *_name;
	UILabel *_version;
	UILabel *_scheme;
	UIStackView *_text;
	NSLayoutConstraint *_nameBaseline;
	CGFloat _scale;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
	if (!self) return nil;

	UIImage *image = [UIImage imageNamed:@"header" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
	UIImageView *icon = [[UIImageView alloc] initWithImage:image];
	icon.translatesAutoresizingMaskIntoConstraints = NO;
	icon.clipsToBounds = YES;
	icon.layer.cornerCurve = kCACornerCurveContinuous;
	icon.layer.cornerRadius = kMCIconSide * 0.225;
	[self.contentView addSubview:icon];

	_name = [[UILabel alloc] init];
	_name.text = @"MoreComplications";
	// the icon's green, 2.03:1 on light and 9.25:1 on dark
	_name.textColor = [UIColor colorWithRed:0x62 / 255.0 green:0xbf / 255.0 blue:0x7a / 255.0 alpha:1.0];

	_version = [[UILabel alloc] init];
	_version.text = @"Version " PACKAGE_VERSION;
	_version.textColor = [UIColor systemGrayColor];

	_scheme = [[UILabel alloc] init];
	_scheme.text = @PACKAGE_SCHEME.capitalizedString;
	_scheme.textColor = [UIColor systemGrayColor];

	// baseline to baseline, so the large name's own leading does not push the two lines under it away
	_text = [[UIStackView alloc] initWithArrangedSubviews:@[_name, _version, _scheme]];
	_text.axis = UILayoutConstraintAxisVertical;
	_text.alignment = UIStackViewAlignmentLeading;
	_text.baselineRelativeArrangement = YES;
	_text.translatesAutoresizingMaskIntoConstraints = NO;
	[self.contentView addSubview:_text];
	_nameBaseline = [_name.firstBaselineAnchor constraintEqualToAnchor:icon.centerYAnchor];
	[self applyTextScale:1.0];

	// icon and text centred as one block, never past the leading margin
	UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
	UILayoutGuide *block = [[UILayoutGuide alloc] init];
	[self.contentView addLayoutGuide:block];
	NSLayoutConstraint *centred = [block.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor];
	centred.priority = UILayoutPriorityDefaultHigh;
	[NSLayoutConstraint activateConstraints:@[
		[icon.widthAnchor constraintEqualToConstant:kMCIconSide],
		[icon.heightAnchor constraintEqualToConstant:kMCIconSide],
		[block.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor],
		[block.trailingAnchor constraintEqualToAnchor:_text.trailingAnchor],
		[icon.leadingAnchor constraintGreaterThanOrEqualToAnchor:margins.leadingAnchor],
		centred,
		[icon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
		[_text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:kMCHeaderGap],
		_nameBaseline
	]];
	return self;
}

// fonts and spacing scale together; the icon never scales
- (void)applyTextScale:(CGFloat)scale {
	if (scale == _scale) return;
	_scale = scale;
	_name.font = MCHeaderNameFont(kMCNameSize * scale);
	_version.font = [UIFont systemFontOfSize:kMCVersionSize * scale];
	_scheme.font = [UIFont systemFontOfSize:kMCSchemeSize * scale];
	[_text setCustomSpacing:kMCNameToVersion * scale afterView:_name];
	[_text setCustomSpacing:kMCVersionToScheme * scale afterView:_version];
	_nameBaseline.constant = MCNameBaselineOffset(scale);
}

// full size wherever the name fits beside the icon, otherwise the whole block shrinks by the overflow
- (void)layoutSubviews {
	CGFloat available = CGRectGetWidth(self.contentView.layoutMarginsGuide.layoutFrame) - kMCIconSide - kMCHeaderGap;
	CGFloat natural = [_name.text sizeWithAttributes:@{NSFontAttributeName: MCHeaderNameFont(kMCNameSize)}].width;
	[self applyTextScale:(available > 0 && natural > available) ? available / natural : 1.0];
	[super layoutSubviews];
}

- (void)setSeparatorStyle:(UITableViewCellSeparatorStyle)style {
	[super setSeparatorStyle:UITableViewCellSeparatorStyleNone];
}

- (void)setBackgroundColor:(UIColor *)color {
	[super setBackgroundColor:[UIColor clearColor]];
}

- (UITableViewCellSelectionStyle)selectionStyle {
	return UITableViewCellSelectionStyleNone;
}

@end

@implementation MCSettingsController

- (NSMutableArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
		PSSpecifier *header = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:NULL get:NULL detail:nil cell:PSStaticTextCell edit:nil];
		[header setProperty:[MCHeaderCell class] forKey:@"cellClass"];
		[header setProperty:@142 forKey:@"height"];
		[specifiers insertObject:header atIndex:0];
		// Root.plist opens with a switch, so the header needs a section of its own
		[specifiers insertObject:[PSSpecifier emptyGroupSpecifier] atIndex:1];
		_specifiers = specifiers;
	}
	return _specifiers;
}

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
