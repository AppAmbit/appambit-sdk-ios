#import "StorableApp.h"
#import <sqlite3.h>
#import <unistd.h> // usleep

#define SA_SQLITE_TRANSIENT ((sqlite3_destructor_type)-1)

@interface StorableApp () {
    sqlite3 *_db;
    dispatch_queue_t _queue;
    int _maxAttempts;
    int _baseDelayMs;
    int _maxDelayMs;
}
@end

@implementation StorableApp

#pragma mark - Singleton

+ (instancetype)shared {
    static StorableApp *S;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        S = [[StorableApp alloc] initPrivate];
    });
    return S;
}

- (instancetype)initPrivate {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.appambit.sqlite", DISPATCH_QUEUE_SERIAL);
        _maxAttempts = 12;
        _baseDelayMs = 20;
        _maxDelayMs = 1200;

        NSError *err = nil;
        if (![self openDB:&err]) {
            NSLog(@"[StorableApp] Failed to initialize Storable: %@", err.localizedDescription);
        }
    }
    return self;
}

- (instancetype)init {
    [NSException raise:@"Use shared" format:@"Use [StorableApp shared]"];
    return nil;
}

#pragma mark - Open/Close

- (BOOL)openDB:(NSError **)error {
    __block BOOL ok = YES;
    __block NSError *localErr = nil;

    dispatch_sync(_queue, ^{
        if (_db) { ok = YES; return; }

        NSURL *appSup = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                inDomains:NSUserDomainMask] firstObject];
        if (!appSup) {
            localErr = [NSError errorWithDomain:@"DataStore" code:1
                                       userInfo:@{NSLocalizedDescriptionKey:@"Application Support not found"}];
            ok = NO; return;
        }
        NSURL *url = [appSup URLByAppendingPathComponent:@"AppAmbit.sqlite"];

        int flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX;
        sqlite3 *tmp = NULL;
        int rc = sqlite3_open_v2(url.path.UTF8String, &tmp, flags, NULL);
        if (rc != SQLITE_OK || !tmp) {
            localErr = [NSError errorWithDomain:@"DataStore" code:rc
                                       userInfo:@{NSLocalizedDescriptionKey:@"Unable to open database"}];
            ok = NO; return;
        }
        _db = tmp;

        [self exec:@"PRAGMA journal_mode=WAL;" error:nil];
        [self exec:@"PRAGMA synchronous=NORMAL;" error:nil];
        [self exec:@"PRAGMA foreign_keys=ON;" error:nil];

        sqlite3_busy_timeout(_db, 15000);

        [self exec:@"PRAGMA read_uncommitted=1;" error:nil];
        [self exec:@"PRAGMA wal_autocheckpoint=1000;" error:nil];
    });

    if (error) *error = localErr;
    return ok;
}

- (void)close {
    dispatch_sync(_queue, ^{
        if (_db) { sqlite3_close_v2(_db); _db = NULL; }
    });
}

#pragma mark - Helpers base

- (NSError *)sqliteError {
    const char *msg = sqlite3_errmsg(_db);
    NSString *s = msg ? [NSString stringWithUTF8String:msg] : @"unknown";
    return [NSError errorWithDomain:@"SQLite3" code:1 userInfo:@{NSLocalizedDescriptionKey:s}];
}

- (void)sleepWithBackoffAttempt:(int)attempt {
    int powFactor = MIN(attempt, 7);
    int delayMs = MIN(_maxDelayMs, _baseDelayMs * (1 << powFactor));
    int jitter = arc4random_uniform(2501); // 0..2500
    useconds_t us = (useconds_t)((delayMs * 1000) + jitter);
    usleep(us);
}

