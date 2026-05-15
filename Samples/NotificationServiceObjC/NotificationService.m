#import "NotificationService.h"

@import AppAmbitPushNotifications;

@interface NotificationService ()
@property (nonatomic, copy) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;
@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    [AppAmbitNotificationProcessor processRequest:request
                                   contentHandler:contentHandler
                                    handlePayload:^(AppAmbitNotification * _Nonnull notification, UNMutableNotificationContent * _Nonnull content) {
        NSLog(@"[ObjC Extension] Received notification title=%@ body=%@", notification.title, notification.body);
        content.title = [content.title stringByAppendingString:@" Custom"];
    }];
}

- (void)serviceExtensionTimeWillExpire {
    if (self.bestAttemptContent && self.contentHandler) {
        self.contentHandler(self.bestAttemptContent);
    }
}

@end
