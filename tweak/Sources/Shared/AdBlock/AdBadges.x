// The "Premium" badge out of the rows that sell a subscription beside something the mod already gives you: the
// sheet Spotify opens for a new playlist (Playlist, Collaborative playlist, Blend, Jam) puts one on the Jam
// row, Spotify's mark and the word. Hide upsells removes the sales marker, not
// a server-side entitlement. The Very high quality row uses the same treatment.
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

@interface SPTPremiumBadgeView : UIView
@end

static char kHidPartsKey;

// The word a label says, plain or attributed. Attributed text is only asked for when there is no plain text and
// it is short enough to be this word, because reading it builds a string.
static NSString *wordIn(UILabel *label) {
    NSString *text = label.text;
    if (!text.length) {
        NSAttributedString *attributed = label.attributedText;
        if (attributed.length > 0 && attributed.length <= 16) text = attributed.string;
    }
    if (![text isKindOfClass:NSString.class]) return nil;
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static BOOL says(NSString *text, NSString *word) {
    return text.length > 0 && text.length < 24 && [text caseInsensitiveCompare:word] == NSOrderedSame;
}

static BOOL holds(UIView *root, NSString *word) {
    __block BOOL found = NO;
    SGForEachView(root, ^(UIView *view) {
        if (found || ![view isKindOfClass:UILabel.class]) return;
        if (says(wordIn((UILabel *)view), word)) found = YES;
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

// Media quality's Very high option can use an independent Premium label.
// Match the option within one row, not the Premium branding on plan pages.
static BOOL isVeryHighBadge(UILabel *label) {
    for (UIView *row = label.superview; row; row = row.superview) {
        if (CGRectGetHeight(row.bounds) > 120) break;
        if (holds(row, @"Very high")) return YES;
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

static void hideBadge(UILabel *label) {
    if (objc_getAssociatedObject(label, &kHidPartsKey)) return;
    NSArray<UIView *> *parts = partsOfBadge(label);
    for (UIView *part in parts) part.alpha = 0;
    objc_setAssociatedObject(label, &kHidPartsKey, parts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SGLog(@"hid %lu part(s) of the Premium badge beside Jam", (unsigned long)parts.count);
}

static void showBadge(UILabel *label) {
    NSArray<UIView *> *parts = objc_getAssociatedObject(label, &kHidPartsKey);
    if (!parts) return;
    for (UIView *part in parts) if (part.alpha == 0) part.alpha = 1;
    objc_setAssociatedObject(label, &kHidPartsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Once the label has a frame its row can be read: the word comes before the mark beside it has one, and a row
// reused for another one is laid out again with the word still in it.
static void settle(UILabel *label) {
    BOOL badge = says(wordIn(label), @"Premium") && CGRectGetWidth(label.bounds) >= 1 && (jamRowAround(label) || isVeryHighBadge(label));
    if (badge) hideBadge(label);
    else showBadge(label);
}

// A label that could be the badge, asked before anything is walked: one the mod has already hidden, or one
// whose plain text is the word. A label laid out with attributed text and no plain text is left to the passes
// that come once, so nothing here reads an attributed string on a layout pass.
static BOOL watched(UILabel *label) {
    if (objc_getAssociatedObject(label, &kHidPartsKey) != nil) return YES;
    return says([label.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet], @"Premium");
}

// The mark itself, wherever Spotify puts one: alpha rather than hidden, for the reason above, and it takes no
// touch, so a row it sat in still does what it says. (ContextMenu.x hooks its -didMoveToSuperview for the
// redesign; this leaves that method to it.)
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

%ctor {
    if (!SGFlag(SGKeyHideUpsells, YES)) return;
    %init;
    SGRequireClasses(@[@"SPTPremiumBadgeView"]);
}
