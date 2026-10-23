#import "DiagnosticSDKNetworkHooks.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^DiagnosticSDKTaskCompletionHandler)(id _Nullable payload,
                                                   NSURLResponse *_Nullable response,
                                                   NSError *_Nullable error);

@interface DiagnosticSDKNetworkHooks (Internal)

+ (void)assignCaptureChannel:(DiagnosticSDKTaskCaptureChannel)channel toTask:(NSURLSessionTask *)task;
+ (void)attachUploadBody:(NSData *)uploadBody toTask:(NSURLSessionTask *)task;
+ (void)excludeTaskFromCapture:(NSURLSessionTask *)task;
+ (BOOL)isSessionExcludedFromCapture:(NSURLSession *)session;
+ (void)markSessionAsObservedByDelegateProxy:(NSURLSession *)session;
+ (BOOL)isSessionObservedByDelegateProxy:(NSURLSession *)session;

@end

@interface NSURLSessionTask (DiagnosticSDKNetworkHooks)

+ (void)diagnosticSDK_installResumeHook;

@end

@interface NSURLSession (DiagnosticSDKNetworkHooks)

+ (void)diagnosticSDK_installTaskFactoryHooks;
+ (void)diagnosticSDK_installDelegateProxyHook;

@end

NS_ASSUME_NONNULL_END
