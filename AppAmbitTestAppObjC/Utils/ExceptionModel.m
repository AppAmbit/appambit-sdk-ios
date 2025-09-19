#import "ExceptionModel.h"
#include <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExceptionModel (Private)
+ (NSString *)_appInfoHeaderWithDeviceId:(NSString *_Nullable)deviceId now:(NSDate *)now;
+ (void)_appendSymbolsTo:(NSMutableString *)log;
+ (NSString *_Nullable)_sysctlStringForName:(const char *)name;
+ (void)_parseStackTrace:(NSArray<NSString *> *)symbols
                fileName:(NSString * _Nonnull * _Nonnull)fileNameOut
              className:(NSString * _Nonnull * _Nonnull)classNameOut
                   line:(long long *)lineOut;
@end

@implementation ExceptionModel

- (instancetype)init {
    if ((self = [super init])) {
        _type = @"Unknown";
        _sessionId = @"";
        _message = nil;
        _stackTrace = @"";
        _source = nil;
        _innerException = nil;
        _fileNameFromStackTrace = @"UnknownFile";
        _classFullName = @"UnknownClass";
        _lineNumberFromStackTrace = 0;
        _crashLogFile = nil;
        _createdAt = [NSDate date];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if ((self = [self init])) {
        _type = [[dict objectForKey:@"Type"] ?: @"Unknown" copy];
        _sessionId = [[dict objectForKey:@"SessionId"] ?: @"" copy];

        id msg = dict[@"Message"];
        _message = ([msg isKindOfClass:[NSNull class]] ? nil : [msg copy]);

        _stackTrace = [[dict objectForKey:@"StackTrace"] ?: @"" copy];

        id src = dict[@"Source"];
        _source = ([src isKindOfClass:[NSNull class]] ? nil : [src copy]);

        id inner = dict[@"InnerException"];
        _innerException = ([inner isKindOfClass:[NSNull class]] ? nil : [inner copy]);

        _fileNameFromStackTrace = [[dict objectForKey:@"FileNameFromStackTrace"] ?: @"UnknownFile" copy];
        _classFullName = [[dict objectForKey:@"ClassFullName"] ?: @"UnknownClass" copy];

        NSNumber *line = dict[@"LineNumberFromStackTrace"];
        _lineNumberFromStackTrace = line ? line.longLongValue : 0;

        id crashFile = dict[@"CrashLogFile"];
        _crashLogFile = ([crashFile isKindOfClass:[NSNull class]] ? nil : [crashFile copy]);

        id created = dict[@"CreatedAt"];
        if ([created isKindOfClass:[NSString class]]) {
            NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
            iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
            NSDate *d = [iso dateFromString:(NSString *)created];
            _createdAt = d ?: [NSDate date];
        } else if ([created isKindOfClass:[NSDate class]]) {
            _createdAt = created;
        } else {
            _createdAt = [NSDate date];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSString *created = [iso stringFromDate:self.createdAt];

    NSMutableDictionary *d = [@{
        @"Type": self.type ?: @"Unknown",
        @"SessionId": self.sessionId ?: @"",
        @"Message": self.message ?: [NSNull null],
        @"StackTrace": self.stackTrace ?: @"",
        @"Source": self.source ?: [NSNull null],
        @"InnerException": self.innerException ?: [NSNull null],
        @"FileNameFromStackTrace": self.fileNameFromStackTrace ?: @"UnknownFile",
        @"ClassFullName": self.classFullName ?: @"UnknownClass",
        @"LineNumberFromStackTrace": @(self.lineNumberFromStackTrace),
        @"CreatedAt": created ?: @""
    } mutableCopy];

    if (self.crashLogFile) d[@"CrashLogFile"] = self.crashLogFile;
    return d;
}

+ (instancetype)fromError:(NSError *)error
                sessionId:(NSString *)sessionId
                 deviceId:(NSString *_Nullable)deviceId
                      now:(NSDate *)now
{
    NSArray<NSString *> *symbols = [NSThread callStackSymbols];
    NSString *backtrace = [symbols componentsJoinedByString:@"\n"];

    NSString *fileName = @"UnknownFile";
    NSString *className = @"UnknownClass";
    long long line = 0;
    [self _parseStackTrace:symbols fileName:&fileName className:&className line:&line];

    NSString *inner = nil;
    NSError *under = error.userInfo[NSUnderlyingErrorKey];
    if (under) inner = under.description;

    NSString *source = nil;
    if (symbols.firstObject) {
        NSArray *parts = [symbols.firstObject componentsSeparatedByString:@" "];
        if (parts.count > 1) source = parts[1];
    }

    ExceptionModel *m = [ExceptionModel new];
    m.type = error.domain ?: @"Unknown";
    m.sessionId = sessionId ?: @"";
    m.message = error.localizedDescription;
    m.stackTrace = backtrace ?: @"";
    m.source = source;
    m.innerException = inner;
    m.fileNameFromStackTrace = fileName;
    m.classFullName = className;
    m.lineNumberFromStackTrace = line;
    m.crashLogFile = [self generateCrashLogWithException:nil
                                              stackTrace:backtrace
                                                   error:error
                                                deviceId:deviceId
                                                     now:now];
    m.createdAt = now ?: [NSDate date];
    return m;
}

+ (NSString *)generateCrashLogWithException:(NSException *_Nullable)exception
                                 stackTrace:(NSString *_Nullable)stackTrace
                                      error:(NSError *_Nullable)error
                                   deviceId:(NSString *_Nullable)deviceId
                                        now:(NSDate *)now
{
    NSMutableString *log = [NSMutableString new];
    [log appendString:[self _appInfoHeaderWithDeviceId:deviceId now:now]];
    [log appendString:@"\n"];
    [log appendString:@"iOS Exception Stack:\n"];

    if (exception) {
        [log appendString:[[exception callStackSymbols] componentsJoinedByString:@"\n"]];
    }
    if (stackTrace.length > 0) {
        [log appendFormat:@"\n%@\n", stackTrace];
    }
    if (error) {
        NSArray<NSString *> *sym = [NSThread callStackSymbols];
        [log appendFormat:@"\n%@\n", [sym componentsJoinedByString:@"\n"]];
    }

    [log appendString:@"\n\n"];
    [self _appendSymbolsTo:log];
    return log;
}

#pragma mark - Private helpers

+ (NSString *)_appInfoHeaderWithDeviceId:(NSString *_Nullable)deviceId now:(NSDate *)now {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary] ?: @{};
    NSString *build = info[@"CFBundleVersion"] ?: @"Unknown";
    NSString *appVersion = info[@"CFBundleShortVersionString"] ?: @"Unknown";

    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *os = [NSString stringWithFormat:@"iOS %ld.%ld.%ld",
                    (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];

    NSString *deviceModel = [self _sysctlStringForName:"hw.machine"] ?: @"Unknown";

    NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSString *dateStr = [iso stringFromDate:now];

    NSMutableString *s = [NSMutableString new];
    [s appendFormat:@"Package: %@\n", bundleId];
    [s appendFormat:@"Version Code: %@\n", build];
    [s appendFormat:@"Version Name: %@\n", appVersion];
    [s appendString:@"Manufacturer: Apple\n"];
    [s appendFormat:@"iOS: %@\n", os];
    [s appendFormat:@"Model: %@\n", deviceModel];
    [s appendFormat:@"Device Id: %@\n", deviceId ?: @"Unknown"];
    [s appendFormat:@"Date: %@\n", dateStr];
    return s;
}

+ (NSString *_Nullable)_sysctlStringForName:(const char *)name {
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0) return nil;
    char *value = malloc(size);
    if (!value) return nil;
    if (sysctlbyname(name, value, &size, NULL, 0) != 0) { free(value); return nil; }
    NSString *out = [NSString stringWithUTF8String:value];
    free(value);
    return out;
}

+ (void)_appendSymbolsTo:(NSMutableString *)log {
    NSArray<NSString *> *symbols = [NSThread callStackSymbols];
    [symbols enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [log appendFormat:@"Thread %lu:\n", (unsigned long)idx];
        [log appendFormat:@"  %@\n\n", obj];
    }];
}

+ (void)_parseStackTrace:(NSArray<NSString *> *)symbols
                fileName:(NSString * _Nonnull * _Nonnull)fileNameOut
              className:(NSString * _Nonnull * _Nonnull)classNameOut
                   line:(long long *)lineOut
{
    NSString *file = @"UnknownFile";
    NSString *klass = @"UnknownClass";
    long long line = 0;

    for (NSString *symbol in symbols) {
        NSRange r = [symbol rangeOfString:@".swift:"];
        if (r.location != NSNotFound) {
            // Busca el último "/" antes de ".swift:"
            NSRange before = NSMakeRange(0, r.location);
            NSRange slash = [symbol rangeOfString:@"/" options:NSBackwardsSearch range:before];
            if (slash.location != NSNotFound) {
                NSUInteger start = slash.location + 1;
                NSUInteger len = (r.location + r.length) - start;
                if (start + len <= symbol.length) {
                    file = [symbol substringWithRange:NSMakeRange(start, len)];
                    klass = [file stringByReplacingOccurrencesOfString:@".swift" withString:@""];
                    NSString *after = [symbol substringFromIndex:(r.location + r.length)];
                    NSScanner *scanner = [NSScanner scannerWithString:after];
                    long long tmp = 0;
                    if ([scanner scanLongLong:&tmp]) line = tmp;
                }
            }
            break;
        }
    }

    *fileNameOut = file;
    *classNameOut = klass;
    *lineOut = line;
}

@end

NS_ASSUME_NONNULL_END
