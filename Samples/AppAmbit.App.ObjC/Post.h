#import <Foundation/Foundation.h>

@interface AuthorRelation : NSObject
@property (nonatomic, copy, nullable) NSString *id;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *author;
- (instancetype _Nullable)initWithDictionary:(NSDictionary * _Nullable)dict;
- (NSString * _Nonnull)displayString;
@end

@interface Post : NSObject

@property (nonatomic, copy, nullable) NSString *id;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *body;
@property (nonatomic, copy, nullable) NSString *category;
@property (nonatomic, strong, nullable) AuthorRelation *author;
@property (nonatomic, copy, nullable) NSString *featuredImage;

@property (nonatomic, assign) double viewsCount;
@property (nonatomic, assign) BOOL isPublished;
@property (nonatomic, copy, nullable) NSString *eventDate;
@property (nonatomic, copy, nullable) NSString *scheduledPublishAt;
@property (nonatomic, copy, nullable) NSString *authorEmail;
@property (nonatomic, strong, nullable) id metaData;

- (instancetype _Nullable)initWithDictionary:(NSDictionary * _Nullable)dict;

@end
