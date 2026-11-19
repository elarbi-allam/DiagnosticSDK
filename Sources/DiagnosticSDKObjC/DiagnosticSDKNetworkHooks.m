#import "DiagnosticSDKNetworkHooks+Internal.h"
#import <objc/runtime.h>
#import <os/lock.h>

static const void *DiagnosticSDKCaptureChannelKey = &DiagnosticSDKCaptureChannelKey;
static const void *DiagnosticSDKUploadBodyKey = &DiagnosticSDKUploadBodyKey;
static const void *DiagnosticSDKExcludedTaskKey = &DiagnosticSDKExcludedTaskKey;
static const void *DiagnosticSDKReplayedTaskKey = &DiagnosticSDKReplayedTaskKey;
static const void *DiagnosticSDKExcludedSessionKey = &DiagnosticSDKExcludedSessionKey;
static const void *DiagnosticSDKProxiedSessionKey = &DiagnosticSDKProxiedSessionKey;
static const void *DiagnosticSDKRelayOriginTaskKey = &DiagnosticSDKRelayOriginTaskKey;
static const void *DiagnosticSDKDeliveringURLProtocolNameKey = &DiagnosticSDKDeliveringURLProtocolNameKey;
static NSString *const DiagnosticSDKURLProtocolLoadingTasksThreadKey = @"com.diagnosticsdk.urlprotocol.loadingTasks";
static const NSUInteger DiagnosticSDKMaximumRelayDepth = 8;

static os_unfair_lock DiagnosticSDKEventObserverLock = OS_UNFAIR_LOCK_INIT;
static id<DiagnosticSDKNetworkEventObserving> DiagnosticSDKCurrentEventObserver = nil;

static void DiagnosticSDKSetFlag(id object, const void *key) {
    objc_setAssociatedObject(object, key, @YES, OBJC_ASSOCIATION_RETAIN);
}

static BOOL DiagnosticSDKHasFlag(id object, const void *key) {
    return [objc_getAssociatedObject(object, key) boolValue];
}

@implementation DiagnosticSDKNetworkHooks

+ (id<DiagnosticSDKNetworkEventObserving>)eventObserver {
    os_unfair_lock_lock(&DiagnosticSDKEventObserverLock);
    id<DiagnosticSDKNetworkEventObserving> eventObserver = DiagnosticSDKCurrentEventObserver;
    os_unfair_lock_unlock(&DiagnosticSDKEventObserverLock);
    return eventObserver;
}

+ (void)setEventObserver:(id<DiagnosticSDKNetworkEventObserving>)eventObserver {
    __attribute__((objc_precise_lifetime)) id<DiagnosticSDKNetworkEventObserving> replacedEventObserver = nil;
    os_unfair_lock_lock(&DiagnosticSDKEventObserverLock);
    replacedEventObserver = DiagnosticSDKCurrentEventObserver;
    DiagnosticSDKCurrentEventObserver = eventObserver;
    os_unfair_lock_unlock(&DiagnosticSDKEventObserverLock);
}

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSURLSessionTask diagnosticSDK_installResumeHook];
        [NSURLSession diagnosticSDK_installTaskFactoryHooks];
        [NSURLSession diagnosticSDK_installDelegateProxyHook];
        [NSURLProtocol diagnosticSDK_installStartLoadingHooks];
    });
}

+ (DiagnosticSDKTaskCaptureChannel)captureChannelForTask:(NSURLSessionTask *)task {
    NSNumber *storedChannel = objc_getAssociatedObject(task, DiagnosticSDKCaptureChannelKey);
    if (!storedChannel) {
        return DiagnosticSDKTaskCaptureChannelStateObservation;
    }
    return (DiagnosticSDKTaskCaptureChannel)storedChannel.integerValue;
}

+ (void)assignCaptureChannel:(DiagnosticSDKTaskCaptureChannel)channel toTask:(NSURLSessionTask *)task {
    objc_setAssociatedObject(task, DiagnosticSDKCaptureChannelKey, @(channel), OBJC_ASSOCIATION_RETAIN);
}

+ (NSData *)uploadBodyForTask:(NSURLSessionTask *)task {
    return objc_getAssociatedObject(task, DiagnosticSDKUploadBodyKey);
}

