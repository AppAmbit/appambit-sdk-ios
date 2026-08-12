#import "CloudCodeViewController.h"
#import <UserNotifications/UserNotifications.h>

@import AppAmbit;
@import AppAmbitPushNotifications;

@interface CloudCodeViewController ()
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextField *taskIdField;
@property (nonatomic, strong) UITextField *uuidField;
@property (nonatomic, strong) UITextField *publishTitleField;
@property (nonatomic, strong) UITextField *publishBodyField;
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) UILabel *resultTitleLabel;
@property (nonatomic, strong) UIButton *resultToggleButton;
@property (nonatomic, strong) UIStackView *resultContainer;
@property (nonatomic, strong) UILabel *databaseStatusLabel;
@property (nonatomic, strong) UILabel *cmsStatusLabel;
@property (nonatomic, copy) NSString *fullResultText;
@property (nonatomic, assign) BOOL resultExpanded;
@property (nonatomic, assign) BOOL verifyingBackend;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIView *> *functionCards;
@end

@implementation CloudCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Cloud Code";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self buildUI];
    [self verifyBackend];
}

- (void)buildUI {
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 8;
    self.stack.alignment = UIStackViewAlignmentFill;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:self.stack];
    self.functionCards = [NSMutableDictionary dictionary];

    self.databaseStatusLabel = [self addSetupGroup:@"Database"
                                        requirement:@"Create Database first"
                                               tint:UIColor.systemBlueColor
                                          function:@"cloud-demo-setup-database"
                                            action:@selector(createTables)];

    self.cmsStatusLabel = [self addSetupGroup:@"CMS"
                                    requirement:@"Create Content Type first"
                                           tint:UIColor.systemPurpleColor
                                      function:nil
                                        action:NULL];

    self.titleField = [self field:@"Task title" value:@"Buy coffee"];
    self.taskIdField = [self field:@"Task id" value:@""];
    self.taskIdField.keyboardType = UIKeyboardTypeNumberPad;
    self.uuidField = [self field:@"CMS post UUID (optional)" value:@""];
    self.publishTitleField = [self field:@"Sample title" value:@"Cloud Code sample post"];
    self.publishBodyField = [self field:@"Sample body" value:@"Published through an HTTP Cloud Function."];

    [self addSectionHeader:@"Database"];
    [self.stack addArrangedSubview:self.titleField];
    [self.stack addArrangedSubview:self.taskIdField];
    [self addFunctionCard:@"cloud-demo-create-task"
                   detail:@"Insert a task for the signed-in consumer."
             prerequisite:@"Requires cloud_demo_tasks"
                    action:@selector(createTask)];
    [self addFunctionCard:@"cloud-demo-list-tasks"
                   detail:@"Read the current consumer's tasks."
             prerequisite:@"Requires cloud_demo_tasks"
                    action:@selector(listTasks)];
    [self addFunctionCard:@"cloud-demo-complete-task"
                   detail:@"Update one task with consumer ownership."
             prerequisite:@"Requires a task id"
                    action:@selector(completeTask)];
    [self addFunctionCard:@"cloud-demo-delete-task"
                   detail:@"Delete one task owned by the consumer."
             prerequisite:@"Requires a task id and confirmation"
                    action:@selector(deleteTask)];
    [self addFunctionCard:@"cloud-demo-create-order"
                   detail:@"Create an order without duplicate idempotency keys."
             prerequisite:@"Requires cloud_demo_orders"
                    action:@selector(createOrder)];
    [self addFunctionCard:@"cloud-demo-dashboard-summary"
                   detail:@"Combine Database and CMS in one response."
             prerequisite:@"Requires Database and CMS setup"
                    action:@selector(summary)];

    [self addSectionHeader:@"CMS"];
    [self.stack addArrangedSubview:self.uuidField];
    [self.stack addArrangedSubview:self.publishTitleField];
    [self.stack addArrangedSubview:self.publishBodyField];
    [self addFunctionCard:@"cloud-demo-publish-post"
                   detail:@"Create a published CMS entry."
             prerequisite:@"Requires confirmation and cloud_code_demo_posts"
                    action:@selector(createSampleContent)];
    [self addFunctionCard:@"cloud-demo-read-posts"
                   detail:@"List published entries using only CMS data."
             prerequisite:@"Requires cloud_code_demo_posts"
                    action:@selector(readPosts)];

    [self addSectionHeader:@"Push"];
    [self addFunctionCard:@"cloud-demo-send-push"
                   detail:@"Send a notification to all consumers."
             prerequisite:@"Requires permission and APNs/FCM"
                    action:@selector(sendPush)];

    [self addSectionHeader:@"HTTP"];
    [self addFunctionCard:@"cloud-demo-http-inspector"
                   detail:@"Inspect method, query, body and consumer context."
             prerequisite:@"Requires an HTTP trigger"
                    action:@selector(inspectContext)];
    [self addFunctionCard:@"cloud-demo-json-values"
                   detail:@"Return common JSON value types."
             prerequisite:@"Requires an HTTP trigger"
                    action:@selector(jsonValues)];
    [self addFunctionCard:@"cloud-demo-null-contract"
                   detail:@"Compare raw null and an explicit value."
             prerequisite:@"Requires an HTTP trigger"
                    action:@selector(nullContract)];
    [self addFunctionCard:@"cloud-demo-response-shapes"
                   detail:@"Demonstrate statuses, body and headers."
             prerequisite:@"Requires an HTTP trigger"
                    action:@selector(responseShapes)];
    [self addFunctionCard:@"cloud-demo-error-response"
                   detail:@"Return a safe client error response."
             prerequisite:@"Requires an HTTP trigger"
                    action:@selector(controlledError)];
    [self addFunctionCard:@"cloud-demo-timeout-10s"
                   detail:@"Observe the configured function timeout."
             prerequisite:@"Requires a 10 second function timeout"
                    action:@selector(timeoutDemo)];
    [self addFunctionCard:@"cloud-demo-runtime-context"
                   detail:@"Use environment values, secrets and logs safely."
             prerequisite:@"Requires DEMO_REGION and DEMO_SECRET"
                    action:@selector(runtimeContext)];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [self.stack addArrangedSubview:self.spinner];
    self.resultContainer = [[UIStackView alloc] init];
    self.resultContainer.axis = UILayoutConstraintAxisVertical;
    self.resultContainer.spacing = 8;
    UIStackView *resultHeader = [[UIStackView alloc] init];
    resultHeader.axis = UILayoutConstraintAxisHorizontal;
    resultHeader.alignment = UIStackViewAlignmentCenter;
    resultHeader.spacing = 8;
    self.resultTitleLabel = [self label:@"Latest result" style:UIFontTextStyleSubheadline];
    self.resultTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.resultToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resultToggleButton setTitle:@"Collapse" forState:UIControlStateNormal];
    [self.resultToggleButton addTarget:self action:@selector(toggleResult) forControlEvents:UIControlEventTouchUpInside];
    [resultHeader addArrangedSubview:self.resultTitleLabel];
    [resultHeader addArrangedSubview:[UIView new]];
    [resultHeader addArrangedSubview:self.resultToggleButton];
    [self.resultContainer addArrangedSubview:resultHeader];

    self.fullResultText = @"Run a function to see its response here.";
    self.resultLabel = [self label:self.fullResultText style:UIFontTextStyleCaption1];
    self.resultExpanded = YES;
    self.resultLabel.numberOfLines = 0;
    self.resultLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    [self.resultContainer addArrangedSubview:self.resultLabel];
    self.resultContainer.hidden = YES;
    [self.stack addArrangedSubview:self.resultContainer];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [self.stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [self.stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];
}

- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:style];
    return label;
}

- (void)addSectionHeader:(NSString *)title {
    UILabel *header = [self label:title style:UIFontTextStyleHeadline];
    header.textColor = UIColor.labelColor;
    header.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [self.stack addArrangedSubview:header];
}

- (UITextField *)field:(NSString *)placeholder value:(NSString *)value {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.text = value;
    field.borderStyle = UITextBorderStyleRoundedRect;
    return field;
}

- (UILabel *)addSetupGroup:(NSString *)title
               requirement:(NSString *)requirement
                      tint:(UIColor *)tint
                 function:(NSString *)function
                   action:(SEL)action {
    UIView *group = [UIView new];
    group.backgroundColor = UIColor.secondarySystemBackgroundColor;
    group.layer.cornerRadius = 10;
    group.layer.borderWidth = 1;
    group.layer.borderColor = UIColor.separatorColor.CGColor;

    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 8;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [group addSubview:content];

    UILabel *titleLabel = [self label:title style:UIFontTextStyleHeadline];
    [content addArrangedSubview:titleLabel];

    UILabel *requirementLabel = [self label:requirement style:UIFontTextStyleCaption2];
    requirementLabel.font = [UIFont systemFontOfSize:requirementLabel.font.pointSize weight:UIFontWeightSemibold];
    requirementLabel.textColor = tint;
    [content addArrangedSubview:requirementLabel];

    UIStackView *statusRow = [[UIStackView alloc] init];
    statusRow.axis = UILayoutConstraintAxisHorizontal;
    statusRow.alignment = UIStackViewAlignmentCenter;
    statusRow.spacing = 8;
    UILabel *status = [self label:@"Not available" style:UIFontTextStyleCaption1];
    status.font = [UIFont systemFontOfSize:status.font.pointSize weight:UIFontWeightSemibold];
    status.textColor = UIColor.secondaryLabelColor;
    [statusRow addArrangedSubview:status];
    [statusRow addArrangedSubview:[UIView new]];
    if (function.length > 0) {
        UIButton *button = [self actionButtonWithTitle:function action:action];
        [statusRow addArrangedSubview:button];
    }
    [content addArrangedSubview:statusRow];

    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:group.topAnchor constant:12],
        [content.leadingAnchor constraintEqualToAnchor:group.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:group.trailingAnchor constant:-12],
        [content.bottomAnchor constraintEqualToAnchor:group.bottomAnchor constant:-12]
    ]];
    [self.stack addArrangedSubview:group];
    if (function.length > 0) self.functionCards[function] = group;
    return status;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = UIColor.whiteColor;
    button.accessibilityLabel = title;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.title = title;
        configuration.image = [UIImage systemImageNamed:@"play.fill"];
        configuration.imagePadding = 6;
        configuration.baseForegroundColor = UIColor.whiteColor;
        configuration.baseBackgroundColor = UIColor.systemBlueColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(8, 12, 8, 12);
        button.configuration = configuration;
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
        button.backgroundColor = UIColor.systemBlueColor;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.layer.cornerRadius = 8;
        button.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    }
    return button;
}

