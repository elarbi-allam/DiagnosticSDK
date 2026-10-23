#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nonnull (^DiagnosticSDKImplementationBlockFactory)(IMP originalImplementation);

@interface DiagnosticSDKMethodSwizzling : NSObject

/// Swaps the implementation of two class methods (+) safely using the metaclass.
+ (void)swizzleClassMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls;

/// Swaps the implementation of two instance methods (-).
+ (void)swizzleInstanceMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls;

+ (BOOL)replaceInstanceMethod:(SEL)selector
                      ofClass:(Class)cls
             withBlockFactory:(DiagnosticSDKImplementationBlockFactory)blockFactory;

+ (BOOL)replaceClassMethod:(SEL)selector
                   ofClass:(Class)cls
          withBlockFactory:(DiagnosticSDKImplementationBlockFactory)blockFactory;

+ (NSArray<Class> *)classesInheritingFromClass:(Class)baseClass;

+ (BOOL)doesClass:(Class)cls declareInstanceMethod:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
