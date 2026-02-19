import SwiftUI

@main
struct VPNConnectorApp: App {
    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environmentObject(VPNManager.shared)
        }
    }
}