- (void)addFunctionCard:(NSString *)function
                 detail:(NSString *)detail
           prerequisite:(NSString *)prerequisite
                  action:(SEL)action {
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.9];
    card.layer.cornerRadius = 10;

    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 6;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:content];

    UIStackView *topRow = [[UIStackView alloc] init];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.spacing = 8;

    UIStackView *info = [[UIStackView alloc] init];
    info.axis = UILayoutConstraintAxisVertical;
    info.spacing = 2;
    UILabel *functionLabel = [self label:function style:UIFontTextStyleSubheadline];
    functionLabel.font = [UIFont systemFontOfSize:functionLabel.font.pointSize weight:UIFontWeightSemibold];
    UILabel *detailLabel = [self label:detail style:UIFontTextStyleCaption1];
    detailLabel.textColor = UIColor.secondaryLabelColor;
    detailLabel.numberOfLines = 0;
    UILabel *prerequisiteLabel = [self label:prerequisite style:UIFontTextStyleCaption2];
    prerequisiteLabel.textColor = UIColor.secondaryLabelColor;
    prerequisiteLabel.numberOfLines = 0;
    [info addArrangedSubview:functionLabel];
    [info addArrangedSubview:detailLabel];
    [info addArrangedSubview:prerequisiteLabel];

    UIButton *runButton = [self actionButtonWithTitle:@"Run" action:action];
    runButton.accessibilityLabel = function;
    [topRow addArrangedSubview:info];
    [topRow addArrangedSubview:runButton];
    [content addArrangedSubview:topRow];

    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:10],
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10]
    ]];
    [self.stack addArrangedSubview:card];
    self.functionCards[function] = card;
}

- (NSDictionary *)taskBodyRequired {
    NSInteger taskId = self.taskIdField.text.integerValue;
    return @{ @"task_id": @(taskId) };
}

- (void)runFunction:(NSString *)function method:(CloudCodeHttpMethod)method query:(NSDictionary *)query body:(NSDictionary *)body {
    if (self.spinner.isAnimating) return;
    [self.spinner startAnimating];
    [self prepareResultForFunction:function];
    [self setResultText:[NSString stringWithFormat:@"Calling %@...", function]];
    NSDate *started = [NSDate date];
    __weak typeof(self) weakSelf = self;
    [CloudCode call:function method:method query:query body:body headers:@{ @"X-Sample-Client": @"objc" } completion:^(CloudCodeResponse * _Nullable response, NSError * _Nullable error) {
        NSTimeInterval elapsed = -[started timeIntervalSinceNow];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.spinner stopAnimating];
            if (response) {
                [self setResultText:[NSString stringWithFormat:@"HTTP %ld\nDuration: %.2f s\nrequestId: %@\nBody: %@", (long)response.statusCode, elapsed, response.requestId ?: @"none", [self jsonText:response.data]]];
            } else {
                [self setResultText:[NSString stringWithFormat:@"Duration: %.2f s\nError: %@", elapsed, error.localizedDescription ?: @"Unknown error"]];
            }
        });
    }];
}

