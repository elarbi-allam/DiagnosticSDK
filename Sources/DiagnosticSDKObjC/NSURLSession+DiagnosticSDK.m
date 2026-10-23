#import "DiagnosticSDKNetworkHooks+Internal.h"
#import "DiagnosticSDKMethodSwizzling.h"
#import "DiagnosticSDKSessionDelegateProxy.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSURLSessionTask *_Nullable (^DiagnosticSDKTaskCreation)(DiagnosticSDKTaskCompletionHandler _Nullable completionHandler);

typedef NSURLSessionTask *_Nullable (*DiagnosticSDKTaskFactory)(id, SEL, id);
typedef NSURLSessionTask *_Nullable (*DiagnosticSDKTaskFactoryWithBody)(id, SEL, id, id);
typedef NSURLSessionTask *_Nullable (*DiagnosticSDKTaskFactoryWithCompletion)(id, SEL, id, DiagnosticSDKTaskCompletionHandler _Nullable);
typedef NSURLSessionTask *_Nullable (*DiagnosticSDKTaskFactoryWithBodyAndCompletion)(id, SEL, id, id, DiagnosticSDKTaskCompletionHandler _Nullable);
typedef NSURLSession *(*DiagnosticSDKSessionFactory)(id, SEL, NSURLSessionConfiguration *, id _Nullable, NSOperationQueue *_Nullable);

@interface DiagnosticSDKWeakTaskReference : NSObject

@property (nonatomic, weak, nullable) NSURLSessionTask *task;

@end

@implementation DiagnosticSDKWeakTaskReference
@end

static NSData *_Nullable DiagnosticSDKUploadBodyFromArgument(id _Nullable bodyOrFileURL) {
    return [bodyOrFileURL isKindOfClass:[NSData class]] ? bodyOrFileURL : nil;
}

static void DiagnosticSDKClassifyTaskWithoutCompletionHandler(NSURLSession *session, NSURLSessionTask *task) {
    if ([DiagnosticSDKNetworkHooks isSessionExcludedFromCapture:session]) {
        [DiagnosticSDKNetworkHooks excludeTaskFromCapture:task];
    } else if ([DiagnosticSDKNetworkHooks isSessionObservedByDelegateProxy:session]) {
        [DiagnosticSDKNetworkHooks assignCaptureChannel:DiagnosticSDKTaskCaptureChannelSessionDelegate toTask:task];
    }
}

static DiagnosticSDKTaskCompletionHandler DiagnosticSDKObservingCompletionHandler(DiagnosticSDKTaskCompletionHandler completionHandler,
                                                                                   DiagnosticSDKWeakTaskReference *taskReference) {
    return ^(id _Nullable payload, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        NSURLSessionTask *completedTask = taskReference.task;
        if (completedTask) {
            [DiagnosticSDKNetworkHooks.eventObserver networkTaskDidFinishTransfer:completedTask];
        }

        completionHandler(payload, response, error);

        if (!completedTask) {
            return;
        }
        NSData *responseBody = [payload isKindOfClass:[NSData class]] ? payload : nil;
        [DiagnosticSDKNetworkHooks.eventObserver networkTask:completedTask didCompleteWithResponseBody:responseBody error:error];
    };
}

static NSURLSessionTask *_Nullable DiagnosticSDKCreateObservedTask(NSURLSession *session,
                                                                   DiagnosticSDKTaskCompletionHandler _Nullable completionHandler,
                                                                   NSData *_Nullable uploadBody,
                                                                   DiagnosticSDKTaskCreation createTask) {
    BOOL isObservable = completionHandler && ![DiagnosticSDKNetworkHooks isSessionExcludedFromCapture:session];
    DiagnosticSDKWeakTaskReference *taskReference = [DiagnosticSDKWeakTaskReference new];

    NSURLSessionTask *task = createTask(isObservable
                                        ? DiagnosticSDKObservingCompletionHandler(completionHandler, taskReference)
                                        : completionHandler);
    if (!task) {
        return nil;
    }

    if (isObservable) {
        taskReference.task = task;
        [DiagnosticSDKNetworkHooks assignCaptureChannel:DiagnosticSDKTaskCaptureChannelCompletionHandler toTask:task];
    } else {
        DiagnosticSDKClassifyTaskWithoutCompletionHandler(session, task);
    }

    if (uploadBody) {
        [DiagnosticSDKNetworkHooks attachUploadBody:uploadBody toTask:task];
    }
    return task;
}

