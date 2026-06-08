#import "DatabaseViewController.h"
@import AppAmbit;

@interface DatabaseViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UITextView *sqlInput;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UIStackView *resultGrid;
@end

@implementation DatabaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Database";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self setupUI];
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 8;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.text = @"Tap a button to run a demo.";
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.statusLabel.layer.cornerRadius = 8;
    self.statusLabel.clipsToBounds = YES;
    UIView *statusWrapper = [self wrapWithPadding:self.statusLabel];
    [self.stackView addArrangedSubview:statusWrapper];

    // Result table container
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.hidden = YES;
    self.resultContainer.layer.cornerRadius = 8;
    self.resultContainer.clipsToBounds = YES;
    self.resultContainer.layer.borderColor = UIColor.separatorColor.CGColor;
    self.resultContainer.layer.borderWidth = 0.5;
    [self.stackView addArrangedSubview:self.resultContainer];

    self.resultGrid = [[UIStackView alloc] init];
    self.resultGrid.axis = UILayoutConstraintAxisVertical;
    self.resultGrid.spacing = 0;
    self.resultGrid.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:self.resultGrid];
    [NSLayoutConstraint activateConstraints:@[
        [self.resultGrid.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor],
        [self.resultGrid.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor],
        [self.resultGrid.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor],
        [self.resultGrid.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor],
    ]];

    // SQL input
    [self addSectionHeader:@"Raw SQL"];

    self.sqlInput = [[UITextView alloc] init];
    self.sqlInput.text = @"SELECT * FROM tasks LIMIT 10";
    self.sqlInput.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.sqlInput.layer.borderColor = UIColor.separatorColor.CGColor;
    self.sqlInput.layer.borderWidth = 0.5;
    self.sqlInput.layer.cornerRadius = 8;
    self.sqlInput.autocorrectionType = UITextAutocorrectionTypeNo;
    self.sqlInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.sqlInput.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sqlInput.heightAnchor constraintEqualToConstant:72].active = YES;
    [self.stackView addArrangedSubview:self.sqlInput];

    [self addButton:@"execute(sql)" selector:@selector(executeSQL)];
    [self addButton:@"execute(sql, params) — is_completed=0 LIMIT 10" selector:@selector(executeParams)];
    [self addButton:@"Preset: SELECT sqlite_master tables" selector:@selector(presetTables)];
    [self addButton:@"Preset: SELECT WHERE priority = 'high'" selector:@selector(presetHighPriority)];

    // Schema
    [self addSectionHeader:@"Schema"];
    [self addButton:@"CREATE TABLE tasks" selector:@selector(createTable)];
    [self addButton:@"DROP TABLE tasks" selector:@selector(dropTable)];

    // Batch
    [self addSectionHeader:@"Batch"];
    [self addButton:@"batch() — 2 inserts + count" selector:@selector(demoBatch)];
    [self addButton:@"batchInTransaction() — 2 inserts" selector:@selector(demoBatchInTransaction)];

    // Fluent SELECT
    [self addSectionHeader:@"Fluent Builder — SELECT"];
    [self addButton:@"select+where+orderByDesc+limit" selector:@selector(demoFluentSelect)];
    [self addButton:@"where(is_completed, 0)" selector:@selector(demoWhereEquality)];
    [self addButton:@"whereIn(priority, [high, medium])" selector:@selector(demoWhereIn)];
    [self addButton:@"limit(5).offset(0)" selector:@selector(demoOffset)];
    [self addButton:@"first() — next pending task" selector:@selector(demoFirst)];
    [self addButton:@"count() — pending tasks" selector:@selector(demoCount)];

    // Fluent WRITE
    [self addSectionHeader:@"Fluent Builder — WRITE"];
    [self addButton:@"insert() — single row (medium priority)" selector:@selector(demoInsert)];
    [self addButton:@"insert() — high priority task" selector:@selector(demoInsertHigh)];
    [self addButton:@"insert() — raw SQL execute" selector:@selector(demoInsertRawSQL)];
    [self addButton:@"insert many — seed 5 rows (batch)" selector:@selector(demoInsertMany)];
    [self addButton:@"update() — mark as completed" selector:@selector(demoUpdate)];
    [self addButton:@"delete() — remove completed" selector:@selector(demoDelete)];

    // Typed Model
    [self addSectionHeader:@"Typed Model"];
    [self addButton:@"from(\"tasks\") — typed mapping" selector:@selector(demoTypedModel)];

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

