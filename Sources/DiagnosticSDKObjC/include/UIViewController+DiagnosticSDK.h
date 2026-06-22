#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (DiagnosticSDK)

/// Injects screen tracking into the view controller lifecycle.
/// Swizzles `viewDidLoad` and `viewWillAppear:` to keep screen context up to date.
+ (void)diagnostic_swizzleLifecycle;

@end

NS_ASSUME_NONNULL_END
