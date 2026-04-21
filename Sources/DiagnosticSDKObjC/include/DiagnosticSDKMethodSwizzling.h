#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiagnosticSDKMethodSwizzling : NSObject

+ (void)swizzleClassMethod:(SEL)originalSelector
                withMethod:(SEL)swizzledSelector
                  forClass:(Class)cls;

+ (void)injectProtocolInto:(NSURLSessionConfiguration *)config;

@end

@interface NSURLSessionConfiguration (DiagnosticSDKSwizzle)
+ (NSURLSessionConfiguration *)diagSDK_defaultSessionConfiguration;
+ (NSURLSessionConfiguration *)diagSDK_ephemeralSessionConfiguration;
@end

NS_ASSUME_NONNULL_END
