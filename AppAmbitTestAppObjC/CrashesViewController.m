#import "CrashesViewController.h"
#import "NetworkMonitor.h"
#import "StorableApp.h"
#import "ExceptionModel.h"

@import AppAmbit;

@interface CrashesViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView  *stack;

@property (nonatomic, strong) UITextField *userIdField;
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *messageField;

@property (nonatomic, copy)   NSString *alertMessage;
@end

@implementation CrashesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Crashes";
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

    // didCrashInLastSession
    [self.stack addArrangedSubview:[self makeButton:@"Did the app crash during your last session?"
                                              action:@selector(onDidCrashInLastSession)]];

    // UserId
    self.userIdField = [self makeTextField:@"User Id"];
    self.userIdField.text = [[NSUUID UUID] UUIDString];
    [self.stack addArrangedSubview:self.userIdField];
    [self.stack addArrangedSubview:[self makeButton:@"Change user id"
                                              action:@selector(onChangeUserId)]];

    // Email
    self.emailField = [self makeTextField:@"User email"];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.text = @"test@gmail.com";
    [self.stack addArrangedSubview:self.emailField];
    [self.stack addArrangedSubview:[self makeButton:@"Change user email"
                                              action:@selector(onChangeUserEmail)]];

    // Custom message
    self.messageField = [self makeTextField:@"Test Log Message"];
    self.messageField.text = @"Test Log Message";
    [self.stack addArrangedSubview:self.messageField];
    [self.stack addArrangedSubview:[self makeButton:@"Send Custom LogError"
                                              action:@selector(onSendCustomLogError)]];

    // Default log
    [self.stack addArrangedSubview:[self makeButton:@"Send Default LogError"
                                              action:@selector(onSendDefaultLog)]];

    // Exception log
    [self.stack addArrangedSubview:[self makeButton:@"Send Exception LogError"
                                              action:@selector(onSendExceptionLog)]];

    // ClassFQN log
    [self.stack addArrangedSubview:[self makeButton:@"Send ClassInfo LogError"
                                              action:@selector(onSendClassInfoLog)]];

    // Throw new Crash
    [self.stack addArrangedSubview:[self makeButton:@"Throw new Crash"
                                              action:@selector(onThrowCrash)]];

    // Generate Test Crash
    [self.stack addArrangedSubview:[self makeButton:@"Generate Test Crash"
                                              action:@selector(onGenerateTestCrash)]];
    
    //  Generate 30 daily crashes
    [self.stack addArrangedSubview:[self makeButton:@"Generates the last 30 daily errors"
                                              action:@selector(onGenerate30DaysTestErrorsOC)]];

    //  Generate 30 daily crashes
    [self.stack addArrangedSubview:[self makeButton:@"Generates the last 30 daily crashes"
                                              action:@selector(onGenerate30DaysTestCrashOC)]];
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

- (UITextField *)makeTextField:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] init];
    tf.placeholder = placeholder;
    tf.borderStyle = UITextBorderStyleRoundedRect;
    [tf.heightAnchor constraintEqualToConstant:40].active = YES;
    return tf;
}

#pragma mark - Actions 

- (void)onDidCrashInLastSession {
    [Crashes didCrashInLastSessionWithCompletion:^(BOOL didCrash) {
        self.alertMessage = didCrash ?
            @"Application crashed in the last session" :
            @"Application did not crash in the last session";
        [self presentInfo];
    }];
}

- (void)onChangeUserId {
    NSString *userId = self.userIdField.text ?: @"";
    [Analytics setUserId:userId completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Failed to set user ID: %@", error.localizedDescription);
        } else {
            NSLog(@"User ID set successfully");
        }
    }];
}

- (void)onChangeUserEmail {
    NSString *email = self.emailField.text ?: @"";
    [Analytics setEmail:email completion:nil];
}

- (void)onSendCustomLogError {
    NSString *msg = self.messageField.text ?: @"";
    [Crashes logErrorWithMessage:msg
                      properties:nil
                        classFqn:nil
                       exception:nil
                        fileName:nil
                      lineNumber:0
                       createdAt:nil
                      completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[CrashesView] Error sending Log Error: %@", error.localizedDescription);
        } else {
            NSLog(@"[CrashesView] Log Error sent successfully");
        }
        self.alertMessage = @"LogError Sent";
        [self presentInfo];
    }];
}