+ (void)attachUploadBody:(NSData *)uploadBody toTask:(NSURLSessionTask *)task {
    objc_setAssociatedObject(task, DiagnosticSDKUploadBodyKey, uploadBody, OBJC_ASSOCIATION_COPY);
}

+ (BOOL)isTaskExcludedFromCapture:(NSURLSessionTask *)task {
    return DiagnosticSDKHasFlag(task, DiagnosticSDKExcludedTaskKey);
}

+ (void)excludeTaskFromCapture:(NSURLSessionTask *)task {
    DiagnosticSDKSetFlag(task, DiagnosticSDKExcludedTaskKey);
}

+ (void)excludeSessionFromCapture:(NSURLSession *)session {
    DiagnosticSDKSetFlag(session, DiagnosticSDKExcludedSessionKey);
}

+ (BOOL)isSessionExcludedFromCapture:(NSURLSession *)session {
    return DiagnosticSDKHasFlag(session, DiagnosticSDKExcludedSessionKey);
}

+ (void)markTaskAsReplayed:(NSURLSessionTask *)task {
    DiagnosticSDKSetFlag(task, DiagnosticSDKReplayedTaskKey);
}

+ (BOOL)isTaskReplayed:(NSURLSessionTask *)task {
    return DiagnosticSDKHasFlag(task, DiagnosticSDKReplayedTaskKey);
}

+ (void)markTask:(NSURLSessionTask *)task asDeliveredByURLProtocolClass:(Class)protocolClass {
    objc_setAssociatedObject(task, DiagnosticSDKDeliveringURLProtocolNameKey, NSStringFromClass(protocolClass), OBJC_ASSOCIATION_COPY);
}

+ (nullable NSString *)deliveringURLProtocolNameForTask:(NSURLSessionTask *)task {
    return objc_getAssociatedObject(task, DiagnosticSDKDeliveringURLProtocolNameKey);
}

+ (NSMutableArray *)urlProtocolLoadingTasksOfCurrentThread {
    NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
    NSMutableArray *loadingTasks = threadDictionary[DiagnosticSDKURLProtocolLoadingTasksThreadKey];
    if (!loadingTasks) {
        loadingTasks = [NSMutableArray array];
        threadDictionary[DiagnosticSDKURLProtocolLoadingTasksThreadKey] = loadingTasks;
    }
    return loadingTasks;
}

+ (void)beginLoadingOfTaskByURLProtocol:(nullable NSURLSessionTask *)task {
    [[self urlProtocolLoadingTasksOfCurrentThread] addObject:task ?: (id)NSNull.null];
}

+ (void)endLoadingOfTaskByURLProtocol {
    [[self urlProtocolLoadingTasksOfCurrentThread] removeLastObject];
}

+ (void)linkRelayTaskToLoadingURLProtocolTaskIfNeeded:(NSURLSessionTask *)task {
    NSURLSessionTask *loadingTask = [[self urlProtocolLoadingTasksOfCurrentThread] lastObject];
    if (![loadingTask isKindOfClass:[NSURLSessionTask class]] || loadingTask == task) {
        return;
    }
    DiagnosticSDKWeakTaskReference *originReference = [DiagnosticSDKWeakTaskReference new];
    originReference.task = loadingTask;
    objc_setAssociatedObject(task, DiagnosticSDKRelayOriginTaskKey, originReference, OBJC_ASSOCIATION_RETAIN);
}

+ (nullable NSURLSessionTask *)relayOriginTaskForTask:(NSURLSessionTask *)task {
    NSURLSessionTask *originTask = nil;
    NSURLSessionTask *currentTask = task;
    for (NSUInteger depth = 0; depth < DiagnosticSDKMaximumRelayDepth; depth++) {
        DiagnosticSDKWeakTaskReference *originReference = objc_getAssociatedObject(currentTask, DiagnosticSDKRelayOriginTaskKey);
        NSURLSessionTask *nextOriginTask = originReference.task;
        if (!nextOriginTask) {
            break;
        }
        originTask = nextOriginTask;
        currentTask = nextOriginTask;
    }
    return originTask;
}

+ (void)markSessionAsObservedByDelegateProxy:(NSURLSession *)session {
    DiagnosticSDKSetFlag(session, DiagnosticSDKProxiedSessionKey);
}

+ (BOOL)isSessionObservedByDelegateProxy:(NSURLSession *)session {
    return DiagnosticSDKHasFlag(session, DiagnosticSDKProxiedSessionKey);
}

@end
