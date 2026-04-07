#import "DiagnosticSDKMethodSwizzling.h"
#import <objc/runtime.h>

@implementation DiagnosticSDKMethodSwizzling

+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    
    // Safely attempt to add the method in case it's inherited from a superclass
    BOOL didAddMethod = class_addMethod(cls,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(cls,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@end
