#import "DiagnosticSDKMethodSwizzling.h"
#import <objc/runtime.h>

@implementation DiagnosticSDKMethodSwizzling

// ─── Runs automatically before main() ───────────────────────────
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleClassMethod:@selector(defaultSessionConfiguration)
                      withMethod:@selector(diagSDK_defaultSessionConfiguration)
                        forClass:[NSURLSessionConfiguration class]];

        [self swizzleClassMethod:@selector(ephemeralSessionConfiguration)
                      withMethod:@selector(diagSDK_ephemeralSessionConfiguration)
                        forClass:[NSURLSessionConfiguration class]];
    });
}

// ─── Your existing helper — unchanged ───────────────────────────
+ (void)swizzleClassMethod:(SEL)originalSelector
                withMethod:(SEL)swizzledSelector
                  forClass:(Class)cls {

    Class metaClass = object_getClass((id)cls);

    Method originalMethod = class_getClassMethod(cls, originalSelector);
    Method swizzledMethod = class_getClassMethod(cls, swizzledSelector);

    if (!originalMethod || !swizzledMethod) { return; }

    BOOL didAddMethod = class_addMethod(metaClass,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(metaClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

// ─── Injects CustomURLProtocol into any session configuration ───
+ (void)injectProtocolInto:(NSURLSessionConfiguration *)config {
    Class customProtocol = NSClassFromString(@"DiagnosticURLProtocol");
    if (!customProtocol) { return; }

    NSMutableArray *protocols = [NSMutableArray
        arrayWithArray:config.protocolClasses ?: @[]];

    if (![protocols containsObject:customProtocol]) {
        [protocols insertObject:customProtocol atIndex:0];
        config.protocolClasses = protocols;
    }
}

@end


// ─── Replacement implementations ────────────────────────────────
@implementation NSURLSessionConfiguration (DiagnosticSDKSwizzle)

+ (NSURLSessionConfiguration *)diagSDK_defaultSessionConfiguration {
    // Not recursive — implementations are swapped,
    // so this actually calls Apple's original method.
    NSURLSessionConfiguration *config =
        [self diagSDK_defaultSessionConfiguration];
    [DiagnosticSDKMethodSwizzling injectProtocolInto:config];
    return config;
}

+ (NSURLSessionConfiguration *)diagSDK_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config =
        [self diagSDK_ephemeralSessionConfiguration];
    [DiagnosticSDKMethodSwizzling injectProtocolInto:config];
    return config;
}

@end
