#import "Core/SGCore.h"
#import "AdBlock.h"

// The observed Jam upsell is a sheet, not an Encore popup. Keep Spotify's
// original Create row and recognizers intact and reject the destination instead.
// Match both observed texts so normal Jam sessions and plan pages still work.
static BOOL SGIsJamUpsell(UIViewController *page) {
    if (!page) return NO;
    [page loadViewIfNeeded];
    __block BOOL pitch = NO, premium = NO;
    SGForEachView(page.view, ^(UIView *view) {
        NSString *text = nil;
        if ([view isKindOfClass:UILabel.class]) text = ((UILabel *)view).text;
        else if ([view isKindOfClass:UIButton.class]) text = ((UIButton *)view).currentTitle;
        text = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
        if ([text isEqualToString:@"music sounds better together"]) pitch = YES;
        if ([text isEqualToString:@"explore premium"]) premium = YES;
    });
    if (pitch && premium) return YES;
    for (UIViewController *child in page.childViewControllers) {
        if (SGIsJamUpsell(child)) return YES;
    }
    return NO;
}

// When Create uses a UIControl, swallow its action, not its touch tracking.
// The sheet guard below also covers versions that use gesture-driven rows.
static BOOL SGIsCreateJamControl(UIControl *control) {
    for (UIView *row = control; row && row.bounds.size.height <= 120; row = row.superview) {
        __block BOOL title = NO, subtitle = NO;
        SGForEachView(row, ^(UIView *view) {
            if (![view isKindOfClass:UILabel.class]) return;
            NSString *text = ((UILabel *)view).text.lowercaseString;
            if ([text isEqualToString:@"jam"]) title = YES;
            if ([text isEqualToString:@"listen together from anywhere"]) subtitle = YES;
        });
        if (title && subtitle) return YES;
    }
    return NO;
}

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (SGIsCreateJamControl(self)) {
        SGLog(@"ignored Create Jam action, keeping native press feedback");
        return;
    }
    %orig;
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)page animated:(BOOL)animated completion:(void (^)(void))completion {
    if (SGIsJamUpsell(page)) {
        SGAdBlockCountOne(@"Popups");
        SGLog(@"blocked observed Jam upsell sheet before presentation");
        if (completion) completion();
        return;
    }
    %orig;
}
%end

%hook UINavigationController
- (void)pushViewController:(UIViewController *)page animated:(BOOL)animated {
    if (SGIsJamUpsell(page)) {
        SGAdBlockCountOne(@"Popups");
        SGLog(@"blocked observed Jam upsell navigation");
        return;
    }
    %orig;
}
%end

%ctor {
    if (!SGFlag(SGKeyHideUpsells, YES)) return;
    %init;
}
