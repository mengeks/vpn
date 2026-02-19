# VPN Connector — iOS & macOS

A native SwiftUI VPN client for iOS (iPhone/iPad) and macOS that connects to
servers in **Japan** and **China** using the **IKEv2** protocol via Apple's
`NetworkExtension` framework.

---

## Architecture

```
Sources/
├── Shared/
│   ├── Models/
│   │   └── VPNServer.swift          # Server definitions (JP, CN) + credentials model
│   ├── Managers/
│   │   └── VPNManager.swift         # NEVPNManager wrapper, keychain, state machine
│   └── Views/
│       ├── ConnectionStatusView.swift  # Animated lock icon + uptime counter
│       └── ServerRowView.swift         # Server list row + credentials form
├── iOS/
│   ├── VPNConnectorApp.swift        # @main entry point
│   └── ContentView.swift            # Scrollable server list + connect button
└── macOS/
    ├── VPNConnectorApp.swift        # @main entry point + MenuBarExtra
    └── ContentView.swift            # HSplitView sidebar + detail panel + menu bar popover
```

### Key design decisions

| Choice | Reason |
|---|---|
| `NEVPNManager` (IKEv2) | No custom Network Extension needed; works with any standard IKEv2 server |
| Keychain for secrets | Password & PSK never stored in `UserDefaults`; persist across reinstalls |
| `@MainActor` VPNManager | All state updates happen on main thread; safe for SwiftUI |
| MenuBarExtra (macOS) | App keeps running in menu bar when main window is closed |

---

## Requirements

- **Xcode 15+**
- **iOS 16+** / **macOS 13+**
- An Apple Developer account with the **Personal VPN** entitlement
- A real IKEv2 VPN server for Japan and China (see below)

---

## Setup

### 1. Generate the Xcode project

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you haven't:

```bash
brew install xcodegen
```

Then from the repo root:

```bash
xcodegen generate
open VPNConnector.xcodeproj
```

### 2. Set your Team ID

In `project.yml`, replace the empty `DEVELOPMENT_TEAM` value:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "XXXXXXXXXX"   # your 10-character Apple Team ID
```

Run `xcodegen generate` again after editing.

### 3. Update bundle IDs

Change the `PRODUCT_BUNDLE_IDENTIFIER` values in `project.yml` to match
identifiers registered in your Apple Developer account:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.vpnconnector.ios
PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.vpnconnector.macos
```

Also update `VPNCredentials.keychainService` in `VPNServer.swift` and the
keychain group in both `.entitlements` files to match.

### 4. Configure your VPN servers

Edit `Sources/Shared/Models/VPNServer.swift` and replace the placeholder
hostnames with your actual server addresses:

```swift
VPNServer(
    name: "Japan - Tokyo",
    host: "jp-tokyo.yourvpn.example.com",      // ← your server
    remoteIdentifier: "jp-tokyo.yourvpn.example.com"
),
```

### 5. Enable the Personal VPN capability in Xcode

For each target (iOS + macOS):
1. Select the target → **Signing & Capabilities**
2. Click **+ Capability** → add **Personal VPN**

The entitlement files in `Config/` already contain the required keys; Xcode
just needs to link them to a provisioning profile.

---

## Running

### iOS Simulator

The VPN tunnel **cannot** be established in the iOS Simulator. Run on a
physical device for full functionality.

### macOS

Build and run the macOS target directly. The app installs a VPN configuration
in System Settings → VPN on first connect.

---

## Configuring VPN credentials

Tap/click the **key icon** (toolbar) to open the credentials sheet:

| Field | Description |
|---|---|
| Username | Your IKEv2 / XAUTH username |
| Password | Your IKEv2 / XAUTH password |
| Shared Secret | IKEv2 Pre-Shared Key (PSK) |

Credentials are stored in the system Keychain — never in plain text.

---

## VPN Server Infrastructure

This app is a **client only**. You need IKEv2-compatible servers in Japan
and China. Common options:

- **Self-hosted**: [strongSwan](https://www.strongswan.org/) on a VPS
  (e.g., AWS Tokyo `ap-northeast-1`, or a Chinese cloud provider)
- **Managed**: Any IKEv2-capable VPN service that provides custom credentials

> **Note on China connectivity**: Running a VPN server *inside* China for
> inbound access requires ICP licensing compliance. A common alternative is a
> server in Hong Kong (`ap-east-1`) for low-latency access from mainland China.

---

## Protocol Details (IKEv2)

```
Encryption :  AES-256-GCM
Integrity  :  SHA-256
DH Group   :  Group 14 (2048-bit MODP)
Auth       :  EAP (username + password) over IKEv2
DPD Rate   :  Medium
MOBIKE     :  Enabled  (seamless handoff between Wi-Fi and cellular)
```
