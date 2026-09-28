#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DiagnosticSDKTaskCaptureChannel) {
    DiagnosticSDKTaskCaptureChannelStateObservation = 0,
    DiagnosticSDKTaskCaptureChannelCompletionHandler,
    DiagnosticSDKTaskCaptureChannelSessionDelegate,
};

@protocol DiagnosticSDKNetworkEventObserving <NSObject>

- (void)networkTaskWillResume:(NSURLSessionTask *)task
    NS_SWIFT_NAME(networkTaskWillResume(_:));

- (void)networkTask:(NSURLSessionTask *)task didReceiveResponseData:(NSData *)data
    NS_SWIFT_NAME(networkTask(_:didReceiveResponseData:));

- (void)networkTask:(NSURLSessionTask *)task
    didCompleteWithResponseBody:(nullable NSData *)responseBody
                          error:(nullable NSError *)error
    NS_SWIFT_NAME(networkTask(_:didCompleteWithResponseBody:error:));

- (void)networkTask:(NSURLSessionTask *)task didCompleteInSessionDelegateWithError:(nullable NSError *)error
    NS_SWIFT_NAME(networkTask(_:didCompleteInSessionDelegateWithError:));

@end

@interface DiagnosticSDKNetworkHooks : NSObject

@property (class, nullable, strong) id<DiagnosticSDKNetworkEventObserving> eventObserver;

+ (void)installHooks;

+ (DiagnosticSDKTaskCaptureChannel)captureChannelForTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(captureChannel(for:));

+ (nullable NSData *)uploadBodyForTask:(NSURLSessionTask *)task
    NS_SWIFT_NAME(uploadBody(for:));

+ (BOOL)isTaskExcludedFromCapture:(NSURLSessionTask *)task
    NS_SWIFT_NAME(isTaskExcludedFromCapture(_:));

+ (void)excludeSessionFromCapture:(NSURLSession *)session
    NS_SWIFT_NAME(excludeSessionFromCapture(_:));

+ (void)markTaskAsReplayed:(NSURLSessionTask *)task
    NS_SWIFT_NAME(markTaskAsReplayed(_:));

+ (BOOL)isTaskReplayed:(NSURLSessionTask *)task
    NS_SWIFT_NAME(isTaskReplayed(_:));

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
