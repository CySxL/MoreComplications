// SPCreditCell.m

#import "SPCreditCell.h"

@implementation SPCreditCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];

	if (self) {
		self.detailTextLabel.text = specifier.properties[@"subtitle"] ?: @"";
		self.detailTextLabel.textColor = [UIColor systemGrayColor];

		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		self.selectionStyle = UITableViewCellSelectionStyleBlue;

		UIGraphicsBeginImageContextWithOptions(CGSizeMake(38, 38), NO, [UIScreen mainScreen].scale);
		specifier.properties[@"iconImage"] = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		self.creditImageView = [[UIImageView alloc] initWithFrame:self.imageView.bounds];
		self.creditImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.creditImageView.userInteractionEnabled = NO;
		self.creditImageView.clipsToBounds = YES;
		self.creditImageView.layer.cornerRadius = 38 / 2;
		self.creditImageView.layer.minificationFilter = kCAFilterTrilinear;
		[self.imageView addSubview:self.creditImageView];

		if (specifier.properties[@"twitter"]) {
			self.twitterUsername = specifier.properties[@"twitter"];
			if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
				specifier.properties[@"url"] = [@"twitter://user?screen_name=" stringByAppendingString:specifier.properties[@"twitter"]];
			} else {
				specifier.properties[@"url"] = [@"https://mobile.twitter.com/" stringByAppendingString:specifier.properties[@"twitter"]];
			}
		}

		[self loadImage];
	}

	return self;
}

- (void)openURL {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.specifier.properties[@"url"]] options:@{} completionHandler:nil];
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];

	[self.specifier setTarget:self];
	[self.specifier setButtonAction:@selector(openURL)];

	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
}

- (void)didMoveToSuperview {
	[super didMoveToSuperview];

	[self.specifier setTarget:self];
	[self.specifier setButtonAction:@selector(openURL)];

	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
}

- (void)setCreditImage:(UIImage *)creditImage {
	_creditImage = creditImage;
	self.creditImageView.image = creditImage;
}

- (void)loadImage {
	NSString *name = self.specifier.properties[@"image"];
	if (![name isKindOfClass:[NSString class]]) return;
	NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:name ofType:@"png"];
	if (path) self.creditImage = [UIImage imageWithContentsOfFile:path];
}

@end
