import SwiftUI

public struct DiagnosticDashboardView: View {
    public init() {}
    
    public var body: some View {
        // One NavigationView per tab (not wrapping the whole TabView) avoids broken pops
        // from NavigationLink detail screens on iOS 15.
        DiagnosticRootTabView()
    }
}
