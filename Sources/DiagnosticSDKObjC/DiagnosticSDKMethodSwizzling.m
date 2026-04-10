#import "DiagnosticSDKMethodSwizzling.h"
#import <objc/runtime.h>

@implementation DiagnosticSDKMethodSwizzling

+ (void)swizzleClassMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls {
    // 1. Get the metaclass, because we are swizzling class methods (+), not instance methods (-)
    Class metaClass = object_getClass((id)cls);
    
    Method originalMethod = class_getClassMethod(cls, originalSelector);
    Method swizzledMethod = class_getClassMethod(cls, swizzledSelector);
    
    if (!originalMethod || !swizzledMethod) {
        return;
    }
    
    // 2. Safely attempt to add the method in case it is inherited from a superclass
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
        // 3. If the method already exists, swap their implementations
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@end
