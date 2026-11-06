#import <Foundation/Foundation.h>
#import "BadgeMatching.h"
int main(void) {
    @autoreleasepool {
        NSCAssert([SGAdBadgeNormalizedText(@"Start a\nJam") isEqual:@"Start a Jam"], @"wrapped Jam title");
        NSCAssert([SGAdBadgeNormalizedText(@"Bluetooth &\nAirplay") isEqual:@"Bluetooth & Airplay"], @"wrapped neighboring button");
        NSCAssert([SGAdBadgeNormalizedText(@"\uFFFC Premium\u00a0") isEqual:@"Premium"], @"inline logo and nonbreaking space");
        NSCAssert([SGAdBadgeNormalizedText(nil) isEqual:@""], @"no accessibility label");
        NSCAssert([SGAdBadgeNormalizedText(@"Your Premium") isEqual:@"Your Premium"], @"do not collapse plan branding to Premium");
        CGRect badge = CGRectMake(20, 400, 75, 20);
        CGRect jam = CGRectMake(50, 450, 110, 24);
        NSCAssert(SGConnectBadgeAboveJam(badge, jam), @"tag above title in observed layout");
        NSCAssert(!SGConnectBadgeAboveJam(CGRectMake(20, 490, 75, 20), jam), @"not below Jam");
        NSCAssert(!SGConnectBadgeAboveJam(CGRectMake(250, 400, 75, 20), jam), @"not above Airplay tile");
        NSCAssert(!SGConnectBadgeAboveJam(CGRectMake(20, 100, 75, 20), jam), @"not another card's Premium heading");
        NSCAssert(!SGConnectBadgeAboveJam(CGRectZero, jam), @"wait for layout");
        puts("Connect badge matching tests passed");
    }
    return 0;
}
