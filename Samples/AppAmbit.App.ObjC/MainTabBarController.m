#import "MainTabBarController.h"
#import "CrashesViewController.h"
#import "AnalyticsViewController.h"
#import "RemoteConfigViewController.h"

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

    RemoteConfigViewController *remoteConfig = [RemoteConfigViewController new];
    remoteConfig.title = @"Remote Config";
    remoteConfig.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"RemoteConfig"
                                                            image:[UIImage systemImageNamed:@"arrow.2.circlepath.circle"]
                                                              tag:2];
    UINavigationController *navRemoteConfig = [[UINavigationController alloc] initWithRootViewController:remoteConfig];

    self.viewControllers = @[navCrashes, navAnalytics, navRemoteConfig];
}

@end
