#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Shared by UILabel, UIButton and accessibility paths; Encore wraps titles and
// can embed its logo as a text attachment rather than a sibling UIImageView.
static inline NSString *SGAdBadgeNormalizedText(NSString *text) {
    if (![text isKindOfClass:NSString.class]) return @"";
    text = [text stringByReplacingOccurrencesOfString:@"\uFFFC" withString:@""];
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *word in [text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if (word.length) [words addObject:word];
    }
    return [words componentsJoinedByString:@" "];
}

static inline BOOL SGConnectBadgeAboveJam(CGRect badge, CGRect title) {
    if (badge.size.width <= 0 || badge.size.height <= 0 || title.size.width <= 0 || title.size.height <= 0) return NO;
    return CGRectGetMidY(badge) >= CGRectGetMinY(title) - 100
        && CGRectGetMaxY(badge) <= CGRectGetMinY(title) + 4
        && CGRectGetMinX(badge) < CGRectGetMaxX(title)
        && CGRectGetMaxX(badge) > CGRectGetMinX(title) - 100;
}
