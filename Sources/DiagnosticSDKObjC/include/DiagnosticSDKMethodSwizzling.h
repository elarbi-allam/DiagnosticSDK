#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiagnosticSDKMethodSwizzling : NSObject

/// Swaps the implementation of two instance methods for a given class.
+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector forClass:(Class)cls;

@end

NS_ASSUME_NONNULL_END
