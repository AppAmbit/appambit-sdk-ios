#import "CrashesViewController.h"
#import "NetworkMonitor.h"
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

    [self.stack addArrangedSubview:[self makeButton:@"Did the app crash during your last session?" action:@selector(onDidCrashInLastSession)]];

    self.userIdField = [self makeTextField:@"User Id"];
    self.userIdField.text = [[NSUUID UUID] UUIDString];
    [self.stack addArrangedSubview:self.userIdField];
    [self.stack addArrangedSubview:[self makeButton:@"Change user id" action:@selector(onChangeUserId)]];

    self.emailField = [self makeTextField:@"User email"];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.text = @"test@gmail.com";
    [self.stack addArrangedSubview:self.emailField];
    [self.stack addArrangedSubview:[self makeButton:@"Change user email" action:@selector(onChangeUserEmail)]];

    self.messageField = [self makeTextField:@"Test Log Message"];
    self.messageField.text = @"Test Log Message";
    [self.stack addArrangedSubview:self.messageField];
    [self.stack addArrangedSubview:[self makeButton:@"Send Custom LogError" action:@selector(onSendCustomLogError)]];

    [self.stack addArrangedSubview:[self makeButton:@"Send Default LogError" action:@selector(onSendDefaultLog)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send Exception LogError" action:@selector(onSendExceptionLog)]];
    [self.stack addArrangedSubview:[self makeButton:@"Send ClassInfo LogError" action:@selector(onSendClassInfoLog)]];
    [self.stack addArrangedSubview:[self makeButton:@"Throw new Crash" action:@selector(onThrowCrash)]];
    [self.stack addArrangedSubview:[self makeButton:@"Generate Test Crash" action:@selector(onGenerateTestCrash)]];

    UIButton *errors30Btn = [self makeDisabledButton:@"Generates the last 30 daily errors"];
    [errors30Btn addTarget:self action:@selector(onGenerate30DaysTestErrorsOC) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:errors30Btn];

    UIButton *crashes30Btn = [self makeDisabledButton:@"Generates the last 30 daily crashes"];
    [crashes30Btn addTarget:self action:@selector(onGenerate30DaysTestCrashOC) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:crashes30Btn];
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

- (UIButton *)makeDisabledButton:(NSString *)title {
    UIColor *grayBlue = [UIColor colorWithRed:96.0/255.0 green:120.0/255.0 blue:141.0/255.0 alpha:1.0];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.numberOfLines = 0;
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    b.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    b.layer.cornerRadius = 8.0;
    b.backgroundColor = grayBlue;
    [b setTitleColor:[UIColor colorWithWhite:0.95 alpha:1.0] forState:UIControlStateNormal];
    [b setTitleColor:[UIColor colorWithWhite:0.95 alpha:1.0] forState:UIControlStateDisabled];
    [b.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    b.enabled = NO;
    b.adjustsImageWhenDisabled = NO;
    b.alpha = 1.0;
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
        if (error) NSLog(@"Failed to set user ID: %@", error.localizedDescription);
        else NSLog(@"User ID set successfully");
    }];
}

- (void)onChangeUserEmail {
    NSString *email = self.emailField.text ?: @"";
    [Analytics setEmail:email completion:nil];
}

#pragma mark - NUEVAS llamadas limpias con completion (sin error)

- (void)onSendCustomLogError {
    NSString *msg = self.messageField.text ?: @"";
    [Crashes logErrorWithMessage:msg completion:^{
        NSLog(@"[CrashesView] Log Error sent");
        self.alertMessage = @"LogError Sent";
        [self presentInfo];
    }];
}

- (void)onSendDefaultLog {
    NSDictionary<NSString *, NSString *> *props = @{ @"user_id": @"1" };
    [Crashes logErrorWithMessage:@"Test Log Error" properties:props completion:^{
        NSLog(@"[CrashesView] Log Error sent");
        self.alertMessage = @"LogError Sent";
        [self presentInfo];
    }];
}

- (void)onSendExceptionLog {
    @try {
        [NSException raise:NSInternalInconsistencyException format:@"Test error Exception Objective C"];
    }
    @catch (NSException *ex) {
        [Crashes logErrorWithNSException:ex
                              properties:@{ @"user_id": @"1" }
                                 classFqn:NSStringFromClass(self.class)
                              completion:^{
            NSLog(@"[CrashesView] Exception Log sent");
            self.alertMessage = @"LogError Sent";
            [self presentInfo];
        }];
    }
}

- (void)onSendClassInfoLog {
    [Crashes logErrorWithMessage:@"Test Log Error"
                      properties:@{ @"user_id": @"1" }
                         classFqn:NSStringFromClass(self.class)
                      completion:^{
        NSLog(@"[CrashesView] Log Error sent");
        self.alertMessage = @"LogError Sent";
        [self presentInfo];
    }];
}

#pragma mark - Otros botones

- (void)onGenerate30DaysTestErrorsOC {
}

- (void)onGenerate30DaysTestCrashOC {
}

- (void)onThrowCrash {
    NSArray *array = @[];
    (void)[array objectAtIndex:10];
}

- (void)onGenerateTestCrash {
    [Crashes generateTestCrash];
}

- (void)presentInfo {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Info" message:self.alertMessage ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
