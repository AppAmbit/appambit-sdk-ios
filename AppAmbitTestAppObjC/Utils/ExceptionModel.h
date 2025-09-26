#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExceptionModel : NSObject

@property (nonatomic, copy)   NSString *type;
@property (nonatomic, copy)   NSString *sessionId;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy)   NSString *stackTrace;
@property (nonatomic, copy, nullable) NSString *source;
@property (nonatomic, copy, nullable) NSString *innerException;
@property (nonatomic, copy)   NSString *fileNameFromStackTrace;
@property (nonatomic, copy)   NSString *classFullName;
@property (nonatomic, assign) long long lineNumberFromStackTrace;
@property (nonatomic, copy, nullable) NSString *crashLogFile;
@property (nonatomic, strong) NSDate *createdAt;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

- (NSDictionary *)toDictionary;

+ (instancetype)fromError:(NSError *)error
                sessionId:(NSString *)sessionId
                 deviceId:(NSString *_Nullable)deviceId
                      now:(NSDate *)now;

+ (NSString *)generateCrashLogWithException:(NSException *_Nullable)exception
                                 stackTrace:(NSString *_Nullable)stackTrace
                                      error:(NSError *_Nullable)error
                                   deviceId:(NSString *_Nullable)deviceId
                                        now:(NSDate *)now;

@end

NS_ASSUME_NONNULL_END
