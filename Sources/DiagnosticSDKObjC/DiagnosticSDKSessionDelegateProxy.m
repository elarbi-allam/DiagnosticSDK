#import "DiagnosticSDKSessionDelegateProxy.h"
#import "DiagnosticSDKNetworkHooks.h"
#import <objc/runtime.h>

@implementation DiagnosticSDKSessionDelegateProxy {
    NSObject<NSURLSessionDataDelegate> *_target;
}

+ (instancetype)proxyWithTarget:(id<NSURLSessionDelegate>)target {
    DiagnosticSDKSessionDelegateProxy *proxy = [self alloc];
    proxy->_target = (NSObject<NSURLSessionDataDelegate> *)target;
    return proxy;
}

+ (BOOL)isObservedSelector:(SEL)selector {
    return sel_isEqual(selector, @selector(URLSession:dataTask:didReceiveData:))
        || sel_isEqual(selector, @selector(URLSession:task:didFinishCollectingMetrics:))
        || sel_isEqual(selector, @selector(URLSession:task:didCompleteWithError:));
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [DiagnosticSDKSessionDelegateProxy isObservedSelector:selector] || [_target respondsToSelector:selector];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol {
    return [_target conformsToProtocol:protocol];
}

- (BOOL)isKindOfClass:(Class)cls {
    return [_target isKindOfClass:cls];
}

- (BOOL)isMemberOfClass:(Class)cls {
    return [_target isMemberOfClass:cls];
}

- (NSUInteger)hash {
    return [_target hash];
}

- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}

- (NSString *)description {
    return [_target description];
}

- (NSString *)debugDescription {
    return [_target debugDescription];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:_target];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if ([_target respondsToSelector:_cmd]) {
        [_target URLSession:session dataTask:dataTask didReceiveData:data];
    }
    [DiagnosticSDKNetworkHooks.eventObserver networkTask:dataTask didReceiveResponseData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    if ([_target respondsToSelector:_cmd]) {
        [_target URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
    [DiagnosticSDKNetworkHooks.eventObserver networkTask:task didFinishCollectingMetrics:metrics];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [DiagnosticSDKNetworkHooks.eventObserver networkTaskDidFinishTransfer:task];
    if ([_target respondsToSelector:_cmd]) {
        [_target URLSession:session task:task didCompleteWithError:error];
    }
    [DiagnosticSDKNetworkHooks.eventObserver networkTask:task didCompleteInSessionDelegateWithError:error];
}

@end
