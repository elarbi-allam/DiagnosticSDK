#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiagnosticSDKBootstrapper : NSObject

/// Safely initializes the DiagnosticSDK and applies necessary runtime modifications.
/// Should be called manually by the host application at startup.
+ (void)start;

@end

NS_ASSUME_NONNULL_END
