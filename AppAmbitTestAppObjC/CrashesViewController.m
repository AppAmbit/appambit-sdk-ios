// Views/CrashesViewController.m
#import "CrashesViewController.h"

// Importa el MÓDULO de tu SDK (no bridges, no -Swift.h de tu app)
@import AppAmbit;

@interface CrashesViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView  *stack;

// Campos
@property (nonatomic, strong) UITextField *userIdField;
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *messageField;

// Alertas
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

    // Throw new Crash (forzado)
    [self.stack addArrangedSubview:[self makeButton:@"Throw new Crash"
                                              action:@selector(onThrowCrash)]];

    // Generate Test Crash (del SDK)
    [self.stack addArrangedSubview:[self makeButton:@"Generate Test Crash"
                                              action:@selector(onGenerateTestCrash)]];
    //  Generate 30 daoily crashes
    [self.stack addArrangedSubview:[self makeButton:@"Generate the last 30 daily errors"
                                              action:@selector(onGenerateTestCrash)]];
    
    //  Generate 30 daily crashes
    [self.stack addArrangedSubview:[self makeButton:@"Generates the last 30 daily crashes"
                                              action:@selector(onGenerateTestCrash)]];

    // Nota: Si luego quieres portar "Generate last 30 daily errors/crashes",
    // lo hacemos aparte porque usa utilidades (StorableApp/ConcurrencyApp/etc)
    // que ya tienes en Swift y requieren más “plomería” en Obj-C.
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

#pragma mark - Actions (llamadas al SDK AppAmbit)

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
