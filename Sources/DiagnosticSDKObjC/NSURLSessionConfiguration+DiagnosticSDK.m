#import "NSURLSessionConfiguration+DiagnosticSDK.h"
#import "DiagnosticSDKMethodSwizzling.h"

@implementation NSURLSessionConfiguration (DiagnosticSDK)

+ (void)diagnosticSDK_swizzleNSURLSessionClasses {
    [DiagnosticSDKMethodSwizzling swizzleClassMethod:@selector(defaultSessionConfiguration)
                                          withMethod:@selector(diagnosticSDK_defaultSessionConfiguration)
                                            forClass:[NSURLSessionConfiguration class]];
    
    [DiagnosticSDKMethodSwizzling swizzleClassMethod:@selector(ephemeralSessionConfiguration)
                                          withMethod:@selector(diagnosticSDK_ephemeralSessionConfiguration)
                                            forClass:[NSURLSessionConfiguration class]];
}

#pragma mark - Swizzled Methods

+ (NSURLSessionConfiguration *)diagnosticSDK_defaultSessionConfiguration {
    // This calls Apple's original implementation due to the method exchange.
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
    // Dynamically resolve the Swift interceptor class.
    Class interceptorClass = NSClassFromString(@"DiagnosticURLProtocol");
    
    if (interceptorClass) {
        NSMutableArray *protocols = [NSMutableArray arrayWithArray:config.protocolClasses];
        
        // Insert at index 0 to ensure the interceptor evaluates requests before Apple's default protocols.
        if (![protocols containsObject:interceptorClass]) {
            [protocols insertObject:interceptorClass atIndex:0];
            config.protocolClasses = protocols;
        }
    }
}

@end