// MARK: - Raw SQL

- (void)executeSQL {
    NSString *q = [self.sqlInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (q.length == 0) return;
    [self startAction:@"Running…"];
    [AppAmbitDb execute:q completion:^(DbResult *result, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
        [self showResult:result label:@"execute(sql)"];
    }];
}

- (void)executeParams {
    [self startAction:@"Running parameterized query…"];
    [AppAmbitDb execute:@"SELECT * FROM tasks WHERE is_completed = ? LIMIT ?"
                 params:@[@0, @10]
             completion:^(DbResult *result, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
        [self showResult:result label:@"execute(sql, 0, 10)"];
    }];
}

- (void)presetTables {
    self.sqlInput.text = @"SELECT name FROM sqlite_master WHERE type = 'table'";
    [self executeSQL];
}

- (void)presetHighPriority {
    self.sqlInput.text = @"SELECT * FROM tasks WHERE priority = 'high'";
    [self executeSQL];
}

// MARK: - Schema

- (void)createTable {
    [self startAction:@"Running CREATE TABLE…"];
    [AppAmbitDb execute:@"CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, is_completed INTEGER DEFAULT 0, priority TEXT, due_date TEXT)"
             completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"CREATE TABLE"];
    }];
}

- (void)dropTable {
    [self startAction:@"Running DROP TABLE…"];
    [AppAmbitDb execute:@"DROP TABLE IF EXISTS tasks"
             completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"DROP TABLE"];
    }];
}

// MARK: - Batch

- (void)demoBatch {
    [self startAction:@"Running batch (no transaction)…"];
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
        [self setStatus:[NSString stringWithFormat:
            @"batch() — %ld row(s) written across %lu statements (no transaction)",
            (long)written, (unsigned long)results.count] isError:NO];
        NSArray<NSString *> *cols = @[@"statement", @"rows_written"];
        NSMutableArray<NSArray *> *rows = [NSMutableArray array];
        [results enumerateObjectsUsingBlock:^(DbResult *r, NSUInteger i, BOOL *stop) {
            [rows addObject:@[@(i + 1), @(r.rowsWritten)]];
        }];
        [self buildResultTable:cols rows:rows];
    }];
}

- (void)demoBatchInTransaction {
    [self startAction:@"Running batch in transaction…"];
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
        [self setStatus:[NSString stringWithFormat:
            @"batchInTransaction() — %ld row(s) written, rolled back on failure", (long)written]
                isError:NO];
    }];
}

// MARK: - Fluent SELECT

- (void)demoFluentSelect {
    [self startAction:@"Running fluent select…"];
    [[[[[[AppAmbitDb from:@"tasks"]
         select:@[@"id", @"title", @"priority", @"due_date"]]
        where:@"is_completed" op:@"=" value:@0]
       orderByDesc:@"due_date"]
      limit:5]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setStatus:@"No pending tasks" isError:NO]; return; }
        [self setStatus:[NSString stringWithFormat:
            @"pending tasks by due date — %lu row(s)", (unsigned long)rows.count] isError:NO];
        [self showMaps:rows];
    }];
}

- (void)demoWhereEquality {
    [self startAction:@"where equality…"];
    [[[AppAmbitDb from:@"tasks"] where:@"is_completed" value:@0]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setStatus:@"No pending tasks" isError:NO]; return; }
        [self setStatus:[NSString stringWithFormat:
            @"where(is_completed, 0) — %lu task(s)", (unsigned long)rows.count] isError:NO];
        [self showMaps:rows];
    }];
}

- (void)demoWhereIn {
    [self startAction:@"whereIn…"];
    [[[[AppAmbitDb from:@"tasks"]
       whereIn:@"priority" values:@[@"high", @"medium"]]
      orderBy:@"due_date"]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setStatus:@"No high/medium tasks" isError:NO]; return; }
        [self setStatus:[NSString stringWithFormat:
            @"whereIn(priority, [high, medium]) — %lu row(s)", (unsigned long)rows.count] isError:NO];
        [self showMaps:rows];
    }];
}

