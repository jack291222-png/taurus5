#import "IndividualPlan.h"
#import "Settings/SGPage.h"
#import "Settings/SGPageStyle.h"
#import "Core/SGCore.h"
#import <objc/runtime.h>

@interface SGIndividualPlanPageController : SGPage
@property(nonatomic) BOOL managing;
@end

static UIColor *SGPlanGreen(void) {
    return [UIColor colorWithRed:0.12 green:0.84 blue:0.38 alpha:1];
}
static UILabel *SGPlanText(NSString *text, CGFloat size, UIFontWeight weight, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    return label;
}

@implementation SGIndividualPlanPageController
- (instancetype)init { return [super initWithStyle:UITableViewStylePlain]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.managing ? @"Manage subscription" : @"Your Premium";
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 300;
    self.tableView.allowsSelection = NO;
    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closePlan)];
    }
}
- (void)closePlan { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)managePlan {
    SGIndividualPlanPageController *page = [SGIndividualPlanPageController new];
    page.managing = YES;
    SGShowPage(self, page);
}
- (void)openAccount {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://www.spotify.com/account/"] options:@{} completionHandler:nil];
}
- (void)exploreBenefits {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://www.spotify.com/premium/"] options:@{} completionHandler:nil];
}
- (UIButton *)outlineButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightBold]
    }];
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);
    button.configuration = configuration;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:0.55 alpha:1].CGColor;
    button.layer.cornerRadius = 24;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (UIControl *)managementLink:(NSString *)title subtitle:(NSString *)subtitle action:(SEL)action {
    UIControl *link = [UIControl new];
    link.isAccessibilityElement = YES;
    link.accessibilityTraits = UIAccessibilityTraitButton;
    link.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", title, subtitle];
    [link addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    UIStackView *words = [UIStackView new];
    words.axis = UILayoutConstraintAxisVertical;
    words.spacing = 6;
    words.userInteractionEnabled = NO;
    words.translatesAutoresizingMaskIntoConstraints = NO;
    [words addArrangedSubview:SGPlanText(title, 19, UIFontWeightRegular, UIColor.whiteColor)];
    [words addArrangedSubview:SGPlanText(subtitle, 16, UIFontWeightRegular, UIColor.lightGrayColor)];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.tintColor = UIColor.lightGrayColor;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [link addSubview:words];
    [link addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[
        [words.leadingAnchor constraintEqualToAnchor:link.leadingAnchor],
        [words.topAnchor constraintEqualToAnchor:link.topAnchor constant:4],
        [words.bottomAnchor constraintEqualToAnchor:link.bottomAnchor constant:-4],
        [words.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-12],
        [chevron.trailingAnchor constraintEqualToAnchor:link.trailingAnchor],
        [chevron.centerYAnchor constraintEqualToAnchor:link.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:16],
        [chevron.heightAnchor constraintEqualToConstant:24]
    ]];
    return link;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.managing ? 3 : 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return self.managing ? 16 : (section == 0 ? 24 : 72); }
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [UIView new];
    header.backgroundColor = tableView.backgroundColor;
    if (self.managing || section == 0) return header;
    UILabel *title = SGPlanText(section == 0 ? @"Subscription" : @"Snapshot of your benefits", 22, UIFontWeightBold, UIColor.whiteColor);
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [title.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-16]
    ]];
    return header;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = UIColor.clearColor;
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor colorWithWhite:0.125 alpha:1];
    card.layer.cornerRadius = 8;
    card.clipsToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:card];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
        [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20],
        [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:(!self.managing && indexPath.section == 0 ? 48 : 24)],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    if (self.managing) {
        if (indexPath.section == 0) {
            [stack addArrangedSubview:SGPlanText(@"Premium", 18, UIFontWeightBold, UIColor.whiteColor)];
            [stack addArrangedSubview:SGPlanText(@"Individual", 32, UIFontWeightBold, SGPlanGreen())];
            [stack setCustomSpacing:6 afterView:stack.arrangedSubviews.firstObject];
            [stack setCustomSpacing:24 afterView:stack.arrangedSubviews.lastObject];
            [stack addArrangedSubview:SGPlanText(@"1 Premium account", 16, UIFontWeightRegular, UIColor.lightGrayColor)];
        } else if (indexPath.section == 1) {
            [stack addArrangedSubview:SGPlanText(@"Payment", 22, UIFontWeightBold, UIColor.whiteColor)];
            [stack addArrangedSubview:SGPlanText(@"Manage your Premium plan on web.", 18, UIFontWeightRegular, UIColor.lightGrayColor)];
            [stack addArrangedSubview:[self outlineButton:@"View billing on Spotify" action:@selector(openAccount)]];
        } else {
            [stack addArrangedSubview:SGPlanText(@"Available plans and add-ons", 22, UIFontWeightBold, UIColor.whiteColor)];
            [stack addArrangedSubview:[self managementLink:@"Browse add-ons · New" subtitle:@"Get more from your Premium experience." action:@selector(openAccount)]];
            UIView *divider = [UIView new];
            divider.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
            [divider.heightAnchor constraintEqualToConstant:1].active = YES;
            [stack addArrangedSubview:divider];
            [stack addArrangedSubview:[self managementLink:@"Explore plans" subtitle:@"Affordable options for any situation." action:@selector(exploreBenefits)]];
        }
    } else if (indexPath.section == 0) {
        UIView *tag = [UIView new];
        tag.backgroundColor = [UIColor colorWithWhite:0.20 alpha:1];
        tag.layer.cornerRadius = 8;
        tag.layer.maskedCorners = kCALayerMaxXMaxYCorner;
        tag.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:tag];
        UILabel *caption = SGPlanText(@"Subscription", 17, UIFontWeightBold, UIColor.whiteColor);
        caption.translatesAutoresizingMaskIntoConstraints = NO;
        [tag addSubview:caption];
        [NSLayoutConstraint activateConstraints:@[
            [tag.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
            [tag.topAnchor constraintEqualToAnchor:card.topAnchor],
            [caption.leadingAnchor constraintEqualToAnchor:tag.leadingAnchor constant:16],
            [caption.trailingAnchor constraintEqualToAnchor:tag.trailingAnchor constant:-16],
            [caption.topAnchor constraintEqualToAnchor:tag.topAnchor constant:8],
            [caption.bottomAnchor constraintEqualToAnchor:tag.bottomAnchor constant:-8],
            [tag.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor]
        ]];
        [stack addArrangedSubview:SGPlanText(@"Premium", 18, UIFontWeightBold, UIColor.whiteColor)];
        UILabel *name = SGPlanText(@"Individual", 28, UIFontWeightBold, SGPlanGreen());
        [stack addArrangedSubview:name];
        [stack setCustomSpacing:0 afterView:stack.arrangedSubviews.firstObject];
        [stack setCustomSpacing:16 afterView:name];
        UIStackView *actions = [UIStackView new];
        UIView *spacer = [UIView new];
        [actions addArrangedSubview:spacer];
        [actions addArrangedSubview:[self outlineButton:@"Manage" action:@selector(managePlan)]];
        [stack addArrangedSubview:actions];
    } else {
        NSArray *titles = @[@"Ad-free music listening", @"Download to listen offline", @"Play songs in any order", @"High quality audio", @"Listen with friends in real time", @"Organise listening queue"];
        for (NSString *title in titles) {
            UIStackView *line = [UIStackView new];
            line.axis = UILayoutConstraintAxisHorizontal;
            line.alignment = UIStackViewAlignmentCenter;
            line.spacing = 16;
            UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]];
            check.tintColor = SGPlanGreen();
            check.contentMode = UIViewContentModeScaleAspectFit;
            [check.widthAnchor constraintEqualToConstant:24].active = YES;
            [check.heightAnchor constraintEqualToConstant:24].active = YES;
            [line addArrangedSubview:check];
            [line addArrangedSubview:SGPlanText(title, 17, UIFontWeightSemibold, UIColor.whiteColor)];
            [stack addArrangedSubview:line];
        }
        UIStackView *actions = [UIStackView new];
        [actions addArrangedSubview:[self outlineButton:@"Explore your benefits" action:@selector(exploreBenefits)]];
        [actions addArrangedSubview:[UIView new]];
        [stack addArrangedSubview:actions];
    }
    return cell;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.managing) return section == 2 ? @"You can’t make changes to your plan in the app. Open Spotify’s website for actual billing and subscription details. Individual is a local plan preview, not proof of a paid subscription." : nil;
    return section == 1 ? @"Local plan preview, not your billing status. Benefits depend on your actual Spotify account; this page does not unlock server-side features. Manage shows a local overview; billing details are available on Spotify’s website." : nil;
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