- (void)onSendDefaultLog {
    NSDictionary<NSString *, NSString *> *props = @{ @"user_id": @"1" };
    [Crashes logErrorWithMessage:@"Test Log Error"
                      properties:props
                        classFqn:nil
                       exception:nil
                        fileName:nil
                      lineNumber:0
                       createdAt:nil
                      completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[CrashesView] Error sending Log Error: %@", error.localizedDescription);
        } else {
            NSLog(@"[CrashesView] Log Error sent successfully");
        }
        self.alertMessage = @"LogError Sent";
        [self presentInfo];
    }];
}

- (void)onSendExceptionLog {
    @try {
        [NSException raise:NSInternalInconsistencyException format:@"Test error Exception Objective C"];
    }
    @catch (NSException *ex) {
        [Crashes logErrorWithNsException:ex
                              properties:@{ @"user_id": @"1" }
                                 classFqn:NSStringFromClass(self.class)
                                 fileName:[NSString stringWithUTF8String:__FILE__]
                               lineNumber:@(__LINE__).longLongValue
                              completion:^(NSError * _Nullable err) {
            NSLog(@"%@", err ? err.localizedDescription : @"OK");
        }];
    }
}

- (void)onSendClassInfoLog {
    [Crashes logErrorWithMessage:@"Test Log Error"
                      properties:@{ @"user_id": @"1" }
                        classFqn:nil
                       exception:nil
                        fileName:@(__FILE__)
                      lineNumber:__LINE__
                       createdAt:nil
                      completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error sending Log Error: %@", error.localizedDescription);
        } else {
            NSLog(@"Log Error sent successfully");
        }
        self.alertMessage = @"LogError Sent";
        [self presentInfo];
    }];
}

- (void)onGenerate30DaysTestErrorsOC {
    if ([NetworkMonitor isConnected]) {
        self.alertMessage = @"Turn off internet and try again";
        [self presentInfo];
        return;
    }

    const NSInteger totalDays = 30;
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];

    (void)[StorableApp.shared putSessionDataWithTimestamp:[NSDate date]
                                              sessionType:@"end"
                                                   error:NULL];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (NSInteger i = 1; i <= totalDays; i++) {
            NSInteger daysToSubtract = totalDays - i;
            NSDate *start = [cal dateByAddingUnit:NSCalendarUnitDay value:-daysToSubtract toDate:now options:0];
            if (!start) start = now;

            NSDate *logCreatedAt = [start dateByAddingTimeInterval:1.0];
            NSDate *end          = [logCreatedAt dateByAddingTimeInterval:1.0];

            NSError *sesErr = nil;
            BOOL ok = [StorableApp.shared putSessionDataWithTimestamp:start
                                                          sessionType:@"start"
                                                               error:&sesErr];
            if (!ok) {
                NSLog(@"[CrashesView] start session error: %@", sesErr.localizedDescription);
                continue;
            }

            dispatch_semaphore_t sem = dispatch_semaphore_create(1);
            dispatch_semaphore_wait(sem, DISPATCH_TIME_NOW);

            [Crashes logErrorWithMessage:@"Test 30 Last Days Errors"
                              properties:nil
                                classFqn:NSStringFromClass(self.class)
                               exception:nil
                                fileName:[NSString stringWithUTF8String:__FILE__]
                              lineNumber:@(__LINE__)
                               createdAt:logCreatedAt
                              completion:^(NSError * _Nullable logErr) {

                if (logErr) NSLog(@"[CrashesView] log error: %@", logErr.localizedDescription);

                NSError *upErr = nil;
                (void)[StorableApp.shared updateLogsWithCurrentSessionId:&upErr];
                if (upErr) NSLog(@"[CrashesView] updateLogs error: %@", upErr.localizedDescription);

                dispatch_semaphore_signal(sem);
            }];

            (void)dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
            dispatch_semaphore_signal(sem);

            NSError *endErr = nil;
            BOOL endOK = [StorableApp.shared putSessionDataWithTimestamp:end
                                                             sessionType:@"end"
                                                                  error:&endErr];
            if (!endOK && endErr) {
                NSLog(@"[CrashesView] end session error: %@", endErr.localizedDescription);
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.alertMessage = @"Logs generated, turn on internet";
            [self presentInfo];
        });
    });
}

