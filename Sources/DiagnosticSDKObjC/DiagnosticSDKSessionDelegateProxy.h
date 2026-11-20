#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DiagnosticSDKSessionDelegateProxy : NSProxy <NSURLSessionDataDelegate>

+ (instancetype)proxyWithTarget:(id<NSURLSessionDelegate>)target;

+ (nullable id)unwrappedDelegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END
