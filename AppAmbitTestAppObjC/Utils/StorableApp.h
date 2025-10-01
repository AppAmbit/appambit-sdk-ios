#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StorableApp : NSObject

+ (instancetype)shared;

- (void)close;

- (BOOL)putSessionDataWithTimestamp:(NSDate *)timestamp
                        sessionType:(NSString *)sessionType
                              error:(NSError * _Nullable * _Nullable)error;

- (BOOL)updateLogsWithCurrentSessionId:(NSError * _Nullable * _Nullable)error;

- (BOOL)updateEventsWithCurrentSessionId:(NSError * _Nullable * _Nullable)error;

- (NSString * _Nullable)getCurrentOpenSessionId:(NSError * _Nullable * _Nullable)error;


@end

NS_ASSUME_NONNULL_END
