#import "UIViewController+DiagnosticSDK.h"
#import <objc/runtime.h>

// MARK: - Swift Interop Workaround
// Since SPM enforces strict unidirectional dependencies (Swift depends on Obj-C),
// we cannot import the Swift auto-generated header here at compile time.
// Instead, I provide a local interface declaration to satisfy the compiler.
// At runtime, this correctly maps to our '@objc(DiagnosticContext)' Swift class.
@interface DiagnosticContext : NSObject
+ (instancetype)shared;
- (void)updateCurrentScreen:(NSString *)screenName;
@end

@implementation UIViewController (DiagnosticSDK)

+ (void)diagnostic_swizzleLifecycle {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        // 1. Swizzle 'viewDidLoad'
        // This ensures we register the screen context immediately upon creation,
        // capturing any API requests triggered during initial load.
        SEL originalLoad = @selector(viewDidLoad);
        SEL swizzledLoad = @selector(diagnostic_viewDidLoad);
        method_exchangeImplementations(class_getInstanceMethod(class, originalLoad),
                                       class_getInstanceMethod(class, swizzledLoad));

        // 2. Swizzle 'viewWillAppear:'
        // This ensures we properly update the context when a user navigates backward
        // (since 'viewDidLoad' is not called again when popping a controller).
        SEL originalAppear = @selector(viewWillAppear:);
        SEL swizzledAppear = @selector(diagnostic_viewWillAppear:);
        method_exchangeImplementations(class_getInstanceMethod(class, originalAppear),
                                       class_getInstanceMethod(class, swizzledAppear));
    });
}

#pragma mark - Swizzled Implementations

- (void)diagnostic_viewDidLoad {
    // Pre-register the screen in our SDK before the host app executes its logic.
    [self updateDiagnosticContext];
    
    // Resume the normal host app execution
    [self diagnostic_viewDidLoad];
}

- (void)diagnostic_viewWillAppear:(BOOL)animated {
    // Update the screen context to handle back-navigation
    [self updateDiagnosticContext];
    
    // Resume the normal host app execution
    [self diagnostic_viewWillAppear:animated];
}

#pragma mark - Context Management

/// I extract the screen name and forward it to our Swift singleton.
- (void)updateDiagnosticContext {
    NSString *screenName = NSStringFromClass([self class]);
    
    // I filter out Apple's private and structural UI components to maintain clean logs.
    if ([screenName hasPrefix:@"UI"] ||
        [screenName hasPrefix:@"_UI"] ||
        [screenName isEqualToString:@"UINavigationController"] ||
        [screenName isEqualToString:@"UITabBarController"] ||
        // SwiftUI hosting containers are structural; tagging them breaks attribution for mixed UIKit/SwiftUI apps.
        // SwiftUI-only apps should explicitly set the screen via the Swift API (provided by the SDK UI layer).
        [screenName hasPrefix:@"SwiftUI."] ||
        [screenName containsString:@"UIHostingController"] ||
        // SwiftUI-mangled runtime names (e.g. _TtGC7SwiftUI...StyleContextSplitViewNavigationController...)
        [screenName containsString:@"SwiftUI"] ||
        [screenName hasPrefix:@"_TtGC7SwiftUI"]) {
        return;
    }
    
    // Dynamically invoke the Swift singleton
    DiagnosticContext *context = [DiagnosticContext shared];
    [context updateCurrentScreen:screenName];
}

@end