- (void)prepareResultForFunction:(NSString *)function {
    self.resultTitleLabel.text = [NSString stringWithFormat:@"Result · %@", [self displayNameForFunction:function]];
    self.resultExpanded = YES;
    self.resultContainer.hidden = NO;

    UIView *anchor = self.functionCards[function];
    [self.stack removeArrangedSubview:self.resultContainer];
    [self.resultContainer removeFromSuperview];

    if (anchor) {
        NSUInteger index = [self.stack.arrangedSubviews indexOfObject:anchor];
        [self.stack insertArrangedSubview:self.resultContainer atIndex:index + 1];
    } else {
        [self.stack addArrangedSubview:self.resultContainer];
    }
}

- (void)verifyBackend {
    if (self.verifyingBackend) return;
    self.verifyingBackend = YES;
    self.databaseStatusLabel.text = @"Checking...";
    self.cmsStatusLabel.text = @"Checking...";
    self.databaseStatusLabel.textColor = UIColor.secondaryLabelColor;
    self.cmsStatusLabel.textColor = UIColor.secondaryLabelColor;

    __weak typeof(self) weakSelf = self;
    [CloudCode call:@"cloud-demo-dashboard-summary"
             method:CloudCodeHttpMethodGet
              query:nil
                body:nil
             headers:@{ @"X-Sample-Client": @"objc" }
          completion:^(CloudCodeResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.verifyingBackend = NO;
            if (!response || response.statusCode != 200 || ![response.data isKindOfClass:NSDictionary.class]) {
                self.databaseStatusLabel.text = @"Not available";
                self.cmsStatusLabel.text = @"Not available";
                self.databaseStatusLabel.textColor = UIColor.secondaryLabelColor;
                self.cmsStatusLabel.textColor = UIColor.secondaryLabelColor;
                return;
            }

            NSDictionary *payload = (NSDictionary *)response.data;
            BOOL databaseAvailable = payload[@"task_count"] != nil;
            BOOL cmsAvailable = payload[@"posts"] != nil;
            self.databaseStatusLabel.text = databaseAvailable ? @"Available" : @"Not available";
            self.cmsStatusLabel.text = cmsAvailable ? @"Available" : @"Not available";
            self.databaseStatusLabel.textColor = databaseAvailable ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
            self.cmsStatusLabel.textColor = cmsAvailable ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
        });
    }];
}

- (void)toggleResult {
    self.resultExpanded = !self.resultExpanded;
    [self updateResultDisplay];
}

- (void)setResultText:(NSString *)text {
    self.fullResultText = text ?: @"";
    [self updateResultDisplay];
}

- (void)updateResultDisplay {
    if (self.resultExpanded) {
        self.resultLabel.text = self.fullResultText;
        self.resultLabel.numberOfLines = 0;
        [self.resultToggleButton setTitle:@"Collapse" forState:UIControlStateNormal];
    } else {
        NSArray<NSString *> *lines = [self.fullResultText componentsSeparatedByString:@"\n"];
        NSArray<NSString *> *previewLines = [lines subarrayWithRange:NSMakeRange(0, MIN(lines.count, 2))];
        self.resultLabel.text = [previewLines componentsJoinedByString:@"\n"];
        self.resultLabel.numberOfLines = 2;
        [self.resultToggleButton setTitle:@"Expand" forState:UIControlStateNormal];
    }
}

