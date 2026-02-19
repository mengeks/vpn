import Foundation
import NetworkExtension
import Combine
import Security

// MARK: - VPN Connection State

enum VPNConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed(String)

    var displayText: String {
        switch self {
        case .disconnected:   return "Disconnected"
        case .connecting:     return "Connecting..."
        case .connected:      return "Connected"
        case .disconnecting:  return "Disconnecting..."
        case .failed(let msg): return "Failed: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isTransitioning: Bool {
        switch self {
        case .connecting, .disconnecting: return true
        default: return false
        }
    }
}

// MARK: - VPN Manager

@MainActor
final class VPNManager: ObservableObject {

    static let shared = VPNManager()

    @Published private(set) var connectionState: VPNConnectionState = .disconnected
    @Published private(set) var connectedServer: VPNServer?
    @Published private(set) var connectedDuration: TimeInterval = 0

    private let vpnManager = NEVPNManager.shared()
    private var statusObserver: NSObjectProtocol?
    private var durationTimer: Timer?
    private var connectionStartTime: Date?

    private init() {
        setupStatusObserver()
        Task { await loadPreferences() }
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        durationTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.updateConnectionState()
            }
        }
    }

    private func loadPreferences() async {
        do {
            try await vpnManager.loadFromPreferences()
            updateConnectionState()
        } catch {
            print("VPNManager: Failed to load preferences: \(error)")
        }
    }

    private func updateConnectionState() {
        switch vpnManager.connection.status {
        case .invalid:
            connectionState = .disconnected
            stopDurationTimer()
        case .disconnected:
            connectionState = .disconnected
            connectedServer = nil
            stopDurationTimer()
        case .connecting:
            connectionState = .connecting
        case .connected:
            connectionState = .connected
            startDurationTimer()
        case .reasserting:
            connectionState = .connecting
        case .disconnecting:
            connectionState = .disconnecting
            stopDurationTimer()
        @unknown default:
            connectionState = .disconnected
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        if connectionStartTime == nil {
            connectionStartTime = Date()
        }
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.connectionStartTime else { return }
                self.connectedDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        connectionStartTime = nil
        connectedDuration = 0
    }

    // MARK: - Connect / Disconnect

    func connect(to server: VPNServer, credentials: VPNCredentials) async throws {
        connectionState = .connecting

        do {
            try await vpnManager.loadFromPreferences()
            configureVPN(server: server, credentials: credentials)
            try await vpnManager.saveToPreferences()
            try await vpnManager.loadFromPreferences()

            try vpnManager.connection.startVPNTunnel()
            connectedServer = server
        } catch {
            connectionState = .failed(error.localizedDescription)
            throw error
        }
    }

    func disconnect() {
        connectionState = .disconnecting
        vpnManager.connection.stopVPNTunnel()
    }

    // MARK: - VPN Configuration (IKEv2)

    private func configureVPN(server: VPNServer, credentials: VPNCredentials) {
        vpnManager.localizedDescription = "VPN Connector – \(server.name)"
        vpnManager.isEnabled = true

        let proto = NEVPNProtocolIKEv2()
        proto.serverAddress = server.host
        proto.remoteIdentifier = server.remoteIdentifier
        proto.localIdentifier = credentials.username

        // Authentication
        proto.authenticationMethod = .none   // outer auth: certificates or PSK
        proto.useExtendedAuthentication = true
        proto.username = credentials.username

        // Store password & PSK in keychain
        proto.passwordReference = saveToKeychain(
            value: credentials.password,
            account: "vpn-password-\(server.id)"
        )
        proto.sharedSecretReference = saveToKeychain(
            value: credentials.sharedSecret,
            account: "vpn-psk-\(server.id)"
        )

        // IKEv2 security parameters
        proto.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
        proto.ikeSecurityAssociationParameters.integrityAlgorithm = .SHA256
        proto.ikeSecurityAssociationParameters.diffieHellmanGroup = .group14
        proto.childSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
        proto.childSecurityAssociationParameters.integrityAlgorithm = .SHA256
        proto.childSecurityAssociationParameters.diffieHellmanGroup = .group14

        proto.deadPeerDetectionRate = .medium
        proto.disableMOBIKE = false
        proto.disableRedirect = false
        proto.enableRevocationCheck = false
        proto.useConfigurationAttributeInternalIPSubnet = false

        vpnManager.protocolConfiguration = proto
        vpnManager.onDemandRules = []
        vpnManager.isOnDemandEnabled = false
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(value: String, account: String) -> Data? {
        guard let data = value.data(using: .utf8) else { return nil }

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      VPNCredentials.keychainService,
            kSecAttrAccount as String:      account,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,
            kSecReturnPersistentRef as String: true,
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        var ref: AnyObject?
        let status = SecItemAdd(query as CFDictionary, &ref)
        guard status == errSecSuccess else {
            print("VPNManager: Keychain write failed: \(status)")
            return nil
        }
        return ref as? Data
    }

    func loadCredentials() -> VPNCredentials? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  VPNCredentials.keychainService,
            kSecAttrAccount as String:  VPNCredentials.credentialsKey,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(VPNCredentials.self, from: data)
    }

    func saveCredentials(_ credentials: VPNCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      VPNCredentials.keychainService,
            kSecAttrAccount as String:      VPNCredentials.credentialsKey,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}

// MARK: - Duration Formatting

extension TimeInterval {
    var formattedDuration: String {
        let hours   = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
