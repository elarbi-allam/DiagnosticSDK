#import "DiagnosticSDKNetworkHooks+Internal.h"
#import <objc/runtime.h>
#import <os/lock.h>

static const void *DiagnosticSDKCaptureChannelKey = &DiagnosticSDKCaptureChannelKey;
static const void *DiagnosticSDKUploadBodyKey = &DiagnosticSDKUploadBodyKey;
static const void *DiagnosticSDKExcludedTaskKey = &DiagnosticSDKExcludedTaskKey;
static const void *DiagnosticSDKReplayedTaskKey = &DiagnosticSDKReplayedTaskKey;
static const void *DiagnosticSDKExcludedSessionKey = &DiagnosticSDKExcludedSessionKey;
static const void *DiagnosticSDKProxiedSessionKey = &DiagnosticSDKProxiedSessionKey;

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
    os_unfair_lock_lock(&DiagnosticSDKEventObserverLock);
    DiagnosticSDKCurrentEventObserver = eventObserver;
    os_unfair_lock_unlock(&DiagnosticSDKEventObserverLock);
}

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSURLSessionTask diagnosticSDK_installResumeHook];
        [NSURLSession diagnosticSDK_installTaskFactoryHooks];
        [NSURLSession diagnosticSDK_installDelegateProxyHook];
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

+ (void)markSessionAsObservedByDelegateProxy:(NSURLSession *)session {
    DiagnosticSDKSetFlag(session, DiagnosticSDKProxiedSessionKey);
}

+ (BOOL)isSessionObservedByDelegateProxy:(NSURLSession *)session {
    return DiagnosticSDKHasFlag(session, DiagnosticSDKProxiedSessionKey);
}

@end
