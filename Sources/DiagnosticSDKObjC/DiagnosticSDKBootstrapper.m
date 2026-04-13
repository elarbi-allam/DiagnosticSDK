#import "DiagnosticSDKBootstrapper.h"
#import "NSURLSessionConfiguration+DiagnosticSDK.h"
// 1. I import the new UIViewController category to enable navigation tracking
#import "UIViewController+DiagnosticSDK.h"

@implementation DiagnosticSDKBootstrapper

+ (void)start {
    // Using dispatch_once guarantees thread-safety and ensures
    // the swizzling is applied exactly once per app lifecycle.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // --- Network Interception ---
        // I use your original method which perfectly handles the NSURLSession swizzling
        [NSURLSessionConfiguration diagnosticSDK_swizzleNSURLSessionClasses];
        
        // --- Navigation Interception ---
        // I trigger the view controller swizzling here to start tracking screen changes
        [UIViewController diagnostic_swizzleViewDidAppear];
        
        NSLog(@"✅ [DIAGNOSTIC SDK] Network and Navigation interceptors are now active.");
    });
}

@end