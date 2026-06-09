#import "DatabaseViewController.h"
@import AppAmbit;

@interface DemoItem : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) void (^action)(void);
- (instancetype)initWithLabel:(NSString *)label action:(void (^)(void))action;
@end
@implementation DemoItem
- (instancetype)initWithLabel:(NSString *)label action:(void (^)(void))action {
    self = [super init];
    _label = label; _action = action; return self;
}
@end

@interface DatabaseViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UITextView *sqlInput;
@property (nonatomic, strong) UIButton *dropdownButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIScrollView *tableScroll;
@property (nonatomic, strong) UIView *tableCard;
@property (nonatomic, strong) UIStackView *resultGrid;
@property (nonatomic, strong) UILabel *rowCountLabel;
@property (nonatomic, strong) NSArray<DemoItem *> *demos;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation DatabaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Database";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.selectedIndex = 0;
    [self buildDemos];
    [self setupUI];
}

// MARK: - Build demos

- (void)buildDemos {
    self.demos = @[
        [[DemoItem alloc] initWithLabel:@"Raw SQL → execute(sql)"                         action:^{ [self demoExecute]; }],
        [[DemoItem alloc] initWithLabel:@"Raw SQL → execute(sql, params)"                 action:^{ [self demoExecuteParams]; }],
        [[DemoItem alloc] initWithLabel:@"Schema → CREATE TABLE tasks"                    action:^{ [self demoCreateTable]; }],
        [[DemoItem alloc] initWithLabel:@"Schema → DROP TABLE tasks"                      action:^{ [self demoDropTable]; }],
        [[DemoItem alloc] initWithLabel:@"Batch → batch()"                                action:^{ [self demoBatch]; }],
        [[DemoItem alloc] initWithLabel:@"Batch → batchInTransaction()"                   action:^{ [self demoBatchInTransaction]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent SELECT → select+where+orderByDesc+limit" action:^{ [self demoFluentSelect]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent SELECT → where(col, val)"                action:^{ [self demoWhereEquality]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent SELECT → whereIn()"                      action:^{ [self demoWhereIn]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent SELECT → limit+offset"                   action:^{ [self demoOffset]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent SELECT → first()"                        action:^{ [self demoFirst]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent SELECT → count()"                        action:^{ [self demoCount]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent WRITE → insert()"                        action:^{ [self demoInsert]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent WRITE → insert() high priority"          action:^{ [self demoInsertHigh]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent WRITE → insert() raw SQL"                action:^{ [self demoInsertRawSQL]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent WRITE → insert many (batch)"             action:^{ [self demoInsertMany]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent WRITE → update()"                        action:^{ [self demoUpdate]; }],
        [[DemoItem alloc] initWithLabel:@"Fluent WRITE → delete()"                        action:^{ [self demoDelete]; }],
        [[DemoItem alloc] initWithLabel:@"Typed Model → from(tasks) typed mapping"        action:^{ [self demoTypedModel]; }],
        [[DemoItem alloc] initWithLabel:@"Preset → List tables"                           action:^{ [self demoPresetTables]; }],
        [[DemoItem alloc] initWithLabel:@"Preset → SELECT * WHERE priority='high'"        action:^{ [self demoPresetHighPriority]; }],
    ];
}

// MARK: - Setup UI

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 8;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    // SQL input
    self.sqlInput = [[UITextView alloc] init];
    self.sqlInput.text = @"SELECT * FROM tasks LIMIT 10";
    self.sqlInput.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.sqlInput.layer.borderColor = UIColor.separatorColor.CGColor;
    self.sqlInput.layer.borderWidth = 1;
    self.sqlInput.layer.cornerRadius = 8;
    self.sqlInput.autocorrectionType = UITextAutocorrectionTypeNo;
    self.sqlInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.sqlInput.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sqlInput.heightAnchor constraintEqualToConstant:72].active = YES;
    [self.stackView addArrangedSubview:self.sqlInput];

    // Dropdown + Run row
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.alignment = UIStackViewAlignmentCenter;

    self.dropdownButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.dropdownButton setTitle:[self.demos[0] label] forState:UIControlStateNormal];
    self.dropdownButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.dropdownButton.backgroundColor = UIColor.systemBackgroundColor;
    self.dropdownButton.layer.borderColor = UIColor.separatorColor.CGColor;
    self.dropdownButton.layer.borderWidth = 1;
    self.dropdownButton.layer.cornerRadius = 8;
    self.dropdownButton.titleLabel.font = [UIFont systemFontOfSize:12];
    self.dropdownButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.dropdownButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [self.dropdownButton setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    self.dropdownButton.menu = [self buildMenu];
    self.dropdownButton.showsMenuAsPrimaryAction = YES;
    [row addArrangedSubview:self.dropdownButton];

    UIButton *runBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.title = @"Run";
    cfg.image = [UIImage systemImageNamed:@"play.fill"];
    cfg.imagePadding = 4;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 14, 10, 14);
    cfg.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attr) {
        NSMutableDictionary *m = [attr mutableCopy];
        m[NSFontAttributeName] = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        return m;
    };
    runBtn.configuration = cfg;
    [runBtn setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [runBtn addTarget:self action:@selector(runDemo) forControlEvents:UIControlEventTouchUpInside];
    [row addArrangedSubview:runBtn];

    [self.stackView addArrangedSubview:row];

    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.text = @"Select a demo and tap Run.";
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.statusLabel.layer.cornerRadius = 8;
    self.statusLabel.clipsToBounds = YES;
    UIView *statusWrapper = [self paddedWrapper:self.statusLabel];
    [self.stackView addArrangedSubview:statusWrapper];

    // Progress
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.hidden = YES;
    [self.stackView addArrangedSubview:self.progressView];

    // Table card
    self.tableCard = [[UIView alloc] init];
    self.tableCard.backgroundColor = UIColor.systemBackgroundColor;
    self.tableCard.layer.cornerRadius = 10;
    self.tableCard.layer.shadowColor = UIColor.blackColor.CGColor;
    self.tableCard.layer.shadowOpacity = 0.07;
    self.tableCard.layer.shadowRadius = 2;
    self.tableCard.layer.shadowOffset = CGSizeMake(0, 1);
    self.tableCard.hidden = YES;
    self.tableCard.translatesAutoresizingMaskIntoConstraints = NO;

    self.tableScroll = [[UIScrollView alloc] init];
    self.tableScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScroll.showsHorizontalScrollIndicator = YES;
    [self.tableCard addSubview:self.tableScroll];

    self.resultGrid = [[UIStackView alloc] init];
    self.resultGrid.axis = UILayoutConstraintAxisVertical;
    self.resultGrid.spacing = 0;
    self.resultGrid.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableScroll addSubview:self.resultGrid];

    self.rowCountLabel = [[UILabel alloc] init];
    self.rowCountLabel.font = [UIFont systemFontOfSize:11];
    self.rowCountLabel.textColor = UIColor.secondaryLabelColor;
    self.rowCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableCard addSubview:self.rowCountLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableScroll.topAnchor constraintEqualToAnchor:self.tableCard.topAnchor],
        [self.tableScroll.leadingAnchor constraintEqualToAnchor:self.tableCard.leadingAnchor],
        [self.tableScroll.trailingAnchor constraintEqualToAnchor:self.tableCard.trailingAnchor],

        [self.resultGrid.topAnchor constraintEqualToAnchor:self.tableScroll.topAnchor],
        [self.resultGrid.leadingAnchor constraintEqualToAnchor:self.tableScroll.leadingAnchor],
        [self.resultGrid.trailingAnchor constraintEqualToAnchor:self.tableScroll.trailingAnchor],
        [self.resultGrid.bottomAnchor constraintEqualToAnchor:self.tableScroll.bottomAnchor],

        [self.tableScroll.bottomAnchor constraintEqualToAnchor:self.rowCountLabel.topAnchor constant:-1],
        [self.rowCountLabel.leadingAnchor constraintEqualToAnchor:self.tableCard.leadingAnchor constant:12],
        [self.rowCountLabel.trailingAnchor constraintEqualToAnchor:self.tableCard.trailingAnchor constant:-12],
        [self.rowCountLabel.bottomAnchor constraintEqualToAnchor:self.tableCard.bottomAnchor constant:-6],
    ]];
    [self.stackView addArrangedSubview:self.tableCard];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:12],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-24],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32],
    ]];
}

