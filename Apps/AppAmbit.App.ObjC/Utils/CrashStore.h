#import <Foundation/Foundation.h>
@class ExceptionModel;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CrashStoreError) {
    CrashStoreErrorAppSupportNotFound = 1,
    CrashStoreErrorDirectoryMissing   = 2
};

@interface CrashStore : NSObject

+ (NSArray<ExceptionModel *> *)loadAll:(NSError * _Nullable * _Nullable)error;

+ (NSArray<ExceptionModel *> *)loadRangeFrom:(NSDate * _Nullable)from
                                          to:(NSDate * _Nullable)to
                                       error:(NSError * _Nullable * _Nullable)error;

+ (ExceptionModel * _Nullable)loadLatest:(NSError * _Nullable * _Nullable)error;

+ (NSArray<ExceptionModel *> *)loadLatestWithLimit:(NSInteger)limit
                                             error:(NSError * _Nullable * _Nullable)error;

+ (ExceptionModel * _Nullable)loadByFilename:(NSString *)filename
                                       error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
