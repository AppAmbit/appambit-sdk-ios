#import "MainTabBarController.h"
#import "CrashesViewController.h"
#import "AnalyticsViewController.h"
#import "RemoteConfigViewController.h"
#import "CmsViewController.h"

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
    
    CmsViewController *cms = [CmsViewController new];
    cms.title = @"CMS";
    cms.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"CMS"
                                                   image:[UIImage systemImageNamed:@"doc.richtext"]
                                                     tag:3];
    UINavigationController *navCms = [[UINavigationController alloc] initWithRootViewController:cms];

    self.viewControllers = @[navCrashes, navAnalytics, navRemoteConfig, navCms];
}

@end
