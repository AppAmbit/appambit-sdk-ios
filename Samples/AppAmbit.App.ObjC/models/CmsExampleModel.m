#import "CmsExampleModel.h"

@implementation AuthorRelation

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self && dict && [dict isKindOfClass:[NSDictionary class]]) {
        _author = dict[@"author"];
    }
    return self;
}

- (NSString *)displayString {
    if (self.author && ![self.author isKindOfClass:[NSNull class]]) return self.author;
    return @"Unknown Author";
}

@end

@implementation CmsExampleModel

- (id)safeObject:(id)obj {
    return (obj == [NSNull null]) ? nil : obj;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self && [dict isKindOfClass:[NSDictionary class]]) {
        _id = [self safeObject:dict[@"id"]];
        _title = [self safeObject:dict[@"title"]];
        _body = [self safeObject:dict[@"body"]];
        id catObj = [self safeObject:dict[@"category"]];
        if ([catObj isKindOfClass:[NSArray class]]) {
            _category = catObj;
        } else if ([catObj isKindOfClass:[NSString class]] && [(NSString *)catObj length] > 0) {
            _category = @[catObj];
        } else {
            _category = nil;
        }
        _featuredImage = [self safeObject:dict[@"featured_image"]];
        
        id authorObj = [self safeObject:dict[@"author"]];
        if ([authorObj isKindOfClass:[NSDictionary class]]) {
            _author = [[AuthorRelation alloc] initWithDictionary:authorObj];
        } else {
            _author = nil;
        }
        
        id vwObj = [self safeObject:dict[@"views_count"]];
        _viewsCount = vwObj ? [vwObj doubleValue] : 0.0;
        
        id pubObj = [self safeObject:dict[@"is_published"]];
        _isPublished = pubObj ? [pubObj boolValue] : NO;
        
        _eventDate = [self safeObject:dict[@"event_date"]];
        _scheduledPublishAt = [self safeObject:dict[@"scheduled_publish_at"]];
        _authorEmail = [self safeObject:dict[@"author_email"]];
        _metaData = [self safeObject:dict[@"meta_data"]];
    }
    return self;
}

@end
