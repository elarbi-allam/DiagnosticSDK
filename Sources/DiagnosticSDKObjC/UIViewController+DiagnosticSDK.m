#import "UIViewController+DiagnosticSDK.h"
#import "DiagnosticSDKMethodSwizzling.h"

@implementation UIViewController (DiagnosticSDK)

+ (void)diagnostic_swizzleViewDidAppear {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // I use instance method swizzling here since viewDidAppear: is an instance method.
        [DiagnosticSDKMethodSwizzling swizzleInstanceMethod:@selector(viewDidAppear:)
                                                 withMethod:@selector(diagnostic_viewDidAppear:)
                                                   forClass:[self class]];
    });
}

- (void)diagnostic_viewDidAppear:(BOOL)animated {
    NSString *screenName = NSStringFromClass([self class]);
    
    // I filter out Apple's internal system views (e.g., keyboards, navigation containers)
    // to ensure I only track the actual screens created by the host application.
    if (![screenName hasPrefix:@"UI"] && ![screenName hasPrefix:@"_UI"]) {
        
        // I use dynamic class resolution here to avoid direct Swift imports,
        // keeping this Obj-C module fully decoupled and SPM-compatible.
        Class contextClass = NSClassFromString(@"DiagnosticSDK.DiagnosticContext");
        if (contextClass) {
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            SEL sharedSelector = NSSelectorFromString(@"shared");
            if ([contextClass respondsToSelector:sharedSelector]) {
                id sharedContext = [contextClass performSelector:sharedSelector];
                
                SEL updateSelector = NSSelectorFromString(@"updateCurrentScreen:");
                if ([sharedContext respondsToSelector:updateSelector]) {
                    [sharedContext performSelector:updateSelector withObject:screenName];
                }
            }
            
#pragma clang diagnostic pop
        }
    }
    
    // I call the original method to ensure the standard app lifecycle continues normally.
    [self diagnostic_viewDidAppear:animated];
}

@end
