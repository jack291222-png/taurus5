#import "IndividualPlan.h"
#import "Settings/SGPage.h"
#import "Core/SGCore.h"
#import <objc/runtime.h>

@interface SGIndividualPlanPageController : SGPage
@end

@implementation SGIndividualPlanPageController
- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Your Premium";
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 90;
    self.tableView.allowsSelection = NO;
    // The fallback presentation has no preceding page to supply a back button.
    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closePlan)];
    }
}
- (void)closePlan { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 1 : 5; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Subscription" : @"Snapshot of your benefits";
}
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = UIColor.whiteColor;
    header.textLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    header.textLabel.text = section == 0 ? @"Subscription" : @"Snapshot of your benefits";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:0.125 alpha:1];
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.textProperties.color = UIColor.whiteColor;
    content.textProperties.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.color = [UIColor colorWithWhite:0.75 alpha:1];
    content.secondaryTextProperties.font = [UIFont systemFontOfSize:15];
    content.secondaryTextProperties.numberOfLines = 0;
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(20, 16, 20, 16);
    content.textToSecondaryTextVerticalPadding = 8;
    if (indexPath.section == 0) {
        content.text = @"Premium Individual";
        content.secondaryText = @"1 Individual account\nMusic, your way.\n\nLocal plan preview provided by the mod. This does not change your Spotify subscription or billing.";
        content.image = [UIImage systemImageNamed:@"person.fill"];
    } else {
        NSArray *titles = @[@"Ad-free music listening", @"Download to listen offline", @"Play songs in any order", @"Unlimited skips", @"High-quality audio"];
        NSArray *details = @[@"Enjoy music without ad interruptions.", @"Take your music with you, even without an internet connection.", @"Choose the songs you want to hear, when you want to hear them.", @"Skip to your next favorite song.", @"Listen with higher audio quality where available."];
        NSArray *symbols = @[@"speaker.wave.2.fill", @"arrow.down.circle", @"play.circle", @"forward.end.fill", @"waveform"];
        content.text = titles[indexPath.row];
        content.secondaryText = details[indexPath.row];
        content.image = [UIImage systemImageNamed:symbols[indexPath.row]];
    }
    content.imageProperties.tintColor = [UIColor colorWithRed:0.12 green:0.84 blue:0.38 alpha:1];
    content.imageProperties.maximumSize = CGSizeMake(28, 28);
    cell.contentConfiguration = content;
    return cell;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 1 ? @"Premium benefit overview. Availability depends on your actual Spotify account; this page does not unlock server-side features." : nil;
}
@end

UIViewController *SGIndividualPlanPage(void) { return [SGIndividualPlanPageController new]; }

@interface SGPlanButton : UIButton
@end
@implementation SGPlanButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.accessibilityLabel = @"Your plan, Individual";
        [self addTarget:self action:@selector(openPlan) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (void)openPlan {
    UIViewController *owner = nil;
    for (UIResponder *r = self.nextResponder; r; r = r.nextResponder) {
        if ([r isKindOfClass:UIViewController.class]) { owner = (UIViewController *)r; break; }
    }
    owner = owner ?: SGTopController();
    if (owner && !owner.presentedViewController) SGShowPage(owner, SGIndividualPlanPage());
}
@end

void SGInstallPlanButton(UIView *row) {
    static char key;
    SGPlanButton *button = objc_getAssociatedObject(row, &key);
    if (!button) {
        button = [[SGPlanButton alloc] initWithFrame:row.bounds];
        button.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(row, &key, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [row addSubview:button];
    }
    button.frame = row.bounds;
    [row bringSubviewToFront:button];
}

static char SGWindowPlanButtonKey;
void SGClearPlanTouch(UIWindow *window) {
    [objc_getAssociatedObject(window, &SGWindowPlanButtonKey) removeFromSuperview];
}
UIView *SGRoutePlanTouch(UIWindow *window, CGPoint point, UIView *hit) {
    BOOL drawer = NO;
    for (UIView *v = hit; v; v = v.superview) {
        if ([NSStringFromClass(v.class) containsString:@"SideDrawer"]) drawer = YES;
    }
    if (!drawer) return hit;
    for (UIView *row = hit; row && row != window; row = row.superview) {
        if (row.bounds.size.height > 140) break;
        __block BOOL plan = NO;
        SGForEachView(row, ^(UIView *v) {
            if ([v isKindOfClass:UILabel.class] &&
                [((UILabel *)v).text isEqualToString:@"Your plan"]) plan = YES;
        });
        if (!plan) continue;
        SGPlanButton *button = objc_getAssociatedObject(window, &SGWindowPlanButtonKey);
        if (!button) button = [[SGPlanButton alloc] initWithFrame:CGRectZero];
        button.frame = [row convertRect:row.bounds toView:window];
        objc_setAssociatedObject(window, &SGWindowPlanButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [window addSubview:button];
        return button;
    }
    return hit;
}
