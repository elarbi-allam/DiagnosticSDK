#import "DiagnosticSDKBootstrapper.h"
#import "NSURLSessionConfiguration+DiagnosticSDK.h"

@implementation DiagnosticSDKBootstrapper

+ (void)start {
    // Using dispatch_once guarantees thread-safety and ensures
    // the swizzling is applied exactly once per app lifecycle.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSURLSessionConfiguration diagnosticSDK_swizzleNSURLSessionClasses];
        [self diagnosticSDK_startSwiftRuntimeIfAvailable];
    });
}

+ (void)diagnosticSDK_startSwiftRuntimeIfAvailable {
    static id swiftRuntimeInstance = nil;

    Class swiftInterceptorClass = NSClassFromString(@"DiagnosticSDKNetworkInterceptor");
    if (!swiftInterceptorClass) {
        swiftInterceptorClass = NSClassFromString(@"DiagnosticSDK.NetworkInterceptor");
    }
    if (!swiftInterceptorClass) { return; }

    id instance = [[swiftInterceptorClass alloc] init];
    if (!instance) { return; }

    SEL startSelector = @selector(start);
    if (![instance respondsToSelector:startSelector]) { return; }

    void (*startImp)(id, SEL) = (void (*)(id, SEL))[instance methodForSelector:startSelector];
    startImp(instance, startSelector);

    // Keep a strong reference to make startup behavior explicit and stable.
    swiftRuntimeInstance = instance;
}

@end
