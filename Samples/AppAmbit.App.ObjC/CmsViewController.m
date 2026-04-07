#import "CmsViewController.h"
#import "models/CmsExampleModel.h"
@import AppAmbit;

@interface PostTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *featuredImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UILabel *viewsLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UILabel *categoryBadgeLabel;
@property (nonatomic, strong) UILabel *eventDateLabel;
@property (nonatomic, strong) UILabel *metaDataLabel;
- (void)configureWithPost:(CmsExampleModel *)post;
@end

@implementation PostTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    _featuredImageView = [UIImageView new];
    _featuredImageView.contentMode = UIViewContentModeScaleAspectFill;
    _featuredImageView.clipsToBounds = YES;
    _featuredImageView.layer.cornerRadius = 12;
    _featuredImageView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    _titleLabel.numberOfLines = 0;
    
    _bodyLabel = [UILabel new];
    _bodyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _bodyLabel.numberOfLines = 3;
    _bodyLabel.textColor = UIColor.secondaryLabelColor;
    
    _viewsLabel = [UILabel new];
    _viewsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    
    _authorLabel = [UILabel new];
    _authorLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _authorLabel.textAlignment = NSTextAlignmentRight;
    
    _statusBadgeLabel = [UILabel new];
    _statusBadgeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    _statusBadgeLabel.layer.masksToBounds = YES;
    _statusBadgeLabel.layer.cornerRadius = 4;
    _statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    
    _categoryBadgeLabel = [UILabel new];
    _categoryBadgeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    _categoryBadgeLabel.layer.masksToBounds = YES;
    _categoryBadgeLabel.layer.cornerRadius = 8;
    _categoryBadgeLabel.textAlignment = NSTextAlignmentCenter;
    _categoryBadgeLabel.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.1];
    _categoryBadgeLabel.textColor = [UIColor systemBlueColor];
    
    _eventDateLabel = [UILabel new];
    _eventDateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    _eventDateLabel.textColor = UIColor.systemGrayColor;
    
    _metaDataLabel = [UILabel new];
    _metaDataLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    _metaDataLabel.textColor = UIColor.systemBlueColor;
    _metaDataLabel.numberOfLines = 2;
    
    UIStackView *viewsAuthorStack = [[UIStackView alloc] initWithArrangedSubviews:@[_viewsLabel, _authorLabel]];
    viewsAuthorStack.axis = UILayoutConstraintAxisHorizontal;
    viewsAuthorStack.distribution = UIStackViewDistributionEqualSpacing;
    
    UIStackView *badgesStack = [[UIStackView alloc] initWithArrangedSubviews:@[_statusBadgeLabel, [[UIView alloc] init], _categoryBadgeLabel]];
    badgesStack.axis = UILayoutConstraintAxisHorizontal;
    badgesStack.distribution = UIStackViewDistributionEqualSpacing;
    
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _featuredImageView, _titleLabel, _bodyLabel, viewsAuthorStack, badgesStack, _eventDateLabel, _metaDataLabel
    ]];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 8;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [_featuredImageView.heightAnchor constraintEqualToConstant:200],
        [mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16]
    ]];
}

// Returns an attributed string with an SF Symbol icon followed by text
- (NSAttributedString *)iconLabel:(NSString *)symbolName text:(NSString *)text color:(UIColor *)color {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    UIImage *icon = [[UIImage systemImageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (icon) {
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = icon;
        attachment.bounds = CGRectMake(0, -2, 13, 13);
        NSAttributedString *iconStr = [NSAttributedString attributedStringWithAttachment:attachment];
        [result appendAttributedString:iconStr];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    }
    NSDictionary *attrs = color ? @{NSForegroundColorAttributeName: color} : @{};
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attrs]];
    return result;
}

