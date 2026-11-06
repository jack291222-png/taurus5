// The "Premium" badge out of the rows that sell a subscription beside something the mod already gives you: the
// sheet Spotify opens for a new playlist (Playlist, Collaborative playlist, Blend, Jam) puts one on the Jam
// row, Spotify's mark and the word. Hide upsells removes the sales marker, not
// a server-side entitlement. The Very high quality row and Connect sheet
// Start a Jam tag use the same treatment.
//
// Two ways, because the badge is drawn one of two ways: Spotify's own SPTPremiumBadgeView, wherever it appears
// (the redesign's ⋯ takes that class out there; this is the one the rest of the app shows), and, for a badge
// drawn as a plain label, a word "Premium" in the same row as a word "Jam" and nothing else. The second is
// anchored on the Jam row on purpose: "Premium" is also a heading on the mod's own pages and in Spotify's, and
// a word on its own is never touched.
//
// Hiding is alpha, not hidden: Spotify lays these rows out in its own stacks, and hidden on a view inside one
// of those has crashed it (docs/tweaks.md). The mark beside the word goes with the word; the row's own title
// and its glyph stay.
#import "Core/SGCore.h"
#import "AdBlock.h"
#import "BadgeMatching.h"

@interface SPTPremiumBadgeView : UIView
@end

static char kHidPartsKey, kSuppressedPartKey;

// The word a label says, plain or attributed. Attributed text is only asked for when there is no plain text and
// it is short enough to be this word, because reading it builds a string.
static NSString *wordIn(UILabel *label) {
    NSString *text = label.text;
    if (!text.length) {
        NSAttributedString *attributed = label.attributedText;
        if (attributed.length > 0 && attributed.length <= 16) text = attributed.string;
    }
    return SGAdBadgeNormalizedText(text);
}

static BOOL says(NSString *text, NSString *word) {
    text = SGAdBadgeNormalizedText(text);
    return text.length > 0 && text.length < 24 && [text caseInsensitiveCompare:word] == NSOrderedSame;
}

static BOOL holds(UIView *root, NSString *word) {
    __block BOOL found = NO;
    SGForEachView(root, ^(UIView *view) {
        if (found) return;
        if ([view isKindOfClass:UILabel.class] && says(wordIn((UILabel *)view), word)) found = YES;
        if (says(view.accessibilityLabel, word)) found = YES;
        if ([view isKindOfClass:UIButton.class] && says(((UIButton *)view).currentTitle, word)) found = YES;
    });
    return found;
}

// The row the word is in: up from the label while the ancestor is still one row, no taller than a few lines,
// and holds the Jam of the row.
static UIView *jamRowAround(UILabel *label) {
    UIView *row = label.superview;
    for (int depth = 0; row && depth < 6; depth++, row = row.superview) {
        if (row == label || CGRectGetHeight(row.bounds) > 120) break;
        if (holds(row, @"Jam")) return row;
    }
    return nil;
}

// Connect uses "Start a Jam", with the Premium tag above the button rather
// than beside a "Jam" row. Locate it by the observed sheet texts and geometry;
// do not assume a private Connect/badge class or hide the footer itself.
static UIView *connectJamBadge(UIView *label) {
    for (UIView *root = label.superview; root && ![root isKindOfClass:UIWindow.class]; root = root.superview) {
        if (!holds(root, @"Start a Jam") ||
            !(holds(root, @"Connect") || holds(root, @"Bluetooth & Airplay"))) continue;
        CGRect badge = [label convertRect:label.bounds toView:root];
        __block BOOL nearJam = NO;
        SGForEachView(root, ^(UIView *view) {
            BOOL jam = [view isKindOfClass:UILabel.class] && says(wordIn((UILabel *)view), @"Start a Jam");
            jam = jam || says(view.accessibilityLabel, @"Start a Jam");
            if ([view isKindOfClass:UIButton.class]) jam = jam || says(((UIButton *)view).currentTitle, @"Start a Jam");
            if (!jam) return;
            CGRect title = [view convertRect:view.bounds toView:root];
            // The tag sits at the upper-left of the Jam tile, above its title.
            nearJam = nearJam || SGConnectBadgeAboveJam(badge, title);
        });
        if (!nearJam) continue;
        UIView *surface = label;
        for (UIView *parent = label.superview; parent && parent != root; parent = parent.superview) {
            if (parent.bounds.size.height > 48 || parent.bounds.size.width > 180) break;
            if (holds(parent, @"Start a Jam")) break;
            surface = parent;
        }
        return surface;
    }
    return nil;
}

