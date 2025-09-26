#import "MainTabBarController.h"
#import "CrashesViewController.h"
#import "AnalyticsViewController.h"

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];


    CrashesViewController *crashes = [CrashesViewController new];
    crashes.title = @"Crashes";
    crashes.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Crashes"
                                                        image:[UIImage systemImageNamed:@"exclamationmark.triangle"]
                                                          tag:0];
    UINavigationController *navCrashes = [[UINavigationController alloc] initWithRootViewController:crashes];

    AnalyticsViewController *analytics = [AnalyticsViewController new];
    analytics.title = @"Analytics";
    analytics.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Analytics"
                                                          image:[UIImage systemImageNamed:@"chart.bar"]
                                                            tag:1];
    UINavigationController *navAnalytics = [[UINavigationController alloc] initWithRootViewController:analytics];

    self.viewControllers = @[navCrashes, navAnalytics];
}

@end
