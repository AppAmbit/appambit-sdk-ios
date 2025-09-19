#import "NetworkMonitor.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <string.h>

@implementation NetworkMonitor

+ (BOOL)isConnected {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = (uint8_t)sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    SCNetworkReachabilityRef reachability =
        SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&zeroAddress);
    if (reachability == NULL) {
        return NO;
    }

    SCNetworkReachabilityFlags flags = 0;
    Boolean got = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!got) {
        return NO;
    }

    BOOL isReachable     = (flags & kSCNetworkFlagsReachable) != 0;
    BOOL needsConnection = (flags & kSCNetworkFlagsConnectionRequired) != 0;

    return (isReachable && !needsConnection);
}

@end
