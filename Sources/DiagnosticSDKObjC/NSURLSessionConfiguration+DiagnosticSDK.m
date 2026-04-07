#import "NSURLSessionConfiguration+DiagnosticSDK.h"
#import "DiagnosticSDKMethodSwizzling.h"

@implementation NSURLSessionConfiguration (DiagnosticSDK)

+ (void)diagnosticSDK_swizzleNSURLSessionClasses {
    [DiagnosticSDKMethodSwizzling swizzleMethod:@selector(defaultSessionConfiguration)
                                     withMethod:@selector(diagnosticSDK_defaultSessionConfiguration)
                                       forClass:[NSURLSessionConfiguration class]];
    
    [DiagnosticSDKMethodSwizzling swizzleMethod:@selector(ephemeralSessionConfiguration)
                                     withMethod:@selector(diagnosticSDK_ephemeralSessionConfiguration)
                                       forClass:[NSURLSessionConfiguration class]];
}

#pragma mark - Swizzled Methods

+ (NSURLSessionConfiguration *)diagnosticSDK_defaultSessionConfiguration {
    // Calls the original Apple method due to runtime pointer exchange.
    NSURLSessionConfiguration *config = [self diagnosticSDK_defaultSessionConfiguration];
    [self diagnosticSDK_injectProtocol:config];
    return config;
}

+ (NSURLSessionConfiguration *)diagnosticSDK_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = [self diagnosticSDK_ephemeralSessionConfiguration];
    [self diagnosticSDK_injectProtocol:config];
    return config;
}

#pragma mark - Protocol Injection

+ (void)diagnosticSDK_injectProtocol:(NSURLSessionConfiguration *)config {
    // Dynamically load the Swift protocol class to maintain loose coupling between Obj-C and Swift modules.
    Class interceptorClass = NSClassFromString(@"DiagnosticSDK.NetworkInterceptor");
    
    if (interceptorClass) {
        NSMutableArray *protocols = [NSMutableArray arrayWithArray:config.protocolClasses];
        
        // Insert at index 0 to ensure our protocol evaluates network requests first.
        if (![protocols containsObject:interceptorClass]) {
            [protocols insertObject:interceptorClass atIndex:0];
            config.protocolClasses = protocols;
        }
    } else {
        NSLog(@"[DiagnosticSDK] Warning: Swift NetworkInterceptor class not found. Interception is disabled.");
    }
}

@end
