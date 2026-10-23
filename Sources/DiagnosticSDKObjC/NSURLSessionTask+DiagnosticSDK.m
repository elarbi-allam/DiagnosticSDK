#import "DiagnosticSDKNetworkHooks+Internal.h"
#import "DiagnosticSDKMethodSwizzling.h"

typedef void (*DiagnosticSDKResumeImplementation)(id, SEL);

@implementation NSURLSessionTask (DiagnosticSDKNetworkHooks)

+ (void)diagnosticSDK_installResumeHook {
    SEL resumeSelector = @selector(resume);

    for (Class taskClass in [DiagnosticSDKMethodSwizzling classesInheritingFromClass:[NSURLSessionTask class]]) {
        if (![DiagnosticSDKMethodSwizzling doesClass:taskClass declareInstanceMethod:resumeSelector]) {
            continue;
        }

        [DiagnosticSDKMethodSwizzling replaceInstanceMethod:resumeSelector
                                                    ofClass:taskClass
                                           withBlockFactory:^id(IMP originalImplementation) {
            return ^(NSURLSessionTask *task) {
                [DiagnosticSDKNetworkHooks.eventObserver networkTaskWillResume:task];
                ((DiagnosticSDKResumeImplementation)originalImplementation)(task, resumeSelector);
            };
        }];
    }
}

@end
