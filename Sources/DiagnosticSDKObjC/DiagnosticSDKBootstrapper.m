#import "DiagnosticSDKBootstrapper.h"
#import "NSURLSessionConfiguration+DiagnosticSDK.h"
#import "UIViewController+DiagnosticSDK.h"

@implementation DiagnosticSDKBootstrapper

+ (void)start {
    // I use dispatch_once to guarantee thread safety and ensure that
    // method swizzling is applied strictly once during the app's lifecycle.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // Initialize the network interception engine
        [NSURLSessionConfiguration diagnosticSDK_swizzleNSURLSessionClasses];
        
        // Initialize the UI navigation tracker
        [UIViewController diagnostic_swizzleLifecycle];
        
        NSLog(@"✅ [DiagnosticSDK] Network and Navigation interceptors successfully activated.");
    });
}

@end