- (void)onGenerate30DaysTestCrashOC {
    if ([NetworkMonitor isConnected]) {
        self.alertMessage = @"Turn off internet and try again";
        [self presentInfo];
        return;
    }

    const NSInteger totalDays = 30;

    NSURL *appSup = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                            inDomains:NSUserDomainMask] firstObject];
    if (!appSup) { self.alertMessage = @"Failed to access Application Support directory"; [self presentInfo]; return; }
    NSURL *crashDir = [appSup URLByAppendingPathComponent:@"CrashLogs" isDirectory:YES];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:crashDir.path isDirectory:&isDir]) {
        NSError *mkErr = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:crashDir
                                withIntermediateDirectories:YES attributes:nil error:&mkErr];
        if (mkErr) { NSLog(@"[CrashesView] create dir error: %@", mkErr.localizedDescription); return; }
    }

    (void)[StorableApp.shared putSessionDataWithTimestamp:[NSDate date]
                                              sessionType:@"end"
                                                   error:NULL];

    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (NSInteger i = 1; i <= totalDays; i++) {
            NSInteger daysToSubtract = totalDays - i;
            NSDate *start = [cal dateByAddingUnit:NSCalendarUnitDay value:-daysToSubtract toDate:now options:0];
            if (!start) start = now;

            NSDate *createdAt = [start dateByAddingTimeInterval:1.0];
            NSDate *end       = [createdAt dateByAddingTimeInterval:1.0];

            NSError *sesErr = nil;
            BOOL ok = [StorableApp.shared putSessionDataWithTimestamp:start sessionType:@"start" error:&sesErr];
            if (!ok) { NSLog(@"[CrashesView] start session error: %@", sesErr.localizedDescription); continue; }

            NSError *sidErr = nil;
            NSString *sessionId = [StorableApp.shared getCurrentOpenSessionId:&sidErr] ?: @"";
            if (sidErr) { NSLog(@"[CrashesView] getCurrentOpenSessionId error: %@", sidErr.localizedDescription); }

            NSError *baseError = [NSError errorWithDomain:@"com.appambit.crashview"
                                                     code:1234
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Error crash 30 daily"}];

            ExceptionModel *model = [ExceptionModel fromError:baseError
                                                    sessionId:sessionId
                                                     deviceId:nil
                                                          now:createdAt];
            
            model.createdAt = createdAt;

            NSDateFormatter *fmt = [NSDateFormatter new];
            fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            fmt.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
            fmt.dateFormat = @"yyyyMMdd'T'HHmmss";
            NSString *stamp = [fmt stringFromDate:createdAt];

            NSInteger ordinal = i;
            model.crashLogFile = [NSString stringWithFormat:@"%@_%ld",
                                  ({
                                      NSISO8601DateFormatter *f = [NSISO8601DateFormatter new];
                                      f.formatOptions = (NSISO8601DateFormatWithInternetDateTime);
                                      [f stringFromDate:createdAt];
                                  }) ,
                                  (long)ordinal];

            NSDictionary *dict = [model toDictionary];
            NSError *jsonErr = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:dict
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&jsonErr];
            if (!data || jsonErr) {
                NSLog(@"[CrashesView] json error: %@", jsonErr.localizedDescription);
            } else {
                NSURL *fileURL = [crashDir URLByAppendingPathComponent:
                                  [NSString stringWithFormat:@"crash_%@_%ld.json", stamp, (long)ordinal]];
                NSError *writeErr = nil;
                [data writeToURL:fileURL options:NSDataWritingAtomic error:&writeErr];
                if (writeErr) NSLog(@"[CrashesView] write error: %@", writeErr.localizedDescription);
                else NSLog(@"[CrashesView] Crash file saved: %@", fileURL.lastPathComponent);
            }

            NSError *endErr = nil;
            BOOL endOK = [StorableApp.shared putSessionDataWithTimestamp:end sessionType:@"end" error:&endErr];
            if (!endOK && endErr) NSLog(@"[CrashesView] end session error: %@", endErr.localizedDescription);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.alertMessage = @"Crashes generated, turn on internet";
            [self presentInfo];
        });
    });
}

- (void)onThrowCrash {
    NSArray *array = @[];
    (void)[array objectAtIndex:10];
}

- (void)onGenerateTestCrash {
    [Crashes generateTestCrash];
}

#pragma mark - Alert helper

- (void)presentInfo {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Info"
                                                                message:self.alertMessage ?: @""
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
