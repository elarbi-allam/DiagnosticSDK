#import "DiagnosticSDKNetworkHooks+Internal.h"
#import "DiagnosticSDKMethodSwizzling.h"
#import <objc/runtime.h>
#import <os/lock.h>

typedef void (*DiagnosticSDKStartLoadingImplementation)(id, SEL);
typedef id _Nullable (*DiagnosticSDKURLProtocolTaskInitializer)(id, SEL, NSURLSessionTask *, NSCachedURLResponse *_Nullable, id<NSURLProtocolClient>);
typedef id _Nullable (*DiagnosticSDKURLProtocolRequestInitializer)(id, SEL, NSURLRequest *, NSCachedURLResponse *_Nullable, id<NSURLProtocolClient>);

static os_unfair_lock DiagnosticSDKStartLoadingHookLock = OS_UNFAIR_LOCK_INIT;
static NSMutableSet<Class> *DiagnosticSDKInspectedProtocolClasses;

static BOOL DiagnosticSDKIsSystemClass(Class protocolClass) {
    const char *imageName = class_getImageName(protocolClass);
    if (!imageName) {
        return YES;
    }
    NSString *imagePath = @(imageName);
    return [imagePath containsString:@"/System/Library/"] || [imagePath containsString:@"/usr/lib/"];
}

static void DiagnosticSDKHookStartLoadingOfClass(Class protocolClass) {
    SEL startLoadingSelector = @selector(startLoading);
    [DiagnosticSDKMethodSwizzling replaceInstanceMethod:startLoadingSelector
                                                ofClass:protocolClass
                                       withBlockFactory:^id(IMP originalImplementation) {
        return ^(NSURLProtocol *protocol) {
            NSURLSessionTask *deliveredTask = protocol.task;
            if (deliveredTask) {
                [DiagnosticSDKNetworkHooks markTask:deliveredTask asDeliveredByURLProtocolClass:[protocol class]];
            }
            [DiagnosticSDKNetworkHooks beginLoadingOfTaskByURLProtocol:deliveredTask];
            @try {
                ((DiagnosticSDKStartLoadingImplementation)originalImplementation)(protocol, startLoadingSelector);
            } @finally {
                [DiagnosticSDKNetworkHooks endLoadingOfTaskByURLProtocol];
            }
        };
    }];
}

static void DiagnosticSDKEnsureStartLoadingHooksForHierarchyOfClass(Class protocolClass) {
    os_unfair_lock_lock(&DiagnosticSDKStartLoadingHookLock);
    for (Class currentClass = protocolClass; currentClass && currentClass != [NSURLProtocol class]; currentClass = class_getSuperclass(currentClass)) {
        if ([DiagnosticSDKInspectedProtocolClasses containsObject:currentClass]) {
            continue;
        }
        [DiagnosticSDKInspectedProtocolClasses addObject:currentClass];
        if (!DiagnosticSDKIsSystemClass(currentClass)
            && [DiagnosticSDKMethodSwizzling doesClass:currentClass declareInstanceMethod:@selector(startLoading)]) {
            DiagnosticSDKHookStartLoadingOfClass(currentClass);
        }
    }
    os_unfair_lock_unlock(&DiagnosticSDKStartLoadingHookLock);
}

@implementation NSURLProtocol (DiagnosticSDKNetworkHooks)

+ (void)diagnosticSDK_installStartLoadingHooks {
    DiagnosticSDKInspectedProtocolClasses = [NSMutableSet set];

    SEL taskInitializerSelector = @selector(initWithTask:cachedResponse:client:);
    [DiagnosticSDKMethodSwizzling replaceInstanceMethod:taskInitializerSelector
                                                ofClass:[NSURLProtocol class]
                                       withBlockFactory:^id(IMP originalImplementation) {
        return ^id _Nullable (NSURLProtocol *protocol, NSURLSessionTask *task, NSCachedURLResponse *_Nullable cachedResponse, id<NSURLProtocolClient> client) {
            DiagnosticSDKEnsureStartLoadingHooksForHierarchyOfClass(object_getClass(protocol));
            return ((DiagnosticSDKURLProtocolTaskInitializer)originalImplementation)(protocol, taskInitializerSelector, task, cachedResponse, client);
        };
    }];

    SEL requestInitializerSelector = @selector(initWithRequest:cachedResponse:client:);
    [DiagnosticSDKMethodSwizzling replaceInstanceMethod:requestInitializerSelector
                                                ofClass:[NSURLProtocol class]
                                       withBlockFactory:^id(IMP originalImplementation) {
        return ^id _Nullable (NSURLProtocol *protocol, NSURLRequest *request, NSCachedURLResponse *_Nullable cachedResponse, id<NSURLProtocolClient> client) {
            DiagnosticSDKEnsureStartLoadingHooksForHierarchyOfClass(object_getClass(protocol));
            return ((DiagnosticSDKURLProtocolRequestInitializer)originalImplementation)(protocol, requestInitializerSelector, request, cachedResponse, client);
        };
    }];
}

@end
