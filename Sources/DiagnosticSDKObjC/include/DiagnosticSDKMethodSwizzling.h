#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiagnosticSDKMethodSwizzling : NSObject

/// Swaps the implementation of two class methods (+) safely using the metaclass.
+ (void)swizzleClassMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls;

/// I added this to swap the implementation of two instance methods (-) like viewDidAppear.
+ (void)swizzleInstanceMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls;

@end

NS_ASSUME_NONNULL_END
