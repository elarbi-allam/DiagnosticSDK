#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (DiagnosticSDK)

/// I implemented this method to inject our screen tracking logic into the application's lifecycle.
/// It targets both 'viewDidLoad' and 'viewWillAppear:' to ensure we capture early network requests
/// as well as reverse navigation (e.g., popping a view controller).
+ (void)diagnostic_swizzleLifecycle;

@end

NS_ASSUME_NONNULL_END