@implementation NSURLSession (DiagnosticSDKNetworkHooks)

+ (void)diagnosticSDK_installTaskFactoryHooks {
    NSArray<Class> *sessionClasses = [DiagnosticSDKMethodSwizzling classesInheritingFromClass:[NSURLSession class]];

    SEL taskFactorySelectors[] = {
        @selector(dataTaskWithRequest:),
        @selector(dataTaskWithURL:),
        @selector(uploadTaskWithStreamedRequest:),
        @selector(downloadTaskWithRequest:),
        @selector(downloadTaskWithURL:),
        @selector(downloadTaskWithResumeData:),
    };
    for (size_t index = 0; index < sizeof(taskFactorySelectors) / sizeof(SEL); index++) {
        [self diagnosticSDK_hookTaskFactory:taskFactorySelectors[index] inClasses:sessionClasses];
    }

    SEL taskFactoryWithBodySelectors[] = {
        @selector(uploadTaskWithRequest:fromData:),
        @selector(uploadTaskWithRequest:fromFile:),
    };
    for (size_t index = 0; index < sizeof(taskFactoryWithBodySelectors) / sizeof(SEL); index++) {
        [self diagnosticSDK_hookTaskFactoryWithBody:taskFactoryWithBodySelectors[index] inClasses:sessionClasses];
    }

    SEL taskFactoryWithCompletionSelectors[] = {
        @selector(dataTaskWithRequest:completionHandler:),
        @selector(dataTaskWithURL:completionHandler:),
        @selector(downloadTaskWithRequest:completionHandler:),
        @selector(downloadTaskWithURL:completionHandler:),
        @selector(downloadTaskWithResumeData:completionHandler:),
    };
    for (size_t index = 0; index < sizeof(taskFactoryWithCompletionSelectors) / sizeof(SEL); index++) {
        [self diagnosticSDK_hookTaskFactoryWithCompletion:taskFactoryWithCompletionSelectors[index] inClasses:sessionClasses];
    }

    SEL taskFactoryWithBodyAndCompletionSelectors[] = {
        @selector(uploadTaskWithRequest:fromData:completionHandler:),
        @selector(uploadTaskWithRequest:fromFile:completionHandler:),
    };
    for (size_t index = 0; index < sizeof(taskFactoryWithBodyAndCompletionSelectors) / sizeof(SEL); index++) {
        [self diagnosticSDK_hookTaskFactoryWithBodyAndCompletion:taskFactoryWithBodyAndCompletionSelectors[index]
                                                       inClasses:sessionClasses];
    }
}

+ (void)diagnosticSDK_installDelegateProxyHook {
    SEL sessionFactorySelector = @selector(sessionWithConfiguration:delegate:delegateQueue:);

    [DiagnosticSDKMethodSwizzling replaceClassMethod:sessionFactorySelector
                                             ofClass:[NSURLSession class]
                                    withBlockFactory:^id(IMP originalImplementation) {
        return ^NSURLSession *(Class sessionClass,
                               NSURLSessionConfiguration *configuration,
                               id<NSURLSessionDelegate> _Nullable delegate,
                               NSOperationQueue *_Nullable delegateQueue) {
            id<NSURLSessionDelegate> observedDelegate = delegate
                ? [DiagnosticSDKSessionDelegateProxy proxyWithTarget:delegate]
                : nil;
            NSURLSession *session = ((DiagnosticSDKSessionFactory)originalImplementation)(sessionClass,
                                                                                          sessionFactorySelector,
                                                                                          configuration,
                                                                                          observedDelegate,
                                                                                          delegateQueue);
            if (observedDelegate) {
                [DiagnosticSDKNetworkHooks markSessionAsObservedByDelegateProxy:session];
            }
            return session;
        };
    }];
}

