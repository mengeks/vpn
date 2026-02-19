import SwiftUI

@main
struct VPNConnectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            macOSContentView()
                .environmentObject(VPNManager.shared)
                .frame(minWidth: 380, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        // Menu bar extra for quick access
        MenuBarExtra("VPN", systemImage: menuBarIcon) {
            MenuBarView()
                .environmentObject(VPNManager.shared)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        switch VPNManager.shared.connectionState {
        case .connected:    return "lock.fill"
        case .connecting:   return "lock.open.rotation"
        case .disconnecting: return "lock.open"
        case .failed:       return "exclamationmark.lock"
        default:            return "lock.open"
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // Keep running in menu bar when window is closed
    }
}