- (UIMenu *)buildMenu {
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.demos.count; i++) {
        DemoItem *item = self.demos[i];
        NSInteger index = i;
        UIAction *action = [UIAction actionWithTitle:item.label image:nil identifier:nil
                                            handler:^(__kindof UIAction *a) {
            self.selectedIndex = index;
            [self.dropdownButton setTitle:item.label forState:UIControlStateNormal];
        }];
        [actions addObject:action];
    }
    return [UIMenu menuWithTitle:@"" children:actions];
}

// MARK: - Run

- (void)runDemo {
    [self startLoading];
    self.demos[self.selectedIndex].action();
}

// MARK: - Raw SQL

- (void)demoExecute {
    NSString *q = [self.sqlInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (q.length == 0) return;
    [AppAmbitDb execute:q completion:^(DbResult *result, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
        [self showResult:result label:@"execute(sql)"];
    }];
}

- (void)demoExecuteParams {
    [AppAmbitDb execute:@"SELECT * FROM tasks WHERE is_completed = ? LIMIT ?"
                 params:@[@0, @10]
             completion:^(DbResult *result, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
        [self showResult:result label:@"execute(sql, 0, 10)"];
    }];
}

// MARK: - Schema

- (void)demoCreateTable {
    [AppAmbitDb execute:@"CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, is_completed INTEGER DEFAULT 0, priority TEXT, due_date TEXT)"
             completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"CREATE TABLE"];
    }];
}

- (void)demoDropTable {
    [AppAmbitDb execute:@"DROP TABLE IF EXISTS tasks"
             completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"DROP TABLE"];
    }];
}

// MARK: - Batch

- (void)demoBatch {
    NSArray<DbStatement *> *stmts = @[
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Buy coffee", @0, @"low", @"2026-06-10"]],
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Review PR", @0, @"high", @"2026-06-05"]],
        [DbStatement of:@"SELECT COUNT(*) AS total FROM tasks"]
    ];
    [AppAmbitDb batch:stmts completion:^(NSArray<DbResult *> *results, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        NSInteger written = 0;
        for (DbResult *r in results) written += r.rowsWritten;
        NSArray<NSString *> *cols = @[@"statement", @"rows_written", @"rows_read"];
        NSMutableArray<NSArray *> *rows = [NSMutableArray array];
        [results enumerateObjectsUsingBlock:^(DbResult *r, NSUInteger i, BOOL *stop) {
            [rows addObject:@[@(i + 1), @(r.rowsWritten), @(r.rowsRead)]];
        }];
        [self setOk:[NSString stringWithFormat:
            @"batch() — %ld row(s) written across %lu statements (no transaction)",
            (long)written, (unsigned long)results.count]];
        [self buildResultTable:cols rows:rows];
    }];
}

- (void)demoBatchInTransaction {
    NSArray<DbStatement *> *stmts = @[
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Team meeting", @0, @"high", @"2026-06-06"]],
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Prepare agenda", @0, @"medium", @"2026-06-06"]]
    ];
    [AppAmbitDb batchInTransaction:stmts completion:^(NSArray<DbResult *> *results, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        NSInteger written = 0;
        for (DbResult *r in results) written += r.rowsWritten;
        NSArray<NSString *> *cols = @[@"statement", @"rows_written"];
        NSMutableArray<NSArray *> *rows = [NSMutableArray array];
        [results enumerateObjectsUsingBlock:^(DbResult *r, NSUInteger i, BOOL *stop) {
            [rows addObject:@[@(i + 1), @(r.rowsWritten)]];
        }];
        [self setOk:[NSString stringWithFormat:
            @"batchInTransaction() — %ld row(s) written, rolled back on failure", (long)written]];
        [self buildResultTable:cols rows:rows];
    }];
}

// MARK: - Fluent SELECT

- (void)demoFluentSelect {
    [[[[[[AppAmbitDb from:@"tasks"]
         select:@[@"id", @"title", @"priority", @"due_date"]]
        where:@"is_completed" op:@"=" value:@0]
       orderByDesc:@"due_date"]
      limit:5]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setOk:@"No pending tasks"]; return; }
        [self setOk:[NSString stringWithFormat:
            @"from().select().where().orderByDesc().limit(5) — %lu row(s)", (unsigned long)rows.count]];
        [self showMaps:rows];
    }];
}

- (void)demoWhereEquality {
    [[[AppAmbitDb from:@"tasks"] where:@"is_completed" value:@0]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setOk:@"No pending tasks"]; return; }
        [self setOk:[NSString stringWithFormat:
            @"where(is_completed, 0) — %lu task(s)", (unsigned long)rows.count]];
        [self showMaps:rows];
    }];
}

- (void)demoWhereIn {
    [[[[AppAmbitDb from:@"tasks"]
       whereIn:@"priority" values:@[@"high", @"medium"]]
      orderBy:@"due_date"]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setOk:@"No high/medium tasks"]; return; }
        [self setOk:[NSString stringWithFormat:
            @"whereIn(priority, [high, medium]) — %lu row(s)", (unsigned long)rows.count]];
        [self showMaps:rows];
    }];
}

- (void)demoOffset {
    [[[[AppAmbitDb from:@"tasks"] orderBy:@"due_date"] limit:5]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setOk:@"No tasks"]; return; }
        [self setOk:[NSString stringWithFormat:
            @"limit(5).offset(0) — page 1, %lu row(s)", (unsigned long)rows.count]];
        [self showMaps:rows];
    }];
}

- (void)demoFirst {
    [[[[AppAmbitDb from:@"tasks"] where:@"is_completed" op:@"=" value:@0] orderBy:@"due_date"]
     firstWithCompletion:^(NSDictionary *row, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (!row) { [self setOk:@"first() — No pending tasks"]; return; }
        [self setOk:@"first() — next task due"];
        [self showMaps:@[row]];
    }];
}

- (void)demoCount {
    [[[AppAmbitDb from:@"tasks"] where:@"is_completed" value:@0]
     countWithCompletion:^(NSInteger count, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        [self setOk:[NSString stringWithFormat:@"count() — %ld pending task(s)", (long)count]];
        [self buildResultTable:@[@"pending_tasks"] rows:@[@[@(count)]]];
    }];
}

// MARK: - Fluent WRITE

- (void)demoInsert {
    [[AppAmbitDb from:@"tasks"]
     insert:@{@"title": @"New task", @"is_completed": @0, @"priority": @"medium", @"due_date": @"2026-06-10"}
     completion:^(DbResult *result, NSError *error) {
        if (![self assertWriteResult:result error:error label:@"insert()"]) return;
        [self buildResultTable:@[@"rows_written"] rows:@[@[@(result.rowsWritten)]]];
    }];
}

- (void)demoInsertHigh {
    [[AppAmbitDb from:@"tasks"]
     insert:@{@"title": @"Fix critical bug", @"is_completed": @0, @"priority": @"high", @"due_date": @"2026-06-05"}
     completion:^(DbResult *result, NSError *error) {
        if (![self assertWriteResult:result error:error label:@"insert() high priority"]) return;
        [self buildResultTable:@[@"rows_written"] rows:@[@[@(result.rowsWritten)]]];
    }];
}

- (void)demoInsertRawSQL {
    [AppAmbitDb execute:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Raw SQL insert", @0, @"medium", @"2026-06-12"]
             completion:^(DbResult *result, NSError *error) {
        if (![self assertWriteResult:result error:error label:@"execute() INSERT"]) return;
        [self buildResultTable:@[@"rows_written"] rows:@[@[@(result.rowsWritten)]]];
    }];
}

- (void)demoInsertMany {
    NSArray<DbStatement *> *stmts = @[
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Write unit tests", @0, @"high", @"2026-06-07"]],
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Update documentation", @0, @"low", @"2026-06-15"]],
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Code review", @0, @"medium", @"2026-06-08"]],
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Deploy to staging", @0, @"high", @"2026-06-09"]],
        [DbStatement of:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Monitor metrics", @0, @"low", @"2026-06-20"]]
    ];
    [AppAmbitDb batchInTransaction:stmts completion:^(NSArray<DbResult *> *results, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        NSInteger written = 0;
        for (DbResult *r in results) written += r.rowsWritten;
        [self setOk:[NSString stringWithFormat:@"insert many — %ld rows inserted via batch", (long)written]];
        [self buildResultTable:@[@"rows_inserted"] rows:@[@[@(written)]]];
    }];
}

- (void)demoUpdate {
    [[[AppAmbitDb from:@"tasks"] where:@"title" value:@"New task"]
     update:@{@"is_completed": @1}
     completion:^(DbResult *result, NSError *error) {
        if (![self assertWriteResult:result error:error label:@"update()"]) return;
        [self buildResultTable:@[@"rows_written"] rows:@[@[@(result.rowsWritten)]]];
    }];
}

- (void)demoDelete {
    [[[AppAmbitDb from:@"tasks"] where:@"is_completed" value:@1]
     deleteWithCompletion:^(DbResult *result, NSError *error) {
        if (![self assertWriteResult:result error:error label:@"delete()"]) return;
        [self buildResultTable:@[@"rows_written"] rows:@[@[@(result.rowsWritten)]]];
    }];
}

// MARK: - Typed Model

- (void)demoTypedModel {
    [[[[AppAmbitDb from:@"tasks"]
       select:@[@"id", @"title", @"is_completed", @"priority", @"due_date"]]
      limit:5]
     getWithCompletion:^(NSArray<NSDictionary *> *maps, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        NSArray<NSString *> *cols = @[@"id", @"title", @"isCompleted", @"priority", @"dueDate"];
        NSMutableArray<NSArray *> *rows = [NSMutableArray array];
        for (NSDictionary *map in maps) {
            [rows addObject:@[
                map[@"id"]           ?: [NSNull null],
                map[@"title"]        ?: [NSNull null],
                map[@"is_completed"] ?: [NSNull null],
                map[@"priority"]     ?: [NSNull null],
                map[@"due_date"]     ?: [NSNull null],
            ]];
        }
        [self setOk:[NSString stringWithFormat:
            @"from(\"tasks\") typed mapping — %lu row(s)", (unsigned long)maps.count]];
        [self buildResultTable:cols rows:rows];
    }];
}

// MARK: - Presets

- (void)demoPresetTables {
    NSString *q = @"SELECT name FROM sqlite_master WHERE type = 'table'";
    dispatch_async(dispatch_get_main_queue(), ^{ self.sqlInput.text = q; });
    [AppAmbitDb execute:q completion:^(DbResult *result, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
        [self setOk:[NSString stringWithFormat:@"sqlite_master tables — %ld row(s)", (long)result.rowsRead]];
        [self buildResultTable:result.columns rows:result.rows];
    }];
}

- (void)demoPresetHighPriority {
    NSString *q = @"SELECT * FROM tasks WHERE priority = 'high'";
    dispatch_async(dispatch_get_main_queue(), ^{ self.sqlInput.text = q; });
    [AppAmbitDb execute:q completion:^(DbResult *result, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
        [self setOk:[NSString stringWithFormat:@"tasks WHERE priority='high' — %ld row(s)", (long)result.rowsRead]];
        [self buildResultTable:result.columns rows:result.rows];
    }];
}

// MARK: - Result table

- (void)buildResultTable:(NSArray<NSString *> *)columns rows:(NSArray<NSArray *> *)rows {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in self.resultGrid.arrangedSubviews) {
            [self.resultGrid removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        if (columns.count == 0) {
            self.tableCard.hidden = YES;
            return;
        }

        // Header
        UIView *header = [self makeHeaderRow:columns];
        [self.resultGrid addArrangedSubview:header];
        [self.resultGrid addArrangedSubview:[self thinDividerWithColor:[UIColor colorWithRed:0.63 green:0.73 blue:0.93 alpha:0.5]]];

        if (rows.count == 0) {
            UILabel *empty = [[UILabel alloc] init];
            empty.text = @"(no rows)";
            empty.font = [UIFont systemFontOfSize:12];
            empty.textColor = UIColor.secondaryLabelColor;
            empty.translatesAutoresizingMaskIntoConstraints = NO;
            UIView *emptyWrap = [[UIView alloc] init];
            [emptyWrap addSubview:empty];
            [NSLayoutConstraint activateConstraints:@[
                [empty.topAnchor constraintEqualToAnchor:emptyWrap.topAnchor constant:12],
                [empty.leadingAnchor constraintEqualToAnchor:emptyWrap.leadingAnchor constant:12],
                [empty.trailingAnchor constraintEqualToAnchor:emptyWrap.trailingAnchor constant:-12],
                [empty.bottomAnchor constraintEqualToAnchor:emptyWrap.bottomAnchor constant:-12],
            ]];
            [self.resultGrid addArrangedSubview:emptyWrap];
        } else {
            for (NSUInteger ri = 0; ri < rows.count; ri++) {
                NSArray *row = rows[ri];
                NSMutableArray<NSString *> *vals = [NSMutableArray array];
                for (NSUInteger ci = 0; ci < columns.count; ci++) {
                    id val = ci < row.count ? row[ci] : [NSNull null];
                    [vals addObject:[val isKindOfClass:[NSNull class]] ? @"null"
                        : [NSString stringWithFormat:@"%@", val]];
                }
                BOOL isNull_unused __attribute__((unused)) = NO;
                UIColor *bg = (ri % 2 == 0)
                    ? UIColor.systemBackgroundColor
                    : [UIColor colorWithWhite:0.95 alpha:0.45];
                [self.resultGrid addArrangedSubview:[self makeDataRow:vals background:bg]];
                if (ri < rows.count - 1) {
                    [self.resultGrid addArrangedSubview:[self thinDividerWithColor:[UIColor.separatorColor colorWithAlphaComponent:0.5]]];
                }
            }
            [self.resultGrid addArrangedSubview:[self thinDividerWithColor:UIColor.separatorColor]];
        }

        NSInteger n = (NSInteger)rows.count;
        self.rowCountLabel.text = n == 1 ? @"1 row" : [NSString stringWithFormat:@"%ld rows", (long)n];

        CGFloat gridW = MAX(self.tableScroll.bounds.size.width, columns.count * 140.0);
        [self.resultGrid.widthAnchor constraintEqualToConstant:gridW].active = YES;
        CGFloat gridH = MIN(n * 40.0 + 44.0, 320.0);
        [self.tableScroll.heightAnchor constraintEqualToConstant:gridH].active = YES;

        self.tableCard.hidden = NO;
    });
}

