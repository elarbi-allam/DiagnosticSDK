#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionConfiguration (DiagnosticSDK)

/// Applies method swizzling to NSURLSessionConfiguration creation methods.
+ (void)diagnosticSDK_swizzleNSURLSessionClasses;

@end

NS_ASSUME_NONNULL_END
