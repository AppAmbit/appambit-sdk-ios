#import "AnalyticsViewController.h"
#import "NetworkMonitor.h"
#import "StorableApp.h"

@import AppAmbit;

@interface AnalyticsViewController ()

@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView  *stack;

@property (nonatomic, copy)   NSString *alertMessage;

@end

@implementation AnalyticsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Analytics";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self buildUI];
}

#pragma mark - UI

- (void)buildUI {
    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;

    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 16.0;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.scroll];
    [self.scroll addSubview:self.stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:20],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-20],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    [self.stack addArrangedSubview:[self makeButton:@"Invalidate Token"
                                              action:@selector(onInvalidateToken)]];
    [self.stack addArrangedSubview:[self makeButton:@"Token refresh test"
                                              action:@selector(onTokenRefreshTest)]];
    [self.stack addArrangedSubview:[self makeButton:@"Start Session"
                                              action:@selector(onStartSession)]];
    [self.stack addArrangedSubview:[self makeButton:@"End Session"
                                              action:@selector(onEndSession)]];
    [self.stack addArrangedSubview:[self makeButton:@"Generate the last 30 daily sessions"
                                              action:@selector(onGenerateLast30DailySessions)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send 'Button Clicked' Event w/ property"
                                              action:@selector(onSendButtonClickedEvent)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send Default Event w/ property"
                                              action:@selector(onSendDefaultEvent)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send Max-300-Length Event"
                                              action:@selector(onSendMax300LengthEvent)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send Max-20-Properties Event"
                                              action:@selector(onSendMax20PropertiesEvent)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send 30 Daily Events"
                                              action:@selector(onSend30DailyEvents)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send Batch of 220 Events"
                                              action:@selector(onGenerateBatchEvents)]];
}