// Media quality's Very high option can use an independent Premium label.
// Match the option within one row, not the Premium branding on plan pages.
static BOOL qualitySection(UIView *root) {
    return holds(root, @"Media quality") || holds(root, @"Audio download quality")
        || holds(root, @"Wi-Fi streaming quality") || holds(root, @"Cellular streaming quality");
}

static BOOL isVeryHighBadge(UILabel *label) {
    for (UIView *root = label.superview; root && ![root isKindOfClass:UIWindow.class]; root = root.superview) {
        if (!qualitySection(root)) continue;
        // Encore may put the option and trailing badge in separate branches
        // under one tall list. Compare their actual positions, not parent height.
        CGRect badge = [label convertRect:label.bounds toView:root];
        __block BOOL aligned = NO;
        SGForEachView(root, ^(UIView *view) {
            if (aligned || ![view isKindOfClass:UILabel.class]) return;
            UILabel *option = (UILabel *)view;
            if (!says(wordIn(option), @"Very high")) return;
            CGRect frame = [option convertRect:option.bounds toView:root];
            if (frame.size.height <= 0 || badge.size.height <= 0) return;
            CGFloat tolerance = MAX(8, MIN(frame.size.height, badge.size.height) / 2);
            aligned = fabs(CGRectGetMidY(frame) - CGRectGetMidY(badge)) <= tolerance
                && CGRectGetMinX(badge) >= CGRectGetMaxX(frame) - 2;
        });
        if (aligned) return YES;
    }
    return NO;
}

