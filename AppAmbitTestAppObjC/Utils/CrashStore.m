// Utilities/CrashStore.m
#import "CrashStore.h"
#import "ExceptionModel.h"

@implementation CrashStore

#pragma mark - Private

+ (NSURL * _Nullable)_crashLogsDirectory:(NSError * _Nullable * _Nullable)error {
    NSURL *base = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                         inDomains:NSUserDomainMask] firstObject];
    if (!base) {
        if (error) {
            *error = [NSError errorWithDomain:@"CrashStore"
                                         code:CrashStoreErrorAppSupportNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application Support not found"}];
        }
        return nil;
    }
    return [base URLByAppendingPathComponent:@"CrashLogs"];
}

+ (NSArray<NSURL *> *)_jsonFilesInDirectory:(NSURL *)dir {
    NSError *listErr = nil;
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
                              contentsOfDirectoryAtURL:dir
                              includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                              options:NSDirectoryEnumerationSkipsHiddenFiles
                              error:&listErr] ?: @[];

    NSMutableArray<NSURL *> *jsons = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSURL *u in urls) {
        if ([[u.pathExtension lowercaseString] isEqualToString:@"json"]) {
            [jsons addObject:u];
        }
    }
    return jsons;
}

#pragma mark - Public

+ (NSArray<ExceptionModel *> *)loadAll:(NSError * _Nullable * _Nullable)error {
    NSError *dirErr = nil;
    NSURL *dir = [self _crashLogsDirectory:&dirErr];
    if (!dir) { if (error) *error = dirErr; return @[]; }

    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir.path isDirectory:&isDir] || !isDir) {
        if (error) {
            *error = [NSError errorWithDomain:@"CrashStore"
                                         code:CrashStoreErrorDirectoryMissing
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Directory missing: %@", dir.path]}];
        }
        return @[];
    }

    NSArray<NSURL *> *files = [self _jsonFilesInDirectory:dir];
    NSMutableArray<ExceptionModel *> *items = [NSMutableArray arrayWithCapacity:files.count];

    for (NSURL *url in files) {
        @autoreleasepool {
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (!data) { NSLog(@"[CrashStore] skip %@ (no data)", url.lastPathComponent); continue; }

            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) {
                NSLog(@"[CrashStore] skip %@ (invalid json)", url.lastPathComponent);
                continue;
            }

            ExceptionModel *m = [[ExceptionModel alloc] initWithDictionary:(NSDictionary *)json];
            if (m) [items addObject:m];
        }
    }

    // Ordenar por createdAt DESC (recientes primero)
    [items sortUsingComparator:^NSComparisonResult(ExceptionModel * _Nonnull a, ExceptionModel * _Nonnull b) {
        NSDate *da = a.createdAt ?: [NSDate distantPast];
        NSDate *db = b.createdAt ?: [NSDate distantPast];
        return [db compare:da];
    }];

    return items;
}

+ (NSArray<ExceptionModel *> *)loadRangeFrom:(NSDate * _Nullable)from
                                          to:(NSDate * _Nullable)to
                                       error:(NSError * _Nullable * _Nullable)error
{
    NSArray<ExceptionModel *> *all = [self loadAll:error];
    if (all.count == 0) return all;

    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(ExceptionModel *obj, NSDictionary *bindings) {
        NSDate *d = obj.createdAt ?: [NSDate distantPast];
        if (from && [d compare:from] == NSOrderedAscending) return NO;
        if (to && [d compare:to] == NSOrderedDescending) return NO;
        return YES;
    }];
    return [all filteredArrayUsingPredicate:p];
}

+ (ExceptionModel * _Nullable)loadLatest:(NSError * _Nullable * _Nullable)error {
    return [[self loadAll:error] firstObject];
}

+ (NSArray<ExceptionModel *> *)loadLatestWithLimit:(NSInteger)limit
                                             error:(NSError * _Nullable * _Nullable)error
{
    NSArray *all = [self loadAll:error];
    if (limit <= 0 || limit >= (NSInteger)all.count) return all;
    return [all subarrayWithRange:NSMakeRange(0, (NSUInteger)limit)];
}

+ (ExceptionModel * _Nullable)loadByFilename:(NSString *)filename
                                       error:(NSError * _Nullable * _Nullable)error
{
    NSError *dirErr = nil;
    NSURL *dir = [self _crashLogsDirectory:&dirErr];
    if (!dir) { if (error) *error = dirErr; return nil; }

    NSURL *url = [dir URLByAppendingPathComponent:filename];
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:url.path];
    if (!exists) return nil;

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return nil;

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) return nil;

    return [[ExceptionModel alloc] initWithDictionary:(NSDictionary *)json];
}

@end
