#import <UIKit/UIKit.h>

// A local plan overview, not Spotify billing or proof of a paid subscription.
UIViewController *SGIndividualPlanPage(void);
void SGInstallPlanButton(UIView *row);
// Routes a drawer plan touch through a window-owned control, outside row gestures.
UIView *SGRoutePlanTouch(UIWindow *window, CGPoint point, UIView *hit);
void SGClearPlanTouch(UIWindow *window);