- (BOOL)execRetry:(NSString *)sql error:(NSError **)error {
    __block BOOL ok = NO;
    __block NSError *local = nil;

    dispatch_sync(_queue, ^{
        const char *csql = [sql UTF8String];
        char *errmsg = NULL;
        NSString *lastErr = @"unknown";

        for (int attempt=0; attempt<_maxAttempts; attempt++) {
            int rc = sqlite3_exec(_db, csql, NULL, NULL, &errmsg);
            if (rc == SQLITE_OK) { ok = YES; break; }

            if (rc == SQLITE_BUSY || rc == SQLITE_LOCKED) {
                if (errmsg) { lastErr = [NSString stringWithUTF8String:errmsg]; sqlite3_free(errmsg); errmsg = NULL; }
                [self sleepWithBackoffAttempt:attempt];
                continue;
            }
            lastErr = errmsg ? [NSString stringWithUTF8String:errmsg] : @"unknown";
            if (errmsg) { sqlite3_free(errmsg); errmsg = NULL; }
            local = [NSError errorWithDomain:@"SQLite3" code:rc userInfo:@{NSLocalizedDescriptionKey:lastErr}];
            break;
        }

        if (!ok && !local) {
            local = [NSError errorWithDomain:@"SQLite3" code:SQLITE_BUSY
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"execRetry exhausted attempts for: %@ (last: %@)", sql, lastErr]}];
        }
    });

    if (error) *error = local;
    return ok;
}

