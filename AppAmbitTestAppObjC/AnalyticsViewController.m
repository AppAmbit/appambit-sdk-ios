#import "AnalyticsViewController.h"

@implementation AnalyticsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *label = [UILabel new];
    label.text = @"Analytics View (placeholder)";
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:16],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-16],
    ]];
}

@end
