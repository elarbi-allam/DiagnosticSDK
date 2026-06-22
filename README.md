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

- **Shake** the device or simulator, or
- Call `DiagnosticUIManager.shared.presentDashboard()` from your app.

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