- (BOOL)exec:(NSString *)sql error:(NSError **)error {
    __block BOOL ok = NO;
    __block NSError *local = nil;

    dispatch_sync(_queue, ^{
        char *errmsg = NULL;
        int rc = sqlite3_exec(_db, sql.UTF8String, NULL, NULL, &errmsg);
        if (rc == SQLITE_OK) { ok = YES; }
        else {
            NSString *msg = errmsg ? [NSString stringWithUTF8String:errmsg] : @"unknown";
            if (errmsg) sqlite3_free(errmsg);
            local = [NSError errorWithDomain:@"SQLite3" code:rc userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
    });

    if (error) *error = local;
    return ok;
}

- (NSString *)isoStringFromDate:(NSDate *)date {
    static NSDateFormatter *fmt;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [NSDateFormatter new];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return [fmt stringFromDate:date];
}

- (void)bindText:(sqlite3_stmt *)stmt index:(int)index value:(NSString * _Nullable)value {
    if (value) sqlite3_bind_text(stmt, index, value.UTF8String, -1, SA_SQLITE_TRANSIENT);
    else sqlite3_bind_null(stmt, index);
}

- (void)bindBlob:(sqlite3_stmt *)stmt index:(int)index value:(NSData * _Nullable)value {
    if (value) {
        sqlite3_bind_blob(stmt, index, value.bytes, (int)value.length, SA_SQLITE_TRANSIENT);
    } else {
        sqlite3_bind_null(stmt, index);
    }
}

- (BOOL)inTransaction:(BOOL (^)(NSError **innerErr))body error:(NSError **)error {
    if (![self execRetry:@"BEGIN IMMEDIATE;" error:error]) return NO;

    NSError *inner = nil;
    BOOL ok = body(&inner);

    if (ok) {
        if (![self execRetry:@"COMMIT;" error:error]) return NO;
    } else {
        [self execRetry:@"ROLLBACK;" error:nil];
        if (error) *error = inner ?: [self sqliteError];
        return NO;
    }
    return YES;
}

#pragma mark - API públicas (equivalentes a Swift)

- (BOOL)putSessionDataWithTimestamp:(NSDate *)timestamp
                        sessionType:(NSString *)sessionType
                              error:(NSError * _Nullable * _Nullable)error
{
    __block BOOL ok = NO;
    __block NSError *local = nil;

    dispatch_sync(_queue, ^{
        ok = [self inTransaction:^BOOL(NSError *__autoreleasing  _Nullable * _Nonnull innerErr) {

            if ([sessionType isEqualToString:@"start"]) {
                const char *selectOpenSQL =
                "SELECT id FROM sessions WHERE endedAt IS NULL ORDER BY startedAt DESC LIMIT 1;";
                sqlite3_stmt *sel = NULL;
                if (sqlite3_prepare_v2(_db, selectOpenSQL, -1, &sel, NULL) != SQLITE_OK) {
                    *innerErr = [self sqliteError]; return NO;
                }
                NSString *openId = nil;
                if (sqlite3_step(sel) == SQLITE_ROW) {
                    const unsigned char *c = sqlite3_column_text(sel, 0);
                    if (c) openId = [NSString stringWithUTF8String:(const char *)c];
                }
                sqlite3_finalize(sel);

                if (openId) {
                    const char *closeSQL = "UPDATE sessions SET endedAt = ? WHERE id = ?;";
                    sqlite3_stmt *upd = NULL;
                    if (sqlite3_prepare_v2(_db, closeSQL, -1, &upd, NULL) != SQLITE_OK) {
                        *innerErr = [self sqliteError]; return NO;
                    }
                    [self bindText:upd index:1 value:[self isoStringFromDate:timestamp]];
                    [self bindText:upd index:2 value:openId];
                    if (sqlite3_step(upd) != SQLITE_DONE) { sqlite3_finalize(upd); *innerErr = [self sqliteError]; return NO; }
                    sqlite3_finalize(upd);
                }

                const char *insertStartSQL =
                "INSERT INTO sessions (id, sessionId, startedAt, endedAt) VALUES (?, ?, ?, ?);";
                sqlite3_stmt *ins = NULL;
                if (sqlite3_prepare_v2(_db, insertStartSQL, -1, &ins, NULL) != SQLITE_OK) {
                    *innerErr = [self sqliteError]; return NO;
                }
                [self bindText:ins index:1 value:[[NSUUID UUID] UUIDString]];
                [self bindText:ins index:2 value:nil];
                [self bindText:ins index:3 value:[self isoStringFromDate:timestamp]];
                [self bindText:ins index:4 value:nil];
                if (sqlite3_step(ins) != SQLITE_DONE) { sqlite3_finalize(ins); *innerErr = [self sqliteError]; return NO; }
                sqlite3_finalize(ins);
                return YES;
            }

            if ([sessionType isEqualToString:@"end"]) {
                const char *selectSQL =
                "SELECT id FROM sessions WHERE endedAt IS NULL ORDER BY startedAt DESC LIMIT 1;";
                sqlite3_stmt *sel = NULL;
                if (sqlite3_prepare_v2(_db, selectSQL, -1, &sel, NULL) != SQLITE_OK) {
                    *innerErr = [self sqliteError]; return NO;
                }
                NSString *openId = nil;
                if (sqlite3_step(sel) == SQLITE_ROW) {
                    const unsigned char *c = sqlite3_column_text(sel, 0);
                    if (c) openId = [NSString stringWithUTF8String:(const char *)c];
                }
                sqlite3_finalize(sel);

                if (openId) {
                    const char *updateSQL = "UPDATE sessions SET endedAt = ? WHERE id = ?;";
                    sqlite3_stmt *upd = NULL;
                    if (sqlite3_prepare_v2(_db, updateSQL, -1, &upd, NULL) != SQLITE_OK) {
                        *innerErr = [self sqliteError]; return NO;
                    }
                    [self bindText:upd index:1 value:[self isoStringFromDate:timestamp]];
                    [self bindText:upd index:2 value:openId];
                    if (sqlite3_step(upd) != SQLITE_DONE) { sqlite3_finalize(upd); *innerErr = [self sqliteError]; return NO; }
                    sqlite3_finalize(upd);
                } else {
                    const char *insertSQL =
                    "INSERT INTO sessions (id, sessionId, startedAt, endedAt) VALUES (?, ?, ?, ?);";
                    sqlite3_stmt *ins = NULL;
                    if (sqlite3_prepare_v2(_db, insertSQL, -1, &ins, NULL) != SQLITE_OK) {
                        *innerErr = [self sqliteError]; return NO;
                    }
                    [self bindText:ins index:1 value:[[NSUUID UUID] UUIDString]];
                    [self bindText:ins index:2 value:nil];
                    [self bindText:ins index:3 value:nil];
                    [self bindText:ins index:4 value:[self isoStringFromDate:timestamp]];
                    if (sqlite3_step(ins) != SQLITE_DONE) { sqlite3_finalize(ins); *innerErr = [self sqliteError]; return NO; }
                    sqlite3_finalize(ins);
                }
                return YES;
            }

            NSLog(@"The session type does not exist");
            return YES;
        } error:&local];
    });

    if (error) *error = local;
    return ok;
}

- (BOOL)updateLogsWithCurrentSessionId:(NSError * _Nullable * _Nullable)error {
    __block BOOL ok = NO;
    __block NSError *local = nil;

    dispatch_sync(_queue, ^{
        ok = [self inTransaction:^BOOL(NSError *__autoreleasing  _Nullable * _Nonnull innerErr) {
            const char *selectSQL =
            "SELECT id FROM sessions WHERE endedAt IS NULL ORDER BY startedAt DESC LIMIT 1;";
            sqlite3_stmt *sel = NULL;
            if (sqlite3_prepare_v2(_db, selectSQL, -1, &sel, NULL) != SQLITE_OK) {
                *innerErr = [self sqliteError]; return NO;
            }
            NSString *sessionId = nil;
            if (sqlite3_step(sel) == SQLITE_ROW) {
                const unsigned char *c = sqlite3_column_text(sel, 0);
                if (c) sessionId = [NSString stringWithUTF8String:(const char *)c];
            }
            sqlite3_finalize(sel);

            if (!sessionId) {
                NSLog(@"No open session found, logs not updated");
                return YES;
            }

            const char *upd1 =
            "UPDATE logs SET sessionId = ? WHERE _rowid_ = (SELECT _rowid_ FROM logs ORDER BY _rowid_ DESC LIMIT 1);";
            sqlite3_stmt *s1 = NULL;
            if (sqlite3_prepare_v2(_db, upd1, -1, &s1, NULL) != SQLITE_OK) {
                *innerErr = [self sqliteError]; return NO;
            }
            [self bindText:s1 index:1 value:sessionId];
            if (sqlite3_step(s1) != SQLITE_DONE) { sqlite3_finalize(s1); *innerErr = [self sqliteError]; return NO; }
            sqlite3_finalize(s1);

            if (sqlite3_changes(_db) == 1) {
                return YES;
            }

            const char *upd2 =
            "UPDATE logs SET sessionId = ? WHERE id = (SELECT id FROM logs ORDER BY id DESC LIMIT 1);";
            sqlite3_stmt *s2 = NULL;
            if (sqlite3_prepare_v2(_db, upd2, -1, &s2, NULL) != SQLITE_OK) {
                *innerErr = [self sqliteError]; return NO;
            }
            [self bindText:s2 index:1 value:sessionId];
            if (sqlite3_step(s2) != SQLITE_DONE) { sqlite3_finalize(s2); *innerErr = [self sqliteError]; return NO; }
            sqlite3_finalize(s2);

            if (sqlite3_changes(_db) == 0) {
                NSLog(@"No logs to update (table empty?)");
            }
            return YES;
        } error:&local];
    });

    if (error) *error = local;
    return ok;
}

- (NSString * _Nullable)getCurrentOpenSessionId:(NSError * _Nullable * _Nullable)error {
    __block NSString *result = nil;
    __block NSError *local = nil;

    dispatch_sync(_queue, ^{
        const char *sql =
        "SELECT id FROM sessions WHERE endedAt IS NULL ORDER BY startedAt DESC LIMIT 1;";
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) {
            local = [self sqliteError]; return;
        }
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            const unsigned char *c = sqlite3_column_text(stmt, 0);
            if (c) result = [NSString stringWithUTF8String:(const char *)c];
        }
        sqlite3_finalize(stmt);
    });

    if (error) *error = local;
    return result;
}

@end
