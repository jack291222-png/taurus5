#import "Core/SGCore.h"
#import "Settings/SGPage.h"
#import "Settings/SGPageStyle.h"
#import "Settings/SGModPage.h"
#import "Settings/SGGlowSwitch.h"
#import "Native/Home/Home.h"
#import "Shared/AdBlock/AdBlock.h"
#import "Shared/Player/PlayerSettings.h"
#import "Redesigned/Album/Album.h"
#import "Redesigned/Artist/Artist.h"
#import "Redesigned/Lyrics/Sing.h"
#import "Shared/Sing/SGSingModel.h"
#import "Shared/Flags/Flags.h"
#import "Shared/AudioEffects/AudioEffectsPage.h"
#import "Shared/LiveActivity/LiveActivity.h"
#import "Shared/HeadGestures/HeadGestures.h"
#import "Shared/Haptics/Haptics.h"
#import "Shared/Downloads/Downloads.h"
#import "Shared/ListeningStats/ListeningStats.h"
#import "App/About/About.h"
#import "Pages.h"

// The Misc page's switch that hides the Discord banner row in modSettingsPage below.
#define SGKeyHideDiscordBanner @"spotifyglass.hide.discordBanner"

static SGModRow *pageRow(NSString *title, NSString *symbol, UIViewController *(^page)(void)) {
    return SGWithSymbol(SGPageRow(title, page), symbol);
}

// How long the wordmark takes to carry its spectrum all the way round, matching the glow switch's turn.
static const double kRainbowSpinSeconds = 4;

static UIColor *SGRainbowTextColor(CGFloat width, CGFloat height, double phase) {
    width = MAX(1, width);
    height = MAX(1, height);
    NSArray<UIColor *> *stops = SGGlowRainbowColors();
    NSUInteger count = stops.count;
    if (count < 2) return UIColor.whiteColor;
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:count];
    for (UIColor *stop in stops) [colors addObject:(id)stop.CGColor];
    CGFloat *locations = malloc(sizeof(CGFloat) * count);
    for (NSUInteger i = 0; i < count; i++) locations[i] = (CGFloat)i / (CGFloat)(count - 1);
    CGFloat offset = (CGFloat)phase * width;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width, height)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);
        CGContextDrawLinearGradient(context.CGContext, gradient, CGPointMake(-offset, 0), CGPointMake(width - offset, 0), 0);
        CGContextDrawLinearGradient(context.CGContext, gradient, CGPointMake(width - offset, 0), CGPointMake(2 * width - offset, 0), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
    }];
    free(locations);
    return [UIColor colorWithPatternImage:image];
}

@interface SGTaurusSettingsPage : SGModPage
- (instancetype)initWithSections:(NSArray<SGModSection *> *)sections;
@end

@implementation SGTaurusSettingsPage {
    UIView *_masthead;
    UILabel *_mastheadTitle, *_mastheadByline, *_compactTitle;
    BOOL _compactTitleVisible;
    CADisplayLink *_rainbowLink;
    CFTimeInterval _rainbowLast;
    double _rainbowPhase;
}

- (instancetype)initWithSections:(NSArray<SGModSection *> *)sections {
    return [super initWithTitle:@"Individual" intro:nil sections:sections footer:@"Contributor: @Pulse-Ice (EeveeImmersive)\nBug fixes: @darkit"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _masthead = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 132)];
    _masthead.backgroundColor = SGPageBackground();
    _masthead.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _mastheadTitle = [UILabel new];
    _mastheadTitle.text = @"Individual";
    _mastheadTitle.font = [UIFont systemFontOfSize:36 weight:UIFontWeightBold];
    _mastheadTitle.textAlignment = NSTextAlignmentRight;
    [_mastheadTitle sizeToFit];
    _mastheadTitle.textColor = SGRainbowTextColor(_mastheadTitle.bounds.size.width, _mastheadTitle.bounds.size.height, 0);
    _mastheadByline = [UILabel new];
    _mastheadByline.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _mastheadByline.textColor = [UIColor colorWithWhite:1 alpha:0.72];
    _mastheadByline.textAlignment = NSTextAlignmentRight;
    [_masthead addSubview:_mastheadTitle];
    [_masthead addSubview:_mastheadByline];
    self.tableView.tableHeaderView = _masthead;

    _compactTitle = [UILabel new];
    _compactTitle.text = @"Individual";
    _compactTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [_compactTitle sizeToFit];
    _compactTitle.textColor = SGRainbowTextColor(_compactTitle.bounds.size.width, _compactTitle.bounds.size.height, 0);
    _compactTitle.alpha = 0;
    _compactTitle.isAccessibilityElement = YES;
    _compactTitle.accessibilityElementsHidden = YES;
    self.navigationItem.titleView = _compactTitle;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSArray<NSString *> *bylines = @[
        @"by natasha, samj, and arnaupq.", @"by natasha, arnaupq, and samj.",
        @"by samj, natasha, and arnaupq.", @"by samj, arnaupq, and natasha.",
        @"by arnaupq, natasha, and samj.", @"by arnaupq, samj, and natasha.",
    ];
    _mastheadByline.text = bylines[arc4random_uniform((uint32_t)bylines.count)];
    [self startRainbow];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopRainbow];
}

