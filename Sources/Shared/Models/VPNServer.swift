import Foundation

// MARK: - VPN Server Model

struct VPNServer: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let country: String
    let countryCode: String
    let flag: String
    let host: String
    let remoteIdentifier: String
    let localIdentifier: String

    init(
        id: UUID = UUID(),
        name: String,
        country: String,
        countryCode: String,
        flag: String,
        host: String,
        remoteIdentifier: String = "",
        localIdentifier: String = ""
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.flag = flag
        self.host = host
        self.remoteIdentifier = remoteIdentifier.isEmpty ? host : remoteIdentifier
        self.localIdentifier = localIdentifier
    }
}

// MARK: - Predefined Servers

extension VPNServer {
    static let allServers: [VPNServer] = [
        VPNServer(
            name: "Japan - Tokyo",
            country: "Japan",
            countryCode: "JP",
            flag: "🇯🇵",
            host: "jp-tokyo.yourvpn.example.com",
            remoteIdentifier: "jp-tokyo.yourvpn.example.com"
        ),
        VPNServer(
            name: "Japan - Osaka",
            country: "Japan",
            countryCode: "JP",
            flag: "🇯🇵",
            host: "jp-osaka.yourvpn.example.com",
            remoteIdentifier: "jp-osaka.yourvpn.example.com"
        ),
        VPNServer(
            name: "China - Beijing",
            country: "China",
            countryCode: "CN",
            flag: "🇨🇳",
            host: "cn-beijing.yourvpn.example.com",
            remoteIdentifier: "cn-beijing.yourvpn.example.com"
        ),
        VPNServer(
            name: "China - Shanghai",
            country: "China",
            countryCode: "CN",
            flag: "🇨🇳",
            host: "cn-shanghai.yourvpn.example.com",
            remoteIdentifier: "cn-shanghai.yourvpn.example.com"
        ),
    ]

    static var japanServers: [VPNServer] {
        allServers.filter { $0.countryCode == "JP" }
    }

    static var chinaServers: [VPNServer] {
        allServers.filter { $0.countryCode == "CN" }
    }
}

// MARK: - VPN Credentials

struct VPNCredentials: Codable {
    let username: String
    let password: String
    let sharedSecret: String

    static let keychainService = "com.yourapp.vpnconnector"
    static let credentialsKey = "vpn_credentials"
}