- (void)configureWithPost:(CmsExampleModel *)post {
    _titleLabel.text = post.title.length > 0 ? post.title : @"No Title";
    _bodyLabel.text = post.body.length > 0 ? post.body : @"";

    _viewsLabel.attributedText = [self iconLabel:@"eye" text:[NSString stringWithFormat:@" %.0f", post.viewsCount] color:[UIColor secondaryLabelColor]];
    [_viewsLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    // Author: always show something
    NSString *authorName = @"No Author";
    if (post.author) {
        NSString *s = [post.author displayString];
        if (s.length > 0) authorName = s;
    } else if (post.authorEmail.length > 0) {
        authorName = post.authorEmail;
    }
    _authorLabel.text = authorName;
    [_authorLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_authorLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    if (post.isPublished) {
        _statusBadgeLabel.text = @" ✓ Published ";
        _statusBadgeLabel.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.12];
        _statusBadgeLabel.textColor = [UIColor systemGreenColor];
    } else {
        _statusBadgeLabel.text = @" Draft ";
        _statusBadgeLabel.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.12];
        _statusBadgeLabel.textColor = [UIColor systemOrangeColor];
    }
    _statusBadgeLabel.hidden = NO;

    _categoryBadgeLabel.text = [NSString stringWithFormat:@" %@ ", post.category.length > 0 ? post.category : @"Uncategorized"];

    if (post.eventDate.length > 0) {
        _eventDateLabel.attributedText = [self iconLabel:@"calendar" text:[NSString stringWithFormat:@" %@", post.eventDate] color:[UIColor systemGrayColor]];
        _eventDateLabel.hidden = NO;
    } else {
        _eventDateLabel.hidden = YES;
    }

    // Only show meta_data when it has key-value pairs (NSDictionary)
    if ([post.metaData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)post.metaData;
        NSMutableArray *pairs = [NSMutableArray new];
        for (NSString *key in dict.allKeys) {
            [pairs addObject:[NSString stringWithFormat:@"%@: %@", key, dict[key]]];
        }
        NSString *metaText = [pairs componentsJoinedByString:@"  ·  "];
        if (metaText.length > 0) {
            _metaDataLabel.attributedText = [self iconLabel:@"tag" text:[NSString stringWithFormat:@" %@", metaText] color:[UIColor systemBlueColor]];
            _metaDataLabel.hidden = NO;
        } else {
            _metaDataLabel.hidden = YES;
        }
    } else {
        _metaDataLabel.hidden = YES;
    }

    
    _featuredImageView.image = nil;
    BOOL hasImage = post.featuredImage && ![post.featuredImage isKindOfClass:[NSNull class]] && [post.featuredImage length] > 0;
    _featuredImageView.hidden = !hasImage;
    if (hasImage) {
        NSURL *url = [NSURL URLWithString:post.featuredImage];
        if (url) {
            [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data) {
                    UIImage *img = [UIImage imageWithData:data];
                    if (img) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.featuredImageView.image = img;
                        });
                    }
                }
            }] resume];
        }
    }
}
@end

@interface CmsViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate> {
    UITableView *_tableView;
    NSArray<CmsExampleModel *> *_posts;
    NSArray *_filters;
    NSString *_selectedFilter;
    NSString *_searchText;
    UIActivityIndicatorView *_pview;
    UIButton *_filterBtn;
    UITextField *_searchField;
}
@end

@implementation CmsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"CMS";
    
    _posts = @[];
    _selectedFilter = @"All Posts";
    _filters = @[
        @"All Posts", @"Category = tech", @"Category ≠ tech", @"Search 'swift'",
        @"Title contains 't1'", @"Category starts with 'n'", @"Category IN [science, tech]",
        @"Category NOT IN [tech, news]", @"Views > 1000", @"Views ≥ 555",
        @"Views < 15000", @"Views ≤ 15000", @"Sort Title ↑", @"Sort Title ↓", @"Page 1 (2 per page)"
    ];
    
    [self setupUI];
    [self loadPosts];
}