- (void)confirmAndRun:(NSString *)title handler:(void (^)(void))handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"This calls a real backend operation." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Run" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) { handler(); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createTask { [self runFunction:@"cloud-demo-create-task" method:CloudCodeHttpMethodPost query:nil body:@{ @"title": self.titleField.text ?: @"" }]; }
- (void)createTables {
    [self confirmAndRun:@"cloud-demo-setup-database" handler:^{
        [self runFunction:@"cloud-demo-setup-database" method:CloudCodeHttpMethodPost query:nil body:nil];
    }];
}
- (void)listTasks { [self runFunction:@"cloud-demo-list-tasks" method:CloudCodeHttpMethodGet query:@{ @"limit": @"20" } body:nil]; }
- (void)completeTask { [self runFunction:@"cloud-demo-complete-task" method:CloudCodeHttpMethodPatch query:nil body:[self taskBodyRequired]]; }
- (void)deleteTask {
    [self confirmAndRun:@"cloud-demo-delete-task" handler:^{ [self runFunction:@"cloud-demo-delete-task" method:CloudCodeHttpMethodDelete query:nil body:[self taskBodyRequired]]; }];
}
- (void)inspectContext { [self runFunction:@"cloud-demo-http-inspector" method:CloudCodeHttpMethodPost query:@{ @"source": @"objc" } body:@{ @"message": @"hello", @"count": @2 }]; }
- (void)jsonValues { [self runFunction:@"cloud-demo-json-values" method:CloudCodeHttpMethodPost query:nil body:nil]; }
- (void)nullContract { [self runFunction:@"cloud-demo-null-contract" method:CloudCodeHttpMethodGet query:nil body:nil]; }
- (void)responseShapes { [self runFunction:@"cloud-demo-response-shapes" method:CloudCodeHttpMethodPost query:nil body:nil]; }
- (void)controlledError { [self runFunction:@"cloud-demo-error-response" method:CloudCodeHttpMethodPost query:nil body:@{ @"invalid": @YES }]; }
- (void)timeoutDemo { [self runFunction:@"cloud-demo-timeout-10s" method:CloudCodeHttpMethodGet query:nil body:nil]; }
- (void)readPosts {
    NSDictionary *query = self.uuidField.text.length > 0 ? @{ @"uuid": self.uuidField.text } : nil;
    [self runFunction:@"cloud-demo-read-posts" method:CloudCodeHttpMethodGet query:query body:nil];
}
- (void)createSampleContent {
    [self confirmAndRun:@"cloud-demo-publish-post" handler:^{
        [self runFunction:@"cloud-demo-publish-post" method:CloudCodeHttpMethodPost query:nil body:@{ @"title": self.publishTitleField.text ?: @"", @"body": self.publishBodyField.text ?: @"" }];
    }];
}
- (void)runtimeContext { [self runFunction:@"cloud-demo-runtime-context" method:CloudCodeHttpMethodGet query:nil body:nil]; }
- (void)sendPush {
    [self confirmAndRun:@"cloud-demo-send-push" handler:^{
        [self prepareResultForFunction:@"cloud-demo-send-push"];
        [self setResultText:@"Checking notification permission..."];
        [self ensurePushReady:^(BOOL ready) {
            if (ready) {
                [self runFunction:@"cloud-demo-send-push" method:CloudCodeHttpMethodPost query:nil body:@{ @"title": @"Cloud Code demo", @"body": @"Push from Objective-C sample" }];
            }
        }];
    }];
}
- (void)createOrder { [self runFunction:@"cloud-demo-create-order" method:CloudCodeHttpMethodPost query:nil body:@{ @"idempotency_key": NSUUID.UUID.UUIDString, @"amount": @100 }]; }
- (void)summary { [self runFunction:@"cloud-demo-dashboard-summary" method:CloudCodeHttpMethodGet query:nil body:nil]; }

- (void)ensurePushReady:(void (^)(BOOL ready))completion {
    // Keep the action safe if the host app did not initialize Push yet.
    [PushNotifications start];
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UNAuthorizationStatus status = settings.authorizationStatus;
            if (status == UNAuthorizationStatusNotDetermined) {
                [PushNotifications requestNotificationPermissionWithListener:^(BOOL granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (granted) {
                            [PushNotifications setNotificationsEnabled:YES];
                        } else {
                            [self presentAlertWithTitle:@"Notification permission required"
                                                message:@"Allow notifications in Settings before sending a push."];
                        }
                        if (completion) completion(granted);
                    });
                }];
                return;
            }

            if (status == UNAuthorizationStatusAuthorized ||
                status == UNAuthorizationStatusProvisional ||
                status == UNAuthorizationStatusEphemeral) {
                [PushNotifications setNotificationsEnabled:YES];
                if (completion) completion(YES);
                return;
            }

            [self presentAlertWithTitle:@"Notification permission required"
                                message:@"Notifications are disabled in Settings. Enable them and try again."];
            if (completion) completion(NO);
        });
    }];
}

- (NSString *)displayNameForFunction:(NSString *)function {
    return function;
}

- (void)presentAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)jsonText:(id)value {
    if (!value || value == [NSNull null]) return @"null";
    if (![NSJSONSerialization isValidJSONObject:value]) return [value description];
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: [value description];
}

@end
