#import "MainTabBarController.h"
#import "CrashesViewController.h"
#import "AnalyticsViewController.h"
#import "LoadViewController.h"

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

    LoadViewController *load = [LoadViewController new];
    load.title = @"Load";
    load.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Load"
                                                    image:[UIImage systemImageNamed:@"bolt.horizontal.circle"]
                                                      tag:2];
    UINavigationController *navLoad = [[UINavigationController alloc] initWithRootViewController:load];

    self.viewControllers = @[navCrashes, navAnalytics, navLoad];
}

@end