- (void)demoOffset {
    [self startAction:@"limit+offset…"];
    [[[[AppAmbitDb from:@"tasks"]
       orderBy:@"due_date"]
      limit:5]
     getWithCompletion:^(NSArray<NSDictionary *> *rows, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (rows.count == 0) { [self setStatus:@"No tasks found" isError:NO]; return; }
        [self setStatus:[NSString stringWithFormat:
            @"limit(5).offset(0) — page 1, %lu row(s)", (unsigned long)rows.count] isError:NO];
        [self showMaps:rows];
    }];
}

- (void)demoFirst {
    [self startAction:@"first()…"];
    [[[[AppAmbitDb from:@"tasks"]
       where:@"is_completed" op:@"=" value:@0]
      orderBy:@"due_date"]
     firstWithCompletion:^(NSDictionary *row, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        if (!row) { [self setStatus:@"first() — no pending tasks" isError:NO]; return; }
        [self setStatus:@"first() — next task by due date" isError:NO];
        [self showMaps:@[row]];
    }];
}

- (void)demoCount {
    [self startAction:@"count()…"];
    [[[AppAmbitDb from:@"tasks"]
      where:@"is_completed" value:@0]
     countWithCompletion:^(NSInteger count, NSError *error) {
        if (error) { [self setError:error.localizedDescription]; return; }
        [self setStatus:[NSString stringWithFormat:
            @"count() — %ld pending task(s)", (long)count] isError:NO];
        [self buildResultTable:@[@"pending_tasks"] rows:@[@[@(count)]]];
    }];
}

// MARK: - Fluent WRITE

- (void)demoInsert {
    [self startAction:@"insert()…"];
    [[AppAmbitDb from:@"tasks"]
     insert:@{
         @"title": @"New task",
         @"is_completed": @0,
         @"priority": @"medium",
         @"due_date": @"2026-06-10"
     }
     completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"insert()"];
    }];
}

- (void)demoInsertHigh {
    [self startAction:@"insert() high priority…"];
    [[AppAmbitDb from:@"tasks"]
     insert:@{
         @"title": @"Fix critical bug",
         @"is_completed": @0,
         @"priority": @"high",
         @"due_date": @"2026-06-05"
     }
     completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"insert() high priority"];
    }];
}

- (void)demoInsertRawSQL {
    [self startAction:@"execute() INSERT…"];
    [AppAmbitDb execute:@"INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)"
                 params:@[@"Raw SQL insert", @0, @"medium", @"2026-06-12"]
             completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"execute() INSERT"];
    }];
}

- (void)demoInsertMany {
    [self startAction:@"insert many (batch 5 rows)…"];
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
        [self setStatus:[NSString stringWithFormat:
            @"insert many — %ld rows inserted via batch", (long)written] isError:NO];
    }];
}

- (void)demoUpdate {
    [self startAction:@"update()…"];
    [[[AppAmbitDb from:@"tasks"]
      where:@"title" value:@"New task"]
     update:@{@"is_completed": @1}
     completion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"update()"];
    }];
}

- (void)demoDelete {
    [self startAction:@"delete()…"];
    [[[AppAmbitDb from:@"tasks"]
      where:@"is_completed" value:@1]
     deleteWithCompletion:^(DbResult *result, NSError *error) {
        [self writeResult:result error:error label:@"delete()"];
    }];
}

// MARK: - Typed Model

- (void)demoTypedModel {
    [self startAction:@"typed mapping…"];
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
        [self setStatus:[NSString stringWithFormat:
            @"from(\"tasks\") typed mapping — %lu row(s)", (unsigned long)maps.count] isError:NO];
        [self buildResultTable:cols rows:rows];
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
            self.resultContainer.hidden = YES;
            return;
        }

        // Header row
        UIStackView *header = [self makeRow:columns isHeader:YES];
        [self.resultGrid addArrangedSubview:header];
        [self.resultGrid addArrangedSubview:[self separatorView]];

        // Data rows
        for (NSUInteger ri = 0; ri < rows.count; ri++) {
            NSArray *row = rows[ri];
            NSMutableArray<NSString *> *cellVals = [NSMutableArray array];
            for (NSUInteger ci = 0; ci < columns.count; ci++) {
                id val = ci < row.count ? row[ci] : [NSNull null];
                [cellVals addObject:[val isKindOfClass:[NSNull class]] ? @"null"
                    : [NSString stringWithFormat:@"%@", val]];
            }
            UIColor *bg = (ri % 2 == 0)
                ? UIColor.secondarySystemGroupedBackgroundColor
                : UIColor.systemGroupedBackgroundColor;
            UIStackView *rowView = [self makeRow:cellVals isHeader:NO];
            for (UIView *cell in rowView.arrangedSubviews) cell.backgroundColor = bg;
            [self.resultGrid addArrangedSubview:rowView];
            if (ri < rows.count - 1) {
                [self.resultGrid addArrangedSubview:[self separatorView]];
            }
        }

        self.resultContainer.hidden = NO;
    });
}

