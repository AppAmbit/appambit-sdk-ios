#import "MainTabBarController.h"
#import "CrashesViewController.h"
#import "AnalyticsViewController.h"
#import "RemoteConfigViewController.h"
#import "CmsViewController.h"
#import "DatabaseViewController.h"

#pragma mark - TabBarItemView

@interface TabBarItemView : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (instancetype)initWithTitle:(NSString *)title iconName:(NSString *)iconName;
- (void)setSelectedAppearance:(BOOL)selected;
@end

@implementation TabBarItemView

- (instancetype)initWithTitle:(NSString *)title iconName:(NSString *)iconName {
    self = [super init];
    if (self) {
        self.iconView = [UIImageView new];
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconView.image = [UIImage systemImageNamed:iconName];
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.iconView.userInteractionEnabled = NO;

        self.titleLabel = [UILabel new];
        self.titleLabel.text = title;
        self.titleLabel.font = [UIFont systemFontOfSize:11];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.userInteractionEnabled = NO;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.iconView, self.titleLabel]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.spacing = 4;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.userInteractionEnabled = NO;
        [self addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [self.iconView.widthAnchor constraintEqualToConstant:24],
            [self.iconView.heightAnchor constraintEqualToConstant:24],
            [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.widthAnchor constraintGreaterThanOrEqualToConstant:72],
            [self.heightAnchor constraintEqualToConstant:56]
        ]];

        [self setSelectedAppearance:NO];
    }
    return self;
}

- (void)setSelectedAppearance:(BOOL)selected {
    UIColor *color = selected ? [UIColor systemBlueColor] : [UIColor secondaryLabelColor];
    self.iconView.tintColor = color;
    self.titleLabel.textColor = color;
}

@end

#pragma mark - MainTabBarController

@interface MainTabBarController ()
@property (nonatomic, strong) NSArray<UINavigationController *> *tabControllers;
@property (nonatomic, strong) NSArray<TabBarItemView *> *tabButtons;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.selectedIndex = -1;

    CrashesViewController *crashes = [CrashesViewController new];
    crashes.title = @"Crashes";
    UINavigationController *navCrashes = [[UINavigationController alloc] initWithRootViewController:crashes];

    AnalyticsViewController *analytics = [AnalyticsViewController new];
    analytics.title = @"Analytics";
    UINavigationController *navAnalytics = [[UINavigationController alloc] initWithRootViewController:analytics];

    RemoteConfigViewController *remoteConfig = [RemoteConfigViewController new];
    remoteConfig.title = @"Remote Config";
    UINavigationController *navRemoteConfig = [[UINavigationController alloc] initWithRootViewController:remoteConfig];

    CmsViewController *cms = [CmsViewController new];
    cms.title = @"CMS";
    UINavigationController *navCms = [[UINavigationController alloc] initWithRootViewController:cms];

    DatabaseViewController *database = [DatabaseViewController new];
    database.title = @"Database";
    UINavigationController *navDatabase = [[UINavigationController alloc] initWithRootViewController:database];

    self.tabControllers = @[navCrashes, navAnalytics, navRemoteConfig, navCms, navDatabase];

    NSArray<NSString *> *titles = @[@"Crashes", @"Analytics", @"RemoteConfig", @"CMS", @"Database"];
    NSArray<NSString *> *icons = @[@"exclamationmark.triangle", @"chart.bar", @"arrow.2.circlepath.circle", @"doc.richtext", @"cylinder.split.1x2"];

    [self setupContainerAndTabBar];
    [self setupTabButtonsWithTitles:titles icons:icons];
    [self selectTabAtIndex:0];
}

- (void)setupContainerAndTabBar {
    self.containerView = [UIView new];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.containerView];

    self.tabScrollView = [UIScrollView new];
    self.tabScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    self.tabScrollView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.view addSubview:self.tabScrollView];

    UIView *topBorder = [UIView new];
    topBorder.translatesAutoresizingMaskIntoConstraints = NO;
    topBorder.backgroundColor = [UIColor separatorColor];
    [self.tabScrollView addSubview:topBorder];

    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.tabScrollView.topAnchor],

        [self.tabScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabScrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.tabScrollView.heightAnchor constraintEqualToConstant:64],

        [topBorder.topAnchor constraintEqualToAnchor:self.tabScrollView.topAnchor],
        [topBorder.leadingAnchor constraintEqualToAnchor:self.tabScrollView.leadingAnchor],
        [topBorder.trailingAnchor constraintEqualToAnchor:self.tabScrollView.trailingAnchor],
        [topBorder.heightAnchor constraintEqualToConstant:1.0 / [UIScreen mainScreen].scale]
    ]];
}

- (void)setupTabButtonsWithTitles:(NSArray<NSString *> *)titles icons:(NSArray<NSString *> *)icons {
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 24;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tabScrollView addSubview:stack];

    NSMutableArray<TabBarItemView *> *buttons = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        TabBarItemView *item = [[TabBarItemView alloc] initWithTitle:titles[i] iconName:icons[i]];
        item.tag = i;
        [item addTarget:self action:@selector(tabItemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:item];
        [buttons addObject:item];
    }
    self.tabButtons = buttons;

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.tabScrollView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.tabScrollView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.tabScrollView.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:self.tabScrollView.heightAnchor]
    ]];
}

- (void)tabItemTapped:(TabBarItemView *)sender {
    [self selectTabAtIndex:sender.tag];
}

- (void)selectTabAtIndex:(NSInteger)index {
    if (index == self.selectedIndex) return;

    UIViewController *oldVC = self.childViewControllers.firstObject;
    [oldVC willMoveToParentViewController:nil];
    [oldVC.view removeFromSuperview];
    [oldVC removeFromParentViewController];

    UIViewController *newVC = self.tabControllers[index];
    [self addChildViewController:newVC];
    newVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:newVC.view];
    [NSLayoutConstraint activateConstraints:@[
        [newVC.view.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [newVC.view.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [newVC.view.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [newVC.view.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
    ]];
    [newVC didMoveToParentViewController:self];

    self.selectedIndex = index;
    for (NSInteger i = 0; i < self.tabButtons.count; i++) {
        [self.tabButtons[i] setSelectedAppearance:(i == index)];
    }

    TabBarItemView *selectedItem = self.tabButtons[index];
    [self.tabScrollView scrollRectToVisible:[self.tabScrollView convertRect:selectedItem.bounds fromView:selectedItem]
                                    animated:YES];
}

@end
