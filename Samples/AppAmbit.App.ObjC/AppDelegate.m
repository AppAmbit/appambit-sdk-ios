
#import "AppDelegate.h"
@import AppAmbit;
@import AppAmbitPushNotifications;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Uncomment the line for manual session management
    //[Analytics enableManualSession];

    [RemoteConfig enable];
    [AppAmbit start:@"<YOUR-APPKEY>"];
    [PushNotifications start];
    
    // Suscribirse a las notificaciones silenciosas (Data-only / content-available: 1)
    [PushNotifications setBackgroundNotificationListener:^(NSDictionary * _Nonnull userInfo, void (^ _Nonnull completionHandler)(UIBackgroundFetchResult)) {
        NSLog(@"¡Me despertaron en background! Data oculta: %@", userInfo);
        
        // Aquí se puede sincronizar datos o enviar analíticas...
        // Al terminar, siempre debe llamar a completionHandler
        completionHandler(UIBackgroundFetchResultNewData);
    }];

    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