- (UIView *)makeHeaderRow:(NSArray<NSString *> *)columns {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionEqualSpacing;
    row.spacing = 0;
    row.backgroundColor = [UIColor colorWithRed:0.88 green:0.91 blue:0.98 alpha:1.0];
    for (NSString *col in columns) {
        UILabel *lbl = [[UILabel alloc] init];
        lbl.text = col;
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        lbl.textColor = [UIColor colorWithRed:0.10 green:0.14 blue:0.49 alpha:1.0];
        lbl.numberOfLines = 1;
        lbl.lineBreakMode = NSLineBreakByTruncatingTail;
        UIView *cell = [[UIView alloc] init];
        cell.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.widthAnchor constraintEqualToConstant:140].active = YES;
        [cell addSubview:lbl];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [lbl.topAnchor constraintEqualToAnchor:cell.topAnchor constant:10],
            [lbl.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:12],
            [lbl.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
            [lbl.bottomAnchor constraintEqualToAnchor:cell.bottomAnchor constant:-10],
        ]];
        [row addArrangedSubview:cell];
    }
    return row;
}

- (UIView *)makeDataRow:(NSArray<NSString *> *)values background:(UIColor *)bg {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionEqualSpacing;
    row.spacing = 0;
    row.backgroundColor = bg;
    for (NSString *val in values) {
        BOOL isNull = [val isEqualToString:@"null"];
        UILabel *lbl = [[UILabel alloc] init];
        lbl.text = val;
        lbl.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        lbl.textColor = isNull ? UIColor.secondaryLabelColor : UIColor.labelColor;
        lbl.numberOfLines = 2;
        lbl.lineBreakMode = NSLineBreakByTruncatingTail;
        UIView *cell = [[UIView alloc] init];
        cell.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.widthAnchor constraintEqualToConstant:140].active = YES;
        [cell addSubview:lbl];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [lbl.topAnchor constraintEqualToAnchor:cell.topAnchor constant:10],
            [lbl.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:12],
            [lbl.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
            [lbl.bottomAnchor constraintEqualToAnchor:cell.bottomAnchor constant:-10],
        ]];
        [row addArrangedSubview:cell];
    }
    return row;
}