// Each row is a horizontal UIStackView with fillEqually distribution.
// spacing=0.5 + backgroundColor=separatorColor produces thin column dividers
// without requiring explicit separator subviews (which would break fillEqually).
- (UIStackView *)makeRow:(NSArray<NSString *> *)values isHeader:(BOOL)isHeader {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 0.5;
    row.backgroundColor = UIColor.separatorColor;

    UIColor *headerBg = [UIColor colorWithWhite:0 alpha:0.06];

    for (NSString *value in values) {
        UILabel *lbl = [[UILabel alloc] init];
        lbl.text = value;
        lbl.font = isHeader
            ? [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold]
            : [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        lbl.textColor = isHeader ? UIColor.labelColor : UIColor.secondaryLabelColor;
        lbl.numberOfLines = 1;
        lbl.lineBreakMode = NSLineBreakByTruncatingTail;

        UIView *cell = [[UIView alloc] init];
        if (isHeader) cell.backgroundColor = headerBg;
        [cell addSubview:lbl];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [lbl.topAnchor constraintEqualToAnchor:cell.topAnchor constant:6],
            [lbl.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8],
            [lbl.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4],
            [lbl.bottomAnchor constraintEqualToAnchor:cell.bottomAnchor constant:-6],
        ]];
        [row addArrangedSubview:cell];
    }

    return row;
}

- (UIView *)separatorView {
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = UIColor.separatorColor;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [sep.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return sep;
}

// MARK: - Helpers

- (void)showResult:(DbResult *)result label:(NSString *)label {
    [self setStatus:[NSString stringWithFormat:
        @"%@ — %lu row(s)  rows_read=%ld  rows_written=%ld",
        label, (unsigned long)result.rows.count, (long)result.rowsRead, (long)result.rowsWritten]
            isError:NO];
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
    if (error) { [self setError:error.localizedDescription]; return; }
    if (!result) { [self setStatus:[NSString stringWithFormat:@"%@: no result", label] isError:NO]; return; }
    if (result.hasError) { [self setError:result.error ?: @"DB error"]; return; }
    [self setStatus:[NSString stringWithFormat:
        @"%@ OK — rows_read=%ld  rows_written=%ld",
        label, (long)result.rowsRead, (long)result.rowsWritten] isError:NO];
}

- (void)startAction:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in self.resultGrid.arrangedSubviews) {
            [self.resultGrid removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        self.resultContainer.hidden = YES;
        self.statusLabel.text = msg;
        self.statusLabel.textColor = UIColor.secondaryLabelColor;
    });
}

- (void)setStatus:(NSString *)text isError:(BOOL)isError {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = text;
        self.statusLabel.textColor = isError ? UIColor.systemRedColor : UIColor.secondaryLabelColor;
    });
}

- (void)setError:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in self.resultGrid.arrangedSubviews) {
            [self.resultGrid removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        self.resultContainer.hidden = YES;
        self.statusLabel.text = [NSString stringWithFormat:@"ERROR: %@", msg];
        self.statusLabel.textColor = UIColor.systemRedColor;
    });
}

// MARK: - UI builders

- (void)addSectionHeader:(NSString *)title {
    UILabel *header = [[UILabel alloc] init];
    header.text = [title uppercaseString];
    header.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    header.textColor = UIColor.secondaryLabelColor;
    UIView *wrapper = [[UIView alloc] init];
    [wrapper addSubview:header];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:8],
        [header.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [header.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-2],
    ]];
    [self.stackView addArrangedSubview:wrapper];
}

- (void)addButton:(NSString *)title selector:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    btn.layer.cornerRadius = 8;
    btn.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
    btn.titleLabel.font = [UIFont systemFontOfSize:14];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:btn];
}

- (UIView *)wrapWithPadding:(UIView *)inner {
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
