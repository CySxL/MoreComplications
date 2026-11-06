// SPCreditCell.m

#import "SPCreditCell.h"

static const CGFloat kSPAvatarSide = 38.0;

// A row with `branch` hangs off the row above it: a line from that row's avatar bends into it,
// and the row above, carrying `branchBelow`, drops its separator and draws the top of the line.
@implementation SPCreditCell {
	CAShapeLayer *_branch;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];

	if (self) {
		self.detailTextLabel.text = specifier.properties[@"subtitle"] ?: @"";
		self.detailTextLabel.textColor = [UIColor systemGrayColor];

		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		self.selectionStyle = UITableViewCellSelectionStyleBlue;

		BOOL branch = [specifier.properties[@"branch"] isEqual:@YES];
		if (branch || [specifier.properties[@"branchBelow"] isEqual:@YES]) {
			_branch = [CAShapeLayer layer];
			_branch.fillColor = nil;
			_branch.lineWidth = 1.5;
			_branch.lineCap = kCALineCapRound;
			[self.contentView.layer addSublayer:_branch];
		}

		if (branch) {
			// an empty slot as wide as the avatar, so the text lines up with the name above
			UIGraphicsBeginImageContextWithOptions(CGSizeMake(kSPAvatarSide, 16), NO, [UIScreen mainScreen].scale);
			specifier.properties[@"iconImage"] = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();

			UIImageSymbolConfiguration *small = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
			NSString *symbol = specifier.properties[@"branchSymbol"];
			if (![symbol isKindOfClass:[NSString class]]) symbol = @"chevron.left.forwardslash.chevron.right";
			NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
			attachment.image = [[UIImage systemImageNamed:symbol withConfiguration:small] imageWithTintColor:[UIColor linkColor] renderingMode:UIImageRenderingModeAlwaysOriginal];

			NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];
			if (attachment.image) [title appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
			[title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:specifier.name ?: @""]
				attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:13], NSForegroundColorAttributeName: [UIColor linkColor]}]];
			self.textLabel.attributedText = title;
			// nil rather than empty, so the subtitle style centres the one line
			self.detailTextLabel.text = nil;
			return self;
		}

		UIGraphicsBeginImageContextWithOptions(CGSizeMake(kSPAvatarSide, kSPAvatarSide), NO, [UIScreen mainScreen].scale);
		specifier.properties[@"iconImage"] = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		self.creditImageView = [[UIImageView alloc] initWithFrame:self.imageView.bounds];
		self.creditImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.creditImageView.contentMode = UIViewContentModeScaleAspectFill;
		self.creditImageView.userInteractionEnabled = NO;
		self.creditImageView.clipsToBounds = YES;
		self.creditImageView.layer.cornerRadius = kSPAvatarSide / 2;
		self.creditImageView.layer.minificationFilter = kCAFilterTrilinear;
		[self.imageView addSubview:self.creditImageView];

		NSString *twitter = specifier.properties[@"twitter"];
		if ([twitter isKindOfClass:[NSString class]]) {
			specifier.properties[@"url"] = [@"https://twitter.com/" stringByAppendingString:twitter];
		}

		[self loadImageForSpecifier:specifier];
	}

	return self;
}

- (void)openURL {
	NSString *url = self.specifier.properties[@"url"];
	if (![url isKindOfClass:[NSString class]]) return;
	NSURL *target = [NSURL URLWithString:url];
	if (target) [[UIApplication sharedApplication] openURL:target options:@{} completionHandler:nil];
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

- (void)layoutSubviews {
	[super layoutSubviews];
	if (!_branch) return;

	BOOL branch = [self.specifier.properties[@"branch"] isEqual:@YES];
	BOOL below = [self.specifier.properties[@"branchBelow"] isEqual:@YES];
	if (below) {
		for (UIView *view in self.subviews) {
			if ([NSStringFromClass([view class]) hasSuffix:@"SeparatorView"]) view.hidden = YES;
		}
	}

	_branch.strokeColor = [[UIColor systemGray3Color] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
	CGRect slot = [self.contentView convertRect:self.imageView.bounds fromView:self.imageView];
	CGFloat x = round(CGRectGetMidX(slot));
	UIBezierPath *path = [UIBezierPath bezierPath];
	if (branch) {
		CGFloat y = round(CGRectGetMidY(slot)), r = 6;
		[path moveToPoint:CGPointMake(x, 0)];
		[path addLineToPoint:CGPointMake(x, y - r)];
		[path addQuadCurveToPoint:CGPointMake(x + r, y) controlPoint:CGPointMake(x, y)];
		[path addLineToPoint:CGPointMake(CGRectGetMaxX(slot), y)];
		if (below) {
			[path moveToPoint:CGPointMake(x, y - r)];
			[path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
		}
	} else {
		[path moveToPoint:CGPointMake(x, CGRectGetMaxY(slot) + 3)];
		[path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
	}
	_branch.path = path.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
	[super traitCollectionDidChange:previousTraitCollection];
	[self setNeedsLayout];
}

- (void)setCreditImage:(UIImage *)creditImage {
	_creditImage = creditImage;
	self.creditImageView.image = creditImage;
}

// self.specifier is still nil during init, so the image name comes from the argument
- (void)loadImageForSpecifier:(PSSpecifier *)specifier {
	NSString *name = specifier.properties[@"image"];
	if (![name isKindOfClass:[NSString class]]) return;
	NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:name ofType:@"png"];
	if (path) self.creditImage = [UIImage imageWithContentsOfFile:path];
}

@end
