# DiagnosticSDK
Network inspection and local replay for iOS apps.

**iOS 15+**

---

## Install

- Add the `DiagnosticSDK` package (SPM) or embed the framework in your app target.

---

## Integrate

Import the SDK, create a `NetworkInterceptor`, and call `start()` at app launch. **That is the full integration.**

### UIKit (`AppDelegate`)

```swift
import UIKit
import DiagnosticSDK

class AppDelegate: UIResponder, UIApplicationDelegate {

    private lazy var networkInterceptor = NetworkInterceptor()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Your existing startup code…

        networkInterceptor.start()
        return true
    }
}
```

After `start()`, the SDK captures traffic automatically. No other setup is required in the host app.

---

## Open the dashboard

- **Shake** the device or simulator (default), or
- Tap the **floating button**, if you enabled it (see below), or
- Call `DiagnosticUIManager.shared.presentDashboard()` from your app.

---

## Choose the trigger (optional)

`start()` alone enables **both** the shake gesture and the floating button.
To change that, pass a `DiagnosticConfiguration`:

```swift
// Default: shake + floating button
networkInterceptor.start()

// Floating button only
networkInterceptor.start(configuration: DiagnosticConfiguration(triggers: .floatingButton))

// Shake only
networkInterceptor.start(configuration: DiagnosticConfiguration(triggers: .shake))

// Neither: your app opens the dashboard itself, from a debug menu for instance
networkInterceptor.start(configuration: DiagnosticConfiguration(triggers: .manualOnly))
DiagnosticUIManager.shared.presentDashboard()   // ← always available, with any trigger

// Custom look
networkInterceptor.start(configuration: DiagnosticConfiguration(
    floatingButtonColor: UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 1),
    floatingButtonOpacity: 0.7,
    floatingButtonSystemImageName: "ant.circle.fill",
    floatingButtonSize: 60
))
```

| Option | Type | Default | Purpose |
|---|---|---|---|
| `triggers` | `DiagnosticTrigger` | `.all` | `.shake`, `.floatingButton`, `.all`, `.manualOnly` |
| `floatingButtonColor` | `UIColor` | `#FFDE90` | Background of the button |
| `floatingButtonTintColor` | `UIColor` | dark grey | Icon colour |
| `floatingButtonOpacity` | `CGFloat` | `0.95` | Clamped to `0…1` |
| `floatingButtonSystemImageName` | `String` | `"ladybug.fill"` | SF Symbol; unknown name falls back silently |
| `floatingButtonSize` | `CGFloat` | `52` | Diameter in points, minimum `32` |
| `floatingButtonInitialPosition` | `CGPoint?` | `nil` | `nil` = last position used, else bottom-trailing |
| `floatingButtonPersistsPosition` | `Bool` | `true` | Remember where the user dragged it |
| `allowsFloatingButtonInReleaseBuilds` | `Bool` | `false` | Kept for source compatibility; the button now honours `triggers` in every configuration |

**About the floating button**

- It lives in its own overlay `UIWindow`; your view hierarchy is never modified.
- Only the button itself captures touches — everything around it passes through to your app.
- The dashboard is always presented in your application window, never in the overlay.
- It is draggable, and hides itself while the dashboard is open.
- It is installed whenever `.floatingButton` is in `triggers`. In a non-DEBUG build it still
  appears, but the SDK logs a loud warning — never ship such a build to end users.
- Its accessibility identifier is `diagnostic.floatingButton` (useful to exclude it from UI tests).
- The SDK's own screens are excluded from screen tracking, so they never pollute a trace.

---

## Dashboard

| Tab | Purpose |
|-----|---------|
| **Live** | Current session traffic |
| **History** | Saved sessions — import, export, start replay |
| **Replay** | Enable/disable replayed requests while testing |

**Replay:** pick a session in History → Replay → use your app. Matching calls are served from the saved session.

---

## Tips

- If replay does not match, try **Ignore query** mode in History.