- (UIView *)thinDividerWithColor:(UIColor *)color {
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = color;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [sep.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return sep;
}

// MARK: - Helpers

- (void)showResult:(DbResult *)result label:(NSString *)label {
    [self setOk:[NSString stringWithFormat:
        @"%@ — rows_read=%ld  rows_written=%ld",
        label, (long)result.rowsRead, (long)result.rowsWritten]];
    [self buildResultTable:result.columns rows:result.rows];
}

- (void)showMaps:(NSArray<NSDictionary *> *)maps {
    if (maps.count == 0) return;
    NSArray<NSString *> *cols = maps.firstObject.allKeys;
    NSMutableArray<NSArray *> *rows = [NSMutableArray array];
    for (NSDictionary *map in maps) {
        NSMutableArray *row = [NSMutableArray array];
        for (NSString *col in cols) [row addObject:map[col] ?: [NSNull null]];
        [rows addObject:row];
    }
    [self buildResultTable:cols rows:rows];
}

- (void)writeResult:(DbResult *)result error:(NSError *)error label:(NSString *)label {
    if (![self assertWriteResult:result error:error label:label]) return;
    [self setOk:[NSString stringWithFormat:
        @"%@ OK — rows_read=%ld  rows_written=%ld",
        label, (long)result.rowsRead, (long)result.rowsWritten]];
}

- (BOOL)assertWriteResult:(DbResult *)result error:(NSError *)error label:(NSString *)label {
    if (error) { [self setError:error.localizedDescription]; return NO; }
    if (!result) { [self setOk:[NSString stringWithFormat:@"%@: no result", label]]; return NO; }
    if (result.hasError) { [self setError:result.error ?: @"DB error"]; return NO; }
    return YES;
}

- (void)startLoading {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in self.resultGrid.arrangedSubviews) {
            [self.resultGrid removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        self.tableCard.hidden = YES;
        self.statusLabel.text = @"Running…";
        self.statusLabel.textColor = UIColor.secondaryLabelColor;
        self.statusLabel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.progressView.hidden = NO;
        self.progressView.progress = 0;
        [UIView animateWithDuration:1.5 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.progressView.progress = 0.85;
        } completion:nil];
    });
}

- (void)setOk:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.hidden = YES;
        self.statusLabel.text = text;
        self.statusLabel.textColor = [UIColor colorWithRed:0.11 green:0.37 blue:0.13 alpha:1.0];
        self.statusLabel.backgroundColor = [UIColor colorWithRed:0.91 green:0.96 blue:0.91 alpha:1.0];
    });
}

- (void)setError:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.hidden = YES;
        for (UIView *v in self.resultGrid.arrangedSubviews) {
            [self.resultGrid removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        self.tableCard.hidden = YES;
        self.statusLabel.text = [NSString stringWithFormat:@"Error: %@", msg];
        self.statusLabel.textColor = [UIColor colorWithRed:0.78 green:0.16 blue:0.16 alpha:1.0];
        self.statusLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.92 blue:0.92 alpha:1.0];
    });
}

- (UIView *)paddedWrapper:(UIView *)inner {
    UIView *wrapper = [[UIView alloc] init];
    [wrapper addSubview:inner];
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:8],
        [inner.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:8],
        [inner.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-8],
        [inner.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-8],
    ]];
    return wrapper;
}

@end
