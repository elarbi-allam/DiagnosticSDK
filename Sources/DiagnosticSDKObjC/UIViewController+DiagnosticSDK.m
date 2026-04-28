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

static BOOL DSDK_ShouldIgnoreScreenName(NSString *name) {
    if (name == nil || name.length == 0) { return YES; }
    
    if ([name hasPrefix:@"UI"] ||
        [name hasPrefix:@"_UI"] ||
        [name isEqualToString:@"UINavigationController"] ||
        [name isEqualToString:@"UITabBarController"] ||
        [name hasPrefix:@"SwiftUI."] ||
        [name containsString:@"UIHostingController"] ||
        [name containsString:@"SwiftUI"] ||
        [name hasPrefix:@"_TtGC7SwiftUI"]) {
        return YES;
    }
    
    NSString *lower = [name lowercaseString];
    if ([lower containsString:@"remoteviewcontroller"]) { return YES; }
    if ([lower rangeOfString:@"remote"].location != NSNotFound
        && [lower rangeOfString:@"sheet"].location != NSNotFound) { return YES; }
    if ([lower containsString:@"_uiremote"] || [lower containsString:@"sheetpresentation"] || [lower containsString:@"remotekeyboard"]) { return YES; }
    if ([name hasPrefix:@"SH"]) { return YES; }
    if ([lower rangeOfString:@"siri"].location != NSNotFound || [lower rangeOfString:@"carplay"].location != NSNotFound) { return YES; }
    if ([lower hasPrefix:@"rpb"] || [lower hasPrefix:@"rpsystem"] || [name hasPrefix:@"RPScreen"] || [name hasPrefix:@"RPSystem"]) { return YES; }
    
    static NSString * const prefixes[] = {
        @"DOC", @"DPU", @"QL", @"PUP", @"SFS", @"SFAuthentication",
        @"SLCompose", @"PK", @"MF", @"SKStore", @"INUI", @"CNC", @"EK", @"CPS",
    };
    static const size_t nPrefixes = sizeof(prefixes) / sizeof(prefixes[0]);
    for (size_t i = 0; i < nPrefixes; i++) {
        if ([name hasPrefix:prefixes[i]]) { return YES; }
    }
    
    if ([name hasPrefix:@"_"] && ![name hasPrefix:@"_TtC"]) { return YES; }
    
    return NO;
}

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
    if (DSDK_ShouldIgnoreScreenName(screenName)) { return; }
    // Dynamically invoke the Swift singleton
    DiagnosticContext *context = [DiagnosticContext shared];
    [context updateCurrentScreen:screenName];
}

@end
