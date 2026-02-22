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
- An Apple ID (free is enough to build and see the UI; see note below about VPN entitlement)
- A real IKEv2 VPN server (see server setup section below)

---

## Setup

### 1. Generate the Xcode project

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open VPNConnector.xcodeproj
```

### 2. Sign in to Xcode and enable automatic signing

The project uses `CODE_SIGN_STYLE = Automatic` — Xcode manages provisioning profiles for you.

1. Xcode > Settings > Accounts > `+` > sign in with your Apple ID
2. Select each target (`VPNConnector-iOS`, `VPNConnector-macOS`) in the project navigator
3. Under **Signing & Capabilities**, confirm "Automatically manage signing" is checked
4. Select your team (shown as "Your Name (Personal Team)" for a free Apple ID)

Xcode will create certificates and provisioning profiles automatically — no manual portal work.

**Finding your Team ID** (needed only if you want to hardcode it in `project.yml`):

```bash
security find-identity -v -p codesigning
```

Look for `"Apple Development: your@email.com (XXXXXXXXXX)"` — the 10-character code in parentheses is your Team ID. This appears even with a free Personal Team after your first Xcode build.

### 3. Configure your VPN servers

Edit `Sources/Shared/Models/VPNServer.swift` and replace the placeholder hostnames:

```swift
VPNServer(
    name: "Japan - Tokyo",
    host: "jp-tokyo.yourvpn.example.com",      // ← your real server
    remoteIdentifier: "jp-tokyo.yourvpn.example.com"
),
```

### 4. Enter credentials at runtime

Tap/click the **key icon** (toolbar) to open the credentials sheet:

| Field | Description |
|---|---|
| Username | Your IKEv2 / XAUTH username |
| Password | Your IKEv2 / XAUTH password |
| Shared Secret | IKEv2 Pre-Shared Key (PSK) |

Credentials are stored in the system Keychain — never in plain text.

---

## What works with a free Apple account vs. paid

| Feature | Free Personal Team | Paid ($99/yr) |
|---|---|---|
| Build and run iOS app on your device | Yes (expires every 7 days) | Yes |
| Full UI — server list, credentials, status | Yes | Yes |
| **VPN tunnel on iOS** | **No** | Yes |
| VPN tunnel on macOS (local dev build) | Possibly | Yes |
| TestFlight | No | Yes |
| App Store distribution | No | Yes |

### The VPN entitlement restriction

The `com.apple.developer.networking.vpn.api` entitlement (in `Config/iOS.entitlements`)
lets `NEVPNManager` configure system VPN tunnels. Apple's provisioning servers only grant
this in profiles for **paid Apple Developer Program members**.

**What this means in practice:**
- The app compiles and launches fine on a free account
- Tapping Connect will fail with a permission error on **iOS** (entitlement not in profile)
- On **macOS**, local dev builds may work — Apple is more permissive for non-App-Store macOS apps; worth testing
- The $99/year Apple Developer Program is the only supported path to VPN functionality on iOS

### Renewing a free-account iOS build

Free provisioning profiles expire after 7 days. Plug in your device, hit ⌘R in Xcode — it re-signs and re-installs automatically.

---

## Running on a physical iOS device

1. Plug in iPhone or iPad
2. Select your device from the run destination dropdown in Xcode
3. Press ⌘R
4. First time: on the device go to **Settings > General > VPN & Device Management** and tap "Trust" under your developer certificate

---

## macOS notes

- The app stays alive in the **menu bar** after the window is closed (`applicationShouldTerminateAfterLastWindowClosed` returns `false`)
- The menu bar icon reflects connection state (lock open/closed/spinning)
- Quick status and disconnect are available from the menu bar without opening the full window

---

## VPN Server Infrastructure

This app is a **client only**. You need IKEv2-compatible servers. Common options:

- **Self-hosted**: [strongSwan](https://www.strongswan.org/) on a VPS (e.g., AWS Tokyo `ap-northeast-1`)
- **Managed**: Any IKEv2-capable VPN service that provides custom server addresses + PSK

> **Note on China connectivity**: Running a VPN server *inside* China for inbound
> access requires ICP licensing compliance. A common alternative is a server in
> Hong Kong (`ap-east-1`) for low-latency access from mainland China.

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
