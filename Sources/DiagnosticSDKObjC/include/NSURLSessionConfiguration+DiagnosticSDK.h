#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionConfiguration (DiagnosticSDK)

/// Injects the custom URLProtocol into the app's default and ephemeral session configurations.
+ (void)diagnosticSDK_swizzleNSURLSessionClasses;

@end

NS_ASSUME_NONNULL_END