- (UIButton *)makeButton:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.numberOfLines = 0;
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    b.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    b.layer.cornerRadius = 8.0;
    b.backgroundColor = [UIColor systemBlueColor];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [b.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

#pragma mark - Alert helper

- (void)presentInfoWithMessage:(NSString *)message {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Info"
                                                                message:message ?: @""
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Helpers

- (NSDate *)dateBySettingHour:(NSInteger)hour minute:(NSInteger)minute onDay:(NSDate *)day {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *dc = [cal componentsInTimeZone:[NSTimeZone localTimeZone] fromDate:day];
    dc.hour = hour;
    dc.minute = minute;
    dc.second = 0;
    return [cal dateFromComponents:dc] ?: day;
}

#pragma mark - Actions

- (void)onInvalidateToken {
    [Analytics clearToken];
}

- (void)onStartSession {
    [Analytics startSessionWithCompletion:^(NSError * _Nullable error) {
        if (error) NSLog(@"Error Start Session: %@", error.localizedDescription);
        else       NSLog(@"Successful Start Session");
    }];
}

- (void)onEndSession {
    [Analytics endSessionWithCompletion:^(NSError * _Nullable error) {
        if (error) NSLog(@"Error End Session: %@", error.localizedDescription);
        else       NSLog(@"Successful End Session");
    }];
}

- (void)onGenerateLast30DailySessions {
    if ([NetworkMonitor isConnected]) {
        [self presentInfoWithMessage:@"Turn off internet and try again"];
        return;
    }

    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDate *startDate = [cal dateByAddingUnit:NSCalendarUnitDay value:-30 toDate:now options:0];
    NSInteger sessionCount = 30;
    NSInteger fixedDurationMinutes = 90;

    for (NSInteger i = 0; i < sessionCount; i++) {
        NSDate *sessionDay = [cal dateByAddingUnit:NSCalendarUnitDay value:i toDate:startDate options:0];
        NSInteger randomHour = arc4random_uniform(23);
        NSInteger randomMinute = arc4random_uniform(60);
        NSDate *startSessionDate = [self dateBySettingHour:randomHour minute:randomMinute onDay:sessionDay];

        NSError *err = nil;
        BOOL ok = [[StorableApp shared] putSessionDataWithTimestamp:startSessionDate
                                                        sessionType:@"start"
                                                              error:&err];
        if (!ok) NSLog(@"Error inserting start session: %@", err.localizedDescription);

        NSDate *endSessionDate = [startSessionDate dateByAddingTimeInterval:fixedDurationMinutes * 60.0];

        err = nil;
        ok = [[StorableApp shared] putSessionDataWithTimestamp:endSessionDate
                                                   sessionType:@"end"
                                                         error:&err];
        if (!ok) NSLog(@"Error inserting end session: %@", err.localizedDescription);
    }

    NSLog(@"%ld test sessions were inserted.", (long)sessionCount);
    [self presentInfoWithMessage:@"Sessions generated, turn on internet"];
}

- (void)onSendButtonClickedEvent {
    NSDictionary *props = @{@"Count": @"41"};
    [Analytics trackEventWithEventTitle:@"ButtonClicked"
                                   data:props
                              createdAt:nil
                             completion:^(NSError * _Nullable error) {
        if (error) NSLog(@"Error Track Event: %@", error.localizedDescription);
        else       NSLog(@"Event sent successfully");
    }];
}

- (void)onSendDefaultEvent {
    [Analytics generateTestEventWithCompletion:^(NSError * _Nullable error) {
        if (error) NSLog(@"Error Track Event: %@", error.localizedDescription);
        else       NSLog(@"Event sent successfully");
    }];
}

- (void)onSendMax300LengthEvent {
    NSString *s300 =
    @"123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";
    NSString *s300b =
    @"1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678902";

    NSDictionary *props = @{ s300 : s300, s300b : s300b };

    [Analytics trackEventWithEventTitle:s300
                                   data:props
                              createdAt:nil
                             completion:^(NSError * _Nullable error) {
        if (error) NSLog(@"Error Track Event: %@", error.localizedDescription);
        else       NSLog(@"Event sent successfully");
    }];
}

- (void)onSendMax20PropertiesEvent {
    NSMutableDictionary *props = [NSMutableDictionary dictionaryWithCapacity:25];
    for (NSInteger i = 1; i <= 25; i++) {
        NSString *k = [NSString stringWithFormat:@"%02ld", (long)i];
        props[k] = k;
    }
    [Analytics trackEventWithEventTitle:@"TestMaxProperties"
                                   data:props
                              createdAt:nil
                             completion:^(NSError * _Nullable error) {
        if (error) NSLog(@"Error Track Event: %@", error.localizedDescription);
        else       NSLog(@"Event sent successfully");
    }];
}
- (void)onSend30DailyEvents {
    if ([NetworkMonitor isConnected]) {
        [self presentInfoWithMessage:@"Turn off internet and try again"];
        return;
    }

    const NSInteger totalDays = 30;
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];

    (void)[StorableApp.shared putSessionDataWithTimestamp:[NSDate date]
                                              sessionType:@"end"
                                                   error:NULL];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSTimeInterval secOffset = 0.0;

        for (NSInteger i = 1; i <= totalDays; i++) {
            NSInteger daysToSubtract = totalDays - i;
            NSDate *baseDay = [cal dateByAddingUnit:NSCalendarUnitDay value:-daysToSubtract toDate:now options:0];
            if (!baseDay) baseDay = now;

            NSDate *start      = [baseDay dateByAddingTimeInterval:secOffset];
            NSDate *createdAt  = [start   dateByAddingTimeInterval:1.0];
            NSDate *end        = [createdAt dateByAddingTimeInterval:1.0];

            NSError *sesErr = nil;
            BOOL ok = [StorableApp.shared putSessionDataWithTimestamp:start
                                                          sessionType:@"start"
                                                               error:&sesErr];
            if (!ok) {
                NSLog(@"[AnalyticsView] start session error: %@", sesErr.localizedDescription);
                secOffset += 1.0;
                continue;
            }

            dispatch_semaphore_t sem = dispatch_semaphore_create(1);
            dispatch_semaphore_wait(sem, DISPATCH_TIME_NOW);

            NSDictionary *data = @{ @"30 Daily events" : @"Event" };
            [Analytics trackEventWithEventTitle:@"Test Batch TrackEvent"
                                           data:data
                                      createdAt:createdAt
                                     completion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[AnalyticsView] trackEvent offline (esperado): %@", error.localizedDescription);
                }
                NSError *linkErr = nil;
                (void)[StorableApp.shared updateEventsWithCurrentSessionId:&linkErr];
                if (linkErr) {
                    NSLog(@"[AnalyticsView] updateEventsWithCurrentSessionId error: %@", linkErr.localizedDescription);
                }
                dispatch_semaphore_signal(sem);
            }];

            (void)dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
            dispatch_semaphore_signal(sem);

            NSError *endErr = nil;
            ok = [StorableApp.shared putSessionDataWithTimestamp:end
                                                     sessionType:@"end"
                                                          error:&endErr];
            if (!ok && endErr) {
                NSLog(@"[AnalyticsView] end session error: %@", endErr.localizedDescription);
            }
            
            secOffset += 1.0;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentInfoWithMessage:@"Event generated, turn on internet"];
        });
    });
}