- (void)setupUI {
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = @"CMS Query Builder";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    _filterBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_filterBtn setTitle:@"Select a filter..." forState:UIControlStateNormal];
    _filterBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [_filterBtn addTarget:self action:@selector(showFilterPicker:) forControlEvents:UIControlEventTouchUpInside];
    [_filterBtn setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [applyBtn setTitle:@"Apply" forState:UIControlStateNormal];
    applyBtn.backgroundColor = [UIColor systemBlueColor];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.layer.cornerRadius = 6;
    applyBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [applyBtn addTarget:self action:@selector(applyFilterTapped) forControlEvents:UIControlEventTouchUpInside];
    [applyBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [applyBtn setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    UIStackView *filterRow = [[UIStackView alloc] initWithArrangedSubviews:@[_filterBtn, applyBtn]];
    filterRow.axis = UILayoutConstraintAxisHorizontal;
    filterRow.spacing = 10;
    
    _searchField = [[UITextField alloc] init];
    _searchField.placeholder = @"Search term...";
    _searchField.borderStyle = UITextBorderStyleRoundedRect;
    _searchField.delegate = self;
    _searchField.returnKeyType = UIReturnKeySearch;
    [_searchField setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [searchBtn setTitle:@"Search" forState:UIControlStateNormal];
    searchBtn.backgroundColor = [UIColor systemBlueColor];
    [searchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    searchBtn.layer.cornerRadius = 6;
    searchBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [searchBtn addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [searchBtn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [searchBtn setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    UIStackView *searchRow = [[UIStackView alloc] initWithArrangedSubviews:@[_searchField, searchBtn]];
    searchRow.axis = UILayoutConstraintAxisHorizontal;
    searchRow.spacing = 10;
    
    UIButton *getAllBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [getAllBtn setTitle:@"Get All List" forState:UIControlStateNormal];
    [getAllBtn addTarget:self action:@selector(getAllTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, filterRow, searchRow, getAllBtn]];
    headerStack.axis = UILayoutConstraintAxisVertical;
    headerStack.spacing = 15;
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    headerStack.layoutMargins = UIEdgeInsetsMake(15, 15, 15, 15);
    headerStack.layoutMarginsRelativeArrangement = YES;
    
    [self.view addSubview:headerStack];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 350;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];
    
    _pview = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _pview.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_pview];
    
    [NSLayoutConstraint activateConstraints:@[
        [headerStack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [_tableView.topAnchor constraintEqualToAnchor:headerStack.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_pview.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_pview.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)showFilterPicker:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Filter" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *f in _filters) {
        [alert addAction:[UIAlertAction actionWithTitle:f style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self->_selectedFilter = f;
            [self->_filterBtn setTitle:f forState:UIControlStateNormal];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = sender;
        alert.popoverPresentationController.sourceRect = sender.bounds;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyFilterTapped {
    [_searchField resignFirstResponder];
    _searchField.text = @"";
    _searchText = @"";
    [self loadPosts];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self searchTapped];
    return YES;
}

- (void)searchTapped {
    [_searchField resignFirstResponder];
    _searchText = _searchField.text;
    if (_searchText.length > 0) {
        [_filterBtn setTitle:@"All Posts" forState:UIControlStateNormal];
        _selectedFilter = @"All Posts";
        [self searchPosts];
    } else {
        [self getAllTapped];
    }
}

- (void)getAllTapped {
    [_searchField resignFirstResponder];
    _selectedFilter = @"All Posts";
    [_filterBtn setTitle:@"All Posts" forState:UIControlStateNormal];
    _searchText = @"";
    _searchField.text = @"";
    [self loadPosts];
}

- (void)loadPosts {
    [_pview startAnimating];
    
    CmsQueryObjC *query = [Cms contentWithType:@"blog_extended"];
    
    if ([_selectedFilter isEqualToString:@"Category = tech"]) [query equals:@"category" value:@"tech"];
    else if ([_selectedFilter isEqualToString:@"Category ≠ tech"]) [query notEquals:@"category" value:@"tech"];
    else if ([_selectedFilter isEqualToString:@"Search 'swift'"]) [query search:@"swift"];
    else if ([_selectedFilter isEqualToString:@"Title contains 't1'"]) [query contains:@"title" value:@"t1"];
    else if ([_selectedFilter isEqualToString:@"Category starts with 'n'"]) [query startsWith:@"category" value:@"n"];
    else if ([_selectedFilter isEqualToString:@"Category IN [science, tech]"]) [query inList:@"category" values:@[@"science", @"tech"]];
    else if ([_selectedFilter isEqualToString:@"Category NOT IN [tech, news]"]) [query notInList:@"category" values:@[@"tech", @"news"]];
    else if ([_selectedFilter isEqualToString:@"Views > 1000"]) [query greaterThan:@"views_count" value:@1000];
    else if ([_selectedFilter isEqualToString:@"Views ≥ 555"]) [query greaterThanOrEqual:@"views_count" value:@555];
    else if ([_selectedFilter isEqualToString:@"Views < 15000"]) [query lessThan:@"views_count" value:@15000];
    else if ([_selectedFilter isEqualToString:@"Views ≤ 15000"]) [query lessThanOrEqual:@"views_count" value:@15000];
    else if ([_selectedFilter isEqualToString:@"Sort Title ↑"]) [query orderByAscending:@"title"];
    else if ([_selectedFilter isEqualToString:@"Sort Title ↓"]) [query orderByDescending:@"title"];
    else if ([_selectedFilter isEqualToString:@"Page 1 (2 per page)"]) { [query getPage:1]; [query getPerPage:2]; }
    
    [query getListWithCompletion:^(NSArray * _Nonnull items) {
        NSMutableArray *postObjs = [NSMutableArray new];
        for (NSDictionary *d in items) {
            [postObjs addObject:[[CmsExampleModel alloc] initWithDictionary:d]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_posts = postObjs;
            [self->_tableView reloadData];
            [self->_pview stopAnimating];
        });
    }];
}

- (void)searchPosts {
    [_pview startAnimating];
    CmsQueryObjC *query = [Cms contentWithType:@"blog_extended"];
    [query search:_searchText];
    
    [query getListWithCompletion:^(NSArray * _Nonnull items) {
        NSMutableArray *postObjs = [NSMutableArray new];
        for (NSDictionary *d in items) {
            [postObjs addObject:[[CmsExampleModel alloc] initWithDictionary:d]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_posts = postObjs;
            [self->_tableView reloadData];
            [self->_pview stopAnimating];
        });
    }];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _posts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PostTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PostCell"];
    if (!cell) {
        cell = [[PostTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PostCell"];
    }
    
    [cell configureWithPost:_posts[indexPath.row]];
    return cell;
}

@end