- (void)startRainbow {
    if (_rainbowLink) return;
    _rainbowLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(rainbowTick:)];
    _rainbowLink.preferredFrameRateRange = CAFrameRateRangeMake(24, 30, 30);
    [_rainbowLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stopRainbow {
    [_rainbowLink invalidate];
    _rainbowLink = nil;
    _rainbowLast = 0;
}

- (void)rainbowTick:(CADisplayLink *)link {
    CFTimeInterval step = _rainbowLast > 0 ? MIN(link.timestamp - _rainbowLast, 0.1) : 0;
    _rainbowLast = link.timestamp;
    _rainbowPhase += step / kRainbowSpinSeconds;
    _rainbowPhase -= floor(_rainbowPhase);
    [self applyRainbow];
}

- (void)applyRainbow {
    CGSize compact = _compactTitle.bounds.size;
    if (_compactTitleVisible) {
        if (compact.width >= 1)
            _compactTitle.textColor = SGRainbowTextColor(compact.width, compact.height, _rainbowPhase);
        return;
    }
    CGSize title = _mastheadTitle.bounds.size;
    if (title.width >= 1)
        _mastheadTitle.textColor = SGRainbowTextColor(title.width, title.height, _rainbowPhase);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.tableView.bounds.size.width;
    if (width > 0) {
        BOOL sizeChanged = _masthead.bounds.size.width != width || _masthead.bounds.size.height != 132;
        _masthead.frame = CGRectMake(0, 0, width, 132);
        if (sizeChanged || self.tableView.tableHeaderView != _masthead) self.tableView.tableHeaderView = _masthead;
        _masthead.backgroundColor = UIColor.blackColor;
        _mastheadByline.textColor = UIColor.whiteColor;
        CGSize title = _mastheadTitle.bounds.size;
        _mastheadTitle.frame = CGRectMake(MAX(16, width - 16 - title.width), 24 + (48 - title.height) / 2, title.width, title.height);
        _mastheadByline.frame = CGRectMake(16, 72, MAX(0, width - 32), 24);
    }
    [self updateCompactTitleForScrollView:self.tableView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateCompactTitleForScrollView:scrollView];
}

- (void)updateCompactTitleForScrollView:(UIScrollView *)scrollView {
    CGFloat scrolled = scrollView.contentOffset.y + scrollView.adjustedContentInset.top;
    BOOL show = scrolled >= CGRectGetHeight(_masthead.bounds);
    if (show == _compactTitleVisible) return;
    _compactTitleVisible = show;
    if (show) {
        _compactTitle.accessibilityElementsHidden = NO;
        [UIView animateWithDuration:0.18 animations:^{ self->_compactTitle.alpha = 1; }];
    } else {
        _compactTitle.accessibilityElementsHidden = YES;
        [UIView animateWithDuration:0.18 animations:^{ self->_compactTitle.alpha = 0; }];
    }
}

@end

static UIViewController *miscSettingsPage(void) {
    SGModRow *hideSigning = SGHideRow(@"Hide the lock screen alert", @"Hide the notice that this build cannot be opened from the lock screen", SGKeyHideSigningWarning);
    SGModRow *hideDiscord = SGHideRow(@"Hide the Discord banner", @"Hide the row here that advertises the Discord server", SGKeyHideDiscordBanner);
    SGModSection *banners = SGSection(nil, @[
        SGWithSymbol(hideSigning, @"lock.slash"),
        SGWithSymbol(hideDiscord, @"bubble.left.and.bubble.right"),
    ]);
    return [[SGModPage alloc] initWithTitle:@"Misc" intro:SGRestartNote sections:@[banners] footer:nil];
}

static UIViewController *modSettingsPage(void) {
    // Opening the page is the only thing that asks; the cache keeps it to once every six hours.
    SGCheckForUpdate();
    NSMutableArray<SGModSection *> *sections = [NSMutableArray array];
    SGModRow *signing = SGSigningWarningRow();
    if (signing) signing.visible = ^BOOL { return !SGFlag(SGKeyHideSigningWarning, NO); };
    NSMutableArray<SGModRow *> *topRows = [NSMutableArray array];
    SGModRow *update = SGActionRow(@"Individual update available", @"Tap to view the latest release", ^{
        NSString *url = SGUpdateNewestRelease().url;
        if (url.length) SGOpenURL(url);
    });
    update.symbol = @"arrow.down.circle.fill";
    update.color = SGGreen();
    update.visible = ^BOOL { return SGUpdateVersion() != nil; };
    update.refreshOn = SGUpdateCheckedNotification;
    [topRows addObject:update];
    SGModRow *discord = SGLinkRow(@"Join the Discord", @"Release pings, help and previews", SGDiscordURL);
    discord.image = SGDiscordIcon();
    discord.color = SGDiscordColor();
    discord.visible = ^BOOL { return !SGFlag(SGKeyHideDiscordBanner, NO); };
    [topRows addObject:discord];
    if (signing) [topRows addObject:signing];
    [sections addObject:SGSection(nil, topRows)];
    SGModRow *mod = pageRow(@"Mod", @"info.circle", ^UIViewController *{ return SGAboutPage(); });
    mod.value = ^NSString *{ return @(SG_VERSION); };
    // The audio effects work on the sound, so both looks have them, with what they are doing beside the chevron.
    SGModRow *audioEffects = pageRow(@"Audio effects", @"slider.vertical.3", ^UIViewController *{ return SGDSPSettingsPage(); });
    audioEffects.value = ^NSString *{ return SGDSPSummary(); };
    SGModRow *downloads = pageRow(@"Downloads", @"arrow.down.circle", ^UIViewController *{ return SGDownloadsSettingsPage(); });
    downloads.value = ^NSString *{ return SGDownloadsRowSummary(); };
    downloads.refreshOn = SGDownloadsDidChangeNotification;
    NSMutableArray<SGModRow *> *parts = [NSMutableArray arrayWithArray:@[
        pageRow(@"Appearance", @"paintpalette", ^UIViewController *{ return SGAppearanceSettingsPage(); }),
        pageRow(@"Navbar", @"dock.rectangle", ^UIViewController *{ return SGNavbarPage(); }),
        pageRow(@"Player", @"play.circle", ^UIViewController *{ return SGPlayerSettingsPage(); }),
        pageRow(@"Lyrics", @"quote.bubble", ^UIViewController *{ return SGLyricsSettingsPage(); }),
        downloads,
        pageRow(@"Lock Screen", @"lock.iphone", ^UIViewController *{ return SGLockScreenSettingsPage(); }),
        audioEffects,
        pageRow(@"Vibrations", @"iphone.radiowaves.left.and.right", ^UIViewController *{ return SGVibrationsSettingsPage(); }),
    ]];
    if (@available(iOS 17.0, *)) {
        SGModRow *liveActivity = pageRow(@"Live Activity", @"platter.filled.top.iphone", ^UIViewController *{ return SGLiveActivitySettingsPage(); });
        liveActivity.value = ^NSString *{ return SGLiveActivitySummary(); };
        [parts addObject:liveActivity];
    }
    [parts addObjectsFromArray:@[
        pageRow(@"AirPods gestures", @"airpods.pro", ^UIViewController *{ return SGHeadGesturesSettingsPage(); }),
        pageRow(@"Listening stats", @"chart.bar", ^UIViewController *{ return SGListeningStatsPage(); }),
    ]];
    if (SGRedesignedUIStored()) {
        [parts addObject:pageRow(@"Albums", @"square.stack", ^UIViewController *{ return SGRAlbumSettingsPage(); })];
        [parts addObject:pageRow(@"Artists", @"person.2", ^UIViewController *{ return SGRArtistSettingsPage(); })];
    }
    else [parts addObject:pageRow(@"Home & Library", @"house", ^UIViewController *{ return SGHomeSettingsPage(); })];
    [parts addObject:pageRow(@"Misc", @"ellipsis.circle", ^UIViewController *{ return miscSettingsPage(); })];
    // Sing's microphone is the redesigned player's, so Karaoke is the redesign's; its row follows a download.
    if (SGRedesignedUIStored()) {
        SGModRow *karaoke = pageRow(@"Karaoke", @"music.mic", ^UIViewController *{ return SGRKaraokeSettingsPage(); });
        karaoke.value = ^NSString *{ return SGRKaraokeSummary(); };
        karaoke.refreshOn = SGSingModelDidChangeNotification;
        [sections addObject:SGSection(nil, @[karaoke])];
    }
    [sections addObjectsFromArray:@[
        SGSection(nil, parts),
        SGSection(nil, @[
            pageRow(@"Premium, ads & privacy", @"crown", ^UIViewController *{ return SGAdsSettingsPage(); }),
            pageRow(@"Labs", @"testtube.2", ^UIViewController *{ return SGLabsPage(); }),
        ]),
        SGSection(nil, @[
            pageRow(@"All flags", @"flag", ^UIViewController *{ return SGAllFlagsPage(); }),
            mod,
        ]),
    ]];
    return [[SGTaurusSettingsPage alloc] initWithSections:sections];
}

static UINavigationController *navigationIn(UIViewController *page) {
    if ([page isKindOfClass:UINavigationController.class]) return (UINavigationController *)page;
    for (UIViewController *child in page.childViewControllers) {
        UINavigationController *found = navigationIn(child);
        if (found) return found;
    }
    return nil;
}


// The tab bar's controller holds no stack itself; the selected tab's sits among its parent's children.
void SGOpenModSettings(UIView *source) {
    UIViewController *owner = nil;
    for (UIResponder *r = source; r && !owner; r = r.nextResponder) {
        if ([r isKindOfClass:UIViewController.class]) owner = (UIViewController *)r;
    }
    UINavigationController *nav = nil;
    for (UIViewController *page = owner; page && !nav; page = page.parentViewController) nav = navigationIn(page);
    SGShowPage(nav.topViewController ?: SGTopController(), modSettingsPage());
}


%ctor {
    SGRegisterPages();
    SGCheckSigningOnce();
}
