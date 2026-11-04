#import "Core/SGCore.h"

// Search the complete create-menu ancestor, not a fixed-height sheet: Spotify
// can put the four rows in separate cells under a full-screen container.
static BOOL SGIsBlockedJamTouch(UIView *hit, UIWindow *window, CGPoint point, CGRect *targetRect) {
    for (UIView *view = hit; view && view != window; view = view.superview) {
        __block BOOL playlist = NO, blend = NO;
        __block UILabel *jam = nil;
        SGForEachView(view, ^(UIView *child) {
            if (![child isKindOfClass:UILabel.class]) return;
            UILabel *label = (UILabel *)child;
            NSString *text = [label.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if ([text isEqualToString:@"Playlist"]) playlist = YES;
            if ([text isEqualToString:@"Blend"]) blend = YES;
            if ([text isEqualToString:@"Jam"] && label.window == window && label.alpha > 0) jam = label;
        });
        if (!playlist || !blend || !jam) continue;
        // Prefer the actual row boundary, including its icon and subtitle.
        UIView *row = jam;
        for (UIView *parent = jam.superview; parent && parent != view; parent = parent.superview) {
            if (parent.bounds.size.height > 120) break;
            if (parent.bounds.size.width > row.bounds.size.width) row = parent;
        }
        CGRect rect = [row convertRect:row.bounds toView:window];
        CGRect title = [jam convertRect:jam.bounds toView:window];
        rect = CGRectUnion(rect, CGRectMake(0, CGRectGetMinY(title) - 16,
                                         window.bounds.size.width, title.size.height + 56));
        if (!CGRectContainsPoint(rect, point)) return NO;
        CGRect menu = [view convertRect:view.bounds toView:window];
        *targetRect = CGRectIntersection(rect, menu);
        return YES;
    }
    return NO;
}

// A window-owned no-action button receives the touch, outside Spotify's row
// recognizers. It still tracks a held finger and supplies the requested feedback.
@interface SGJamPressButton : UIButton
@end
@implementation SGJamPressButton
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [UIColor colorWithWhite:0 alpha:0.35] : UIColor.clearColor;
}
@end
static char kJamPressButtonKey;

%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    SGJamPressButton *button = objc_getAssociatedObject(self, &kJamPressButtonKey);
    [button removeFromSuperview];
    UIView *hit = %orig;
    CGRect row = CGRectZero;
    if (!hit || !SGIsBlockedJamTouch(hit, self, point, &row)) return hit;
    if (!button) {
        button = [SGJamPressButton buttonWithType:UIButtonTypeCustom];
        button.accessibilityLabel = @"Jam";
        button.accessibilityHint = @"No action";
        button.layer.cornerRadius = 12;
        button.clipsToBounds = YES;
        objc_setAssociatedObject(self, &kJamPressButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    button.frame = CGRectInset(row, 4, 0);
    [self addSubview:button];
    return button;
}
%end

// Defense in depth for Jam entry points outside Create. Match the runtime
// controller family, never generic Premium pages or arbitrary alert copy.
%hook UIViewController
- (void)presentViewController:(UIViewController *)page animated:(BOOL)animated completion:(void (^)(void))completion {
    UIViewController *content = [page isKindOfClass:UINavigationController.class]
        ? ((UINavigationController *)page).viewControllers.firstObject : page;
    NSString *name = NSStringFromClass(content.class).lowercaseString;
    if ([name containsString:@"jam"] && [name containsString:@"upsell"]) {
        SGLog(@"blocked Jam upsell presentation: %@", NSStringFromClass(content.class));
        if (completion) completion();
        return;
    }
    %orig;
}
%end

%ctor { %init; }
