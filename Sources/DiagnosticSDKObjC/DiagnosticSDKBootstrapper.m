#import "DiagnosticSDKBootstrapper.h"
#import "NSURLSessionConfiguration+DiagnosticSDK.h"

@implementation DiagnosticSDKBootstrapper

+ (void)load {
    // The +load method is invoked automatically by the Objective-C runtime when the framework is loaded into memory.
    // Using dispatch_once guarantees thread-safety and ensures the swizzling is applied exactly once per app lifecycle.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSURLSessionConfiguration diagnosticSDK_swizzleNSURLSessionClasses];
    });
}

@end
