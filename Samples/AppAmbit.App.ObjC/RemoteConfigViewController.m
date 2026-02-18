
#import "RemoteConfigViewController.h"
@import AppAmbit;

@interface RemoteConfigViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

// State properties
@property (nonatomic, assign) BOOL bannerVisible;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) NSInteger discount;
@property (nonatomic, assign) double maxUpload;

// UI Elements that need updating
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIView *discountView;
@property (nonatomic, strong) UILabel *discountLabel;
@property (nonatomic, strong) UILabel *maxUploadLabel;

@end

@implementation RemoteConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Remote Config";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    
    [self setupUI];
    [self updateValues];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateValues];
}

- (void)setupUI {
    // Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // Stack View
    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 25;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:20],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-20],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    
    // 1. Banner Section
    self.bannerView = [self createBannerView];
    self.bannerView.hidden = YES;
    [self.stackView addArrangedSubview:self.bannerView];
    
    // 2. Message Section
    self.messageLabel = [[UILabel alloc] init];
    UIView *messageSection = [self createSectionWithTitle:@"Remote Data:" label:self.messageLabel];
    [self.stackView addArrangedSubview:messageSection];
    
    // 3. Discount Section
    self.discountView = [self createDiscountView];
    self.discountView.hidden = YES;
    [self.stackView addArrangedSubview:self.discountView];
    
    // 4. Max Upload Section
    self.maxUploadLabel = [[UILabel alloc] init];
    UIView *uploadSection = [self createSectionWithTitle:@"Max Upload Size:" label:self.maxUploadLabel];
    [self.stackView addArrangedSubview:uploadSection];
}

- (UIView *)createBannerView {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *background = [[UIView alloc] init];
    background.backgroundColor = [UIColor orangeColor];
    background.layer.cornerRadius = 8;
    background.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:background];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = @"BANNER";
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [background addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [background.topAnchor constraintEqualToAnchor:container.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [background.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        
        [label.topAnchor constraintEqualToAnchor:background.topAnchor constant:16],
        [label.bottomAnchor constraintEqualToAnchor:background.bottomAnchor constant:-16],
        [label.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:32],
        [label.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-32]
    ]];
    
    return container;
}

- (UIView *)createSectionWithTitle:(NSString *)title label:(UILabel *)contentLabel {
    UIStackView *sectionStack = [[UIStackView alloc] init];
    sectionStack.axis = UILayoutConstraintAxisVertical;
    sectionStack.spacing = 10;
    sectionStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    titleLabel.textColor = [UIColor grayColor];
    [sectionStack addArrangedSubview:titleLabel];
    
    UIView *contentContainer = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        contentContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        contentContainer.layer.borderColor = [UIColor systemGray4Color].CGColor;
    } else {
        contentContainer.backgroundColor = [UIColor whiteColor];
        contentContainer.layer.borderColor = [UIColor lightGrayColor].CGColor;
    }
    contentContainer.layer.cornerRadius = 8;
    contentContainer.layer.borderWidth = 2;
    contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    contentLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    contentLabel.numberOfLines = 0;
    contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentContainer addSubview:contentLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [contentLabel.topAnchor constraintEqualToAnchor:contentContainer.topAnchor constant:12],
        [contentLabel.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor constant:-12],
        [contentLabel.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor constant:12],
        [contentLabel.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor constant:-12]
    ]];
    
    [sectionStack addArrangedSubview:contentContainer];
    
    return sectionStack;
}

- (UIView *)createDiscountView {
    UIStackView *sectionStack = [[UIStackView alloc] init];
    sectionStack.axis = UILayoutConstraintAxisVertical;
    sectionStack.spacing = 10;
    sectionStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Discount:";
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    titleLabel.textColor = [UIColor grayColor];
    [sectionStack addArrangedSubview:titleLabel];
    
    UIView *contentContainer = [[UIView alloc] init];
    contentContainer.layer.cornerRadius = 8;
    contentContainer.layer.borderWidth = 2;
    if (@available(iOS 13.0, *)) {
         contentContainer.layer.borderColor = [UIColor systemGreenColor].CGColor;
    } else {
         contentContainer.layer.borderColor = [UIColor greenColor].CGColor;
    }
    contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.spacing = 8;
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [contentContainer addSubview:contentStack];
    
    if (@available(iOS 13.0, *)) {
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"tag.fill"]];
        icon.tintColor = [UIColor systemGreenColor];
        [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [contentStack addArrangedSubview:icon];
    }
    
    self.discountLabel = [[UILabel alloc] init];
    self.discountLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    if (@available(iOS 13.0, *)) {
        self.discountLabel.textColor = [UIColor systemGreenColor];
    } else {
        self.discountLabel.textColor = [UIColor greenColor];
    }
    [contentStack addArrangedSubview:self.discountLabel];
    
    UIView *spacer = [[UIView alloc] init];
    [contentStack addArrangedSubview:spacer];
    
    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:contentContainer.topAnchor constant:12],
        [contentStack.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor constant:-12],
        [contentStack.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor constant:12],
        [contentStack.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor constant:-12]
    ]];
    
    [sectionStack addArrangedSubview:contentContainer];
    
    return sectionStack;
}

- (void)updateValues {
    self.bannerVisible = [RemoteConfig getBoolean:@"banner"];
    self.message = [RemoteConfig getString:@"data"];
    self.discount = [RemoteConfig getInt:@"discount"];
    self.maxUpload = [RemoteConfig getDouble:@"max_upload"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bannerView.hidden = !self.bannerVisible;
        self.bannerView.alpha = self.bannerVisible ? 1 : 0;
        
        self.messageLabel.text = self.message.length > 0 ? self.message : @"No message";
        
        self.discountView.hidden = (self.discount <= 0);
        self.discountView.alpha = (self.discount > 0) ? 1 : 0;
        self.discountLabel.text = [NSString stringWithFormat:@"%ld%% available", (long)self.discount];
        
        self.maxUploadLabel.text = [NSString stringWithFormat:@"%.1f MB", self.maxUpload];
    });
}

@end
