#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// I created this category to safely swizzle UIViewController lifecycle methods.
/// This allows us to track screen navigation without requiring the host app to write any code.
@interface UIViewController (DiagnosticSDK)

/// Injects our custom navigation tracking logic into the app's view controllers.
+ (void)diagnostic_swizzleViewDidAppear;

@end

NS_ASSUME_NONNULL_END