+ (void)diagnosticSDK_hookSelector:(SEL)selector
                         inClasses:(NSArray<Class> *)sessionClasses
                  withBlockFactory:(DiagnosticSDKImplementationBlockFactory)blockFactory {
    for (Class sessionClass in sessionClasses) {
        if ([DiagnosticSDKMethodSwizzling doesClass:sessionClass declareInstanceMethod:selector]) {
            [DiagnosticSDKMethodSwizzling replaceInstanceMethod:selector ofClass:sessionClass withBlockFactory:blockFactory];
        }
    }
}

+ (void)diagnosticSDK_hookTaskFactory:(SEL)selector inClasses:(NSArray<Class> *)sessionClasses {
    [self diagnosticSDK_hookSelector:selector inClasses:sessionClasses withBlockFactory:^id(IMP originalImplementation) {
        return ^NSURLSessionTask *_Nullable (NSURLSession *session, id argument) {
            return DiagnosticSDKCreateObservedTask(session, nil, nil, ^NSURLSessionTask *_Nullable (DiagnosticSDKTaskCompletionHandler _Nullable completionHandler) {
                return ((DiagnosticSDKTaskFactory)originalImplementation)(session, selector, argument);
            });
        };
    }];
}

+ (void)diagnosticSDK_hookTaskFactoryWithBody:(SEL)selector inClasses:(NSArray<Class> *)sessionClasses {
    [self diagnosticSDK_hookSelector:selector inClasses:sessionClasses withBlockFactory:^id(IMP originalImplementation) {
        return ^NSURLSessionTask *_Nullable (NSURLSession *session, id request, id bodyOrFileURL) {
            return DiagnosticSDKCreateObservedTask(session, nil, DiagnosticSDKUploadBodyFromArgument(bodyOrFileURL), ^NSURLSessionTask *_Nullable (DiagnosticSDKTaskCompletionHandler _Nullable completionHandler) {
                return ((DiagnosticSDKTaskFactoryWithBody)originalImplementation)(session, selector, request, bodyOrFileURL);
            });
        };
    }];
}

+ (void)diagnosticSDK_hookTaskFactoryWithCompletion:(SEL)selector inClasses:(NSArray<Class> *)sessionClasses {
    [self diagnosticSDK_hookSelector:selector inClasses:sessionClasses withBlockFactory:^id(IMP originalImplementation) {
        return ^NSURLSessionTask *_Nullable (NSURLSession *session, id argument, DiagnosticSDKTaskCompletionHandler _Nullable originalCompletionHandler) {
            return DiagnosticSDKCreateObservedTask(session, originalCompletionHandler, nil, ^NSURLSessionTask *_Nullable (DiagnosticSDKTaskCompletionHandler _Nullable completionHandler) {
                return ((DiagnosticSDKTaskFactoryWithCompletion)originalImplementation)(session, selector, argument, completionHandler);
            });
        };
    }];
}

+ (void)diagnosticSDK_hookTaskFactoryWithBodyAndCompletion:(SEL)selector inClasses:(NSArray<Class> *)sessionClasses {
    [self diagnosticSDK_hookSelector:selector inClasses:sessionClasses withBlockFactory:^id(IMP originalImplementation) {
        return ^NSURLSessionTask *_Nullable (NSURLSession *session, id request, id bodyOrFileURL, DiagnosticSDKTaskCompletionHandler _Nullable originalCompletionHandler) {
            return DiagnosticSDKCreateObservedTask(session, originalCompletionHandler, DiagnosticSDKUploadBodyFromArgument(bodyOrFileURL), ^NSURLSessionTask *_Nullable (DiagnosticSDKTaskCompletionHandler _Nullable completionHandler) {
                return ((DiagnosticSDKTaskFactoryWithBodyAndCompletion)originalImplementation)(session, selector, request, bodyOrFileURL, completionHandler);
            });
        };
    }];
}

@end

NS_ASSUME_NONNULL_END