// Other Spotify versions put the marker into the option title itself.
static NSString *qualityTitle(NSString *text) {
    if (!text.length || text.length > 48) return nil;
    NSRange match = [text rangeOfString:@"^Very high\\s*(?:[·•—–-]\\s*)?\\(?Premium\\)?$"
                               options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
    return match.location != NSNotFound ? [text substringToIndex:9] : nil;
}

// The mark beside the word: the small views on its line, just before it. Spotify's Encore label puts its words
// in a UILabel of its own (id=...-internal, PlayerControls.x), so the word's line is asked for, and then the
// line its own view is in; the row's title and its glyph are far wider than a mark, so they are left alone.
static NSArray<UIView *> *partsOfBadge(UILabel *label) {
    NSMutableArray<UIView *> *parts = [NSMutableArray arrayWithObject:label];
    UIView *anchor = label;
    for (int up = 0; up < 2 && anchor; up++, anchor = anchor.superview) {
        UIView *line = anchor.superview;
        if (!line || CGRectGetHeight(line.bounds) > 44) break;
        CGRect word = [anchor convertRect:anchor.bounds toView:line];
        NSUInteger found = 0;
        for (UIView *sibling in line.subviews) {
            if (sibling == anchor || [sibling isKindOfClass:UILabel.class]) continue;
            if (CGRectGetHeight(sibling.bounds) > 24 || CGRectGetWidth(sibling.bounds) > 28) continue;
            CGRect part = [sibling convertRect:sibling.bounds toView:line];
            if (CGRectGetMidY(part) < CGRectGetMinY(word) - 4 || CGRectGetMidY(part) > CGRectGetMaxY(word) + 4) continue;
            if (CGRectGetMaxX(part) > CGRectGetMinX(word) + 2) continue;
            if (CGRectGetMaxX(part) < CGRectGetMinX(word) - 28) continue;
            [parts addObject:sibling];
            found++;
        }
        if (found) break;
    }
    return parts;
}

static void hideBadge(UIView *owner, UIView *surface) {
    // Weak references are essential: a compact surface can contain the owner.
    // Retaining that ancestor from its own label would create a retain cycle.
    NSHashTable<UIView *> *parts = objc_getAssociatedObject(owner, &kHidPartsKey);
    if (!parts) {
        if (surface) SGLog(@"suppressed Connect Jam Premium tag: %@", NSStringFromClass(surface.class));
        parts = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(owner, &kHidPartsKey, parts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (surface) [parts addObject:surface];
    [parts addObject:owner];
    if ([owner isKindOfClass:UILabel.class]) {
        for (UIView *part in partsOfBadge((UILabel *)owner)) [parts addObject:part];
    }
    for (UIView *part in parts.allObjects) {
        objc_setAssociatedObject(part, &kSuppressedPartKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        part.alpha = 0;
    }
}

static void showBadge(UIView *owner) {
    NSHashTable<UIView *> *parts = objc_getAssociatedObject(owner, &kHidPartsKey);
    if (!parts) return;
    for (UIView *part in parts.allObjects) {
        objc_setAssociatedObject(part, &kSuppressedPartKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (part.alpha == 0) part.alpha = 1;
    }
    objc_setAssociatedObject(owner, &kHidPartsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Once the label has a frame its row can be read: the word comes before the mark beside it has one, and a row
// reused for another one is laid out again with the word still in it.
static void settle(UILabel *label) {
    if (!says(wordIn(label), @"Premium") || CGRectGetWidth(label.bounds) < 1) {
        showBadge(label);
        return;
    }
    UIView *connectSurface = connectJamBadge(label);
    BOOL badge = connectSurface || jamRowAround(label) || isVeryHighBadge(label);
    if (badge) hideBadge(label, connectSurface);
    else showBadge(label);
}

// A label that could be the badge, asked before anything is walked: one the mod has already hidden, or one
// whose plain text is the word. A label laid out with attributed text and no plain text is left to the passes
// that come once, so nothing here reads an attributed string on a layout pass.
static BOOL watched(UILabel *label) {
    if (objc_getAssociatedObject(label, &kHidPartsKey) != nil) return YES;
    return says(wordIn(label), @"Premium");
}

// The mark itself, wherever Spotify puts one: alpha rather than hidden, for the reason above, and it takes no
// touch, so a row it sat in still does what it says. (ContextMenu.x hooks its -didMoveToSuperview for the
// redesign; this leaves that method to it.)
// Spotify can set the compact tag's opacity after layout/appearance. Keep only
// explicitly matched parts suppressed until showBadge releases them on reuse.
%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    %orig(objc_getAssociatedObject(self, &kSuppressedPartKey) ? 0 : alpha);
}
- (void)didMoveToWindow {
    %orig;
    if (!self.window && objc_getAssociatedObject(self, &kHidPartsKey)) showBadge(self);
}
%end

%hook SPTPremiumBadgeView
- (void)didMoveToWindow {
    %orig;
    self.alpha = 0;
    self.userInteractionEnabled = NO;
}

- (void)layoutSubviews {
    %orig;
    if (self.alpha != 0) self.alpha = 0;
    if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
}
%end

%hook UILabel
- (void)setText:(NSString *)text {
    NSString *clean = qualityTitle(text);
    %orig(clean ?: text);
    if (text.length < 1 || text.length > 16 || !watched(self)) return;
    settle(self);
}

- (void)setAttributedText:(NSAttributedString *)text {
    NSString *clean = qualityTitle(text.string);
    if (clean) {
        %orig([text attributedSubstringFromRange:NSMakeRange(0, clean.length)]);
    } else {
        %orig;
    }
    if (text.length < 1 || text.length > 16) return;
    if (!watched(self) && !says(wordIn(self), @"Premium")) return;
    settle(self);
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    if (!watched(self) && !says(wordIn(self), @"Premium")) return;
    settle(self);
}

- (void)layoutSubviews {
    %orig;
    if (self.text.length < 1 || self.text.length > 16 || !watched(self)) return;
    settle(self);
}
%end

// Parent layouts can position the option after its badge label has laid out.
// Retry from completed quality-page and Connect-sheet layouts, including reused labels.
%hook UIViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *root = ((UIViewController *)self).viewIfLoaded;
    if (!root) return;
    BOOL connect = holds(root, @"Start a Jam") &&
        (holds(root, @"Connect") || holds(root, @"Bluetooth & Airplay"));
    if (!connect && !qualitySection(root)) return;
    SGForEachView(root, ^(UIView *view) {
        if ([view isKindOfClass:UILabel.class]) {
            if (watched((UILabel *)view)) settle((UILabel *)view);
            return;
        }
        // Some Encore tags expose text through accessibility/button titles,
        // not an inner UILabel. Match that public surface without class guesses.
        if (!connect) return;
        BOOL premium = says(view.accessibilityLabel, @"Premium");
        if ([view isKindOfClass:UIButton.class]) premium = premium || says(((UIButton *)view).currentTitle, @"Premium");
        if (!premium && !objc_getAssociatedObject(view, &kHidPartsKey)) return;
        // Leave label-backed tags to the label path to avoid two hide owners.
        __block BOOL innerLabel = NO;
        SGForEachView(view, ^(UIView *child) {
            if ([child isKindOfClass:UILabel.class] && says(wordIn((UILabel *)child), @"Premium")) innerLabel = YES;
        });
        if (innerLabel) return;
        UIView *surface = premium ? connectJamBadge(view) : nil;
        if (surface) hideBadge(view, surface);
        else if (objc_getAssociatedObject(view, &kHidPartsKey)) showBadge(view);
    });
}
%end

%ctor {
    if (!SGFlag(SGKeyHideUpsells, YES)) return;
    %init;
    SGRequireClasses(@[@"SPTPremiumBadgeView"]);
}
