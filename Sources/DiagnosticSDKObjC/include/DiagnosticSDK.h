#import <Foundation/Foundation.h>

//! Project version number for DiagnosticSDK.
FOUNDATION_EXPORT double DiagnosticSDKVersionNumber;

//! Project version string for DiagnosticSDK.
FOUNDATION_EXPORT const unsigned char DiagnosticSDKVersionString[];

// --- 🧙‍♂️ THE PERFECT ARCHITECTURE (XCODE vs SPM) ---

// 1. If we compile through the classic Xcode project (.xcodeproj)
// Apple requires angle brackets < > for Framework imports.
#if __has_include(<DiagnosticSDK/DiagnosticSDKBootstrapper.h>)

    #import <DiagnosticSDK/DiagnosticSDKBootstrapper.h>
    #import <DiagnosticSDK/DiagnosticSDKMethodSwizzling.h>
    #import <DiagnosticSDK/NSURLSessionConfiguration+DiagnosticSDK.h>
    #import <DiagnosticSDK/UIViewController+DiagnosticSDK.h>

// 2. If we compile through Swift Package Manager
// SPM builds a "flat" module, so files are imported directly with quotes " "
#else

    #import "DiagnosticSDKBootstrapper.h"
    #import "DiagnosticSDKMethodSwizzling.h"
    #import "NSURLSessionConfiguration+DiagnosticSDK.h"
    #import "UIViewController+DiagnosticSDK.h"

#endif