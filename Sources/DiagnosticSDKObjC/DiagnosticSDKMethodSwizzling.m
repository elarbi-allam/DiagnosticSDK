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

// I implemented this to handle standard instance methods.
+ (void)swizzleInstanceMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    
    if (!originalMethod || !swizzledMethod) {
        return;
    }
    
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

+ (BOOL)replaceInstanceMethod:(SEL)selector
                      ofClass:(Class)cls
             withBlockFactory:(DiagnosticSDKImplementationBlockFactory)blockFactory {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return NO;
    }

    IMP originalImplementation = method_getImplementation(method);
    IMP replacementImplementation = imp_implementationWithBlock(blockFactory(originalImplementation));

    if (!class_addMethod(cls, selector, replacementImplementation, method_getTypeEncoding(method))) {
        method_setImplementation(method, replacementImplementation);
    }
    return YES;
}

+ (BOOL)replaceClassMethod:(SEL)selector
                   ofClass:(Class)cls
          withBlockFactory:(DiagnosticSDKImplementationBlockFactory)blockFactory {
    return [self replaceInstanceMethod:selector ofClass:object_getClass(cls) withBlockFactory:blockFactory];
}

+ (NSArray<Class> *)classesInheritingFromClass:(Class)baseClass {
    NSMutableArray<Class> *inheritingClasses = [NSMutableArray array];
    unsigned int classCount = 0;
    Class *classList = objc_copyClassList(&classCount);

    for (unsigned int classIndex = 0; classIndex < classCount; classIndex++) {
        if ([self isClass:classList[classIndex] inheritingFromClass:baseClass]) {
            [inheritingClasses addObject:classList[classIndex]];
        }
    }

    free(classList);
    return inheritingClasses;
}

+ (BOOL)doesClass:(Class)cls declareInstanceMethod:(SEL)selector {
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(cls, &methodCount);
    BOOL isDeclared = NO;

    for (unsigned int methodIndex = 0; methodIndex < methodCount && !isDeclared; methodIndex++) {
        isDeclared = sel_isEqual(method_getName(methodList[methodIndex]), selector);
    }

    free(methodList);
    return isDeclared;
}

+ (BOOL)isClass:(Class)candidateClass inheritingFromClass:(Class)baseClass {
    for (Class currentClass = candidateClass; currentClass; currentClass = class_getSuperclass(currentClass)) {
        if (currentClass == baseClass) {
            return YES;
        }
    }
    return NO;
}

@end
