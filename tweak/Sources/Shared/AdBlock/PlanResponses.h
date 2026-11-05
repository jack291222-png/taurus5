#import <Foundation/Foundation.h>

// Local display payloads only. Never modify billing endpoints or account entitlements.
BOOL SGIsPlanResponseURL(NSURL *url);
NSData *SGPatchPlanResponse(NSURL *url, NSData *body);