- (void)onTokenRefreshTest {
    dispatch_group_t overallGroup = dispatch_group_create();
    dispatch_group_enter(overallGroup);

    dispatch_group_t logsGroup = dispatch_group_create();
    dispatch_queue_t concurrentQ   = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_queue_t serialEventQ  = dispatch_queue_create("com.appambit.analytics.eventQueue", DISPATCH_QUEUE_SERIAL);

    NSLog(@"[AnalyticsVC] Starting 5 concurrent error logs");

    for (int i = 1; i <= 5; i++) {
        dispatch_group_enter(logsGroup);
        dispatch_async(concurrentQ, ^{
            NSString *message = @"Sending logs 5 after invalid token";
            NSDictionary *properties = @{ @"user_id": @"1" };
            NSString *classFqn = NSStringFromClass(self.class);
            NSDate *createdAt = [NSDate date];

            [Crashes logErrorWithMessage:message
                              properties:properties
                                classFqn:classFqn
                               exception:nil
                                fileName:@(__FILE__)
                              lineNumber:__LINE__
                               createdAt:createdAt
                              completion:^(NSError * _Nullable error) {
                if (error) NSLog(@"Failed to log error %d: %@", i, error.localizedDescription);
                else       NSLog(@"Log %d recorded successfully", i);
                dispatch_group_leave(logsGroup);
            }];
        });
    }

    dispatch_group_notify(logsGroup, concurrentQ, ^{
        NSLog(@"[AnalyticsVC] All logs completed. Starting 5 serial events");

        dispatch_group_t eventsGroup = dispatch_group_create();

        for (int i = 1; i <= 5; i++) {
            dispatch_group_enter(eventsGroup);
            dispatch_async(serialEventQ, ^{
                [Analytics trackEventWithEventTitle:@"Sending event 5 after invalid token"
                                               data:@{ @"Test Token": @"5 events sent" }
                                          createdAt:nil
                                         completion:^(NSError * _Nullable error) {
                    if (error) NSLog(@"Event %d failed: %@", i, error.localizedDescription);
                    else       NSLog(@"Event %d tracked successfully", i);
                    dispatch_group_leave(eventsGroup);
                }];
            });
        }

        dispatch_group_notify(eventsGroup, dispatch_get_main_queue(), ^{
            NSLog(@"[AnalyticsVC] All operations completed successfully");
            [self presentInfoWithMessage:@"5 events and 5 errors sent"];
            dispatch_group_leave(overallGroup);
        });
    });

    dispatch_group_notify(overallGroup, dispatch_get_main_queue(), ^{
        NSLog(@"[AnalyticsVC] Full test sequence completed");
    });
}

- (void)onGenerateBatchEvents {
    if ([NetworkMonitor isConnected]) {
        [self presentInfoWithMessage:@"Turn off internet and try again"];
        return;
    }

    const NSInteger limit = 220;
    dispatch_group_t group = dispatch_group_create();

    for (NSInteger index = 1; index <= limit; index++) {
        dispatch_group_enter(group);

        [Analytics trackEventWithEventTitle:@"Test Batch TrackEvent"
                                       data:@{@"test1": @"test1"}
                                  createdAt:nil
                                 completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[AnalyticsView] Error Track Event: %@", error.localizedDescription);
            } else {
                NSLog(@"[AnalyticsView] Event sent successfully");
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self presentInfoWithMessage:@"Events generated, turn on internet"];
    });
}

@end
