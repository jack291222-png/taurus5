#import "Core/SGCore.h"

// Intercept at the window, before Spotify's controls or ancestor gestures receive
// the touch. No private action selectors are guessed and no sheet is dismissed
// after presentation (which would flash the upsell).
static BOOL SGBlockEntryPoint(UIView *hit, UIWindow *window, CGPoint point) {
    for (UIView *view = hit; view && view != window; view = view.superview) {
        CGRect frame = [view convertRect:view.bounds toView:window];
        NSString *accessibility = view.accessibilityLabel.lowercaseString;
        if (CGRectGetMaxX(frame) <= 100 && CGRectGetMaxY(frame) <= window.safeAreaInsets.top + 100 &&
            ([accessibility isEqualToString:@"your profile"] ||
             [accessibility isEqualToString:@"profile"] ||
             [accessibility isEqualToString:@"open profile"] ||
             [accessibility isEqualToString:@"open navigation menu"])) return YES;
        // Only the create sheet containing all three titles qualifies. Locate
        // Jam's vertical band there, not arbitrary Jam labels in a playlist.
        if (CGRectGetHeight(view.bounds) < 180 || CGRectGetHeight(view.bounds) > 500) continue;
        __block BOOL playlist = NO, blend = NO;
        __block UILabel *jam = nil;
        SGForEachView(view, ^(UIView *child) {
            if (![child isKindOfClass:UILabel.class]) return;
            UILabel *label = (UILabel *)child;
            if ([label.text isEqualToString:@"Playlist"]) playlist = YES;
            if ([label.text isEqualToString:@"Blend"]) blend = YES;
            if ([label.text isEqualToString:@"Jam"]) jam = label;
        });
        if (playlist && blend && jam) {
            CGRect title = [jam convertRect:jam.bounds toView:window];
            if (point.y >= CGRectGetMinY(title) - 16 && point.y <= CGRectGetMaxY(title) + 40) return YES;
        }
    }
    return NO;
}

%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = %orig;
    if (hit && SGBlockEntryPoint(hit, self, point)) return self;
    return hit;
}
%end

%ctor { %init; }
