import SwiftUI

// MARK: - macOS Main Content View

struct macOSContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedServer: VPNServer = VPNServer.allServers[0]
    @State private var showCredentials = false
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            serverList
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)

            detailPanel
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCredentials = true
                } label: {
                    Label("Credentials", systemImage: "key.fill")
                }
                .help("Edit VPN credentials")
            }
        }
        .sheet(isPresented: $showCredentials) {
            macOSCredentialsSheet()
                .environmentObject(vpnManager)
                .frame(width: 400)
        }
    }

    // MARK: - Server List (Sidebar)

    private var serverList: some View {
        List(VPNServer.allServers, selection: Binding(
            get: { selectedServer.id },
            set: { id in
                if let server = VPNServer.allServers.first(where: { $0.id == id }) {
                    selectedServer = server
                }
            }
        )) { server in
            ServerRowView(
                server: server,
                isSelected: selectedServer.id == server.id,
                isConnected: vpnManager.connectedServer?.id == server.id
            )
            .tag(server.id)
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        VStack(spacing: 24) {
            Spacer()

            ConnectionStatusView(vpnManager: vpnManager)
                .frame(maxWidth: 300)

            selectedServerCard

            connectButton

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectedServerCard: some View {
        VStack(spacing: 6) {
            Text(selectedServer.flag)
                .font(.largeTitle)
            Text(selectedServer.name)
                .font(.title3)
                .fontWeight(.semibold)
            Text(selectedServer.host)
                .font(.caption)
                .foregroundStyle(.secondary)
                .truncationMode(.middle)
        }
        .frame(maxWidth: 300)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var connectButton: some View {
        Button(action: handleConnectTap) {
            HStack {
                if vpnManager.connectionState.isTransitioning {
                    ProgressView().scaleEffect(0.7)
                }
                Text(connectButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(width: 240)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(connectButtonColor)
        .disabled(vpnManager.connectionState.isTransitioning)
        .keyboardShortcut(.return, modifiers: .command)
        .help(vpnManager.connectionState.isConnected ? "Disconnect VPN (⌘↩)" : "Connect to selected server (⌘↩)")
    }

    private var connectButtonTitle: String {
        switch vpnManager.connectionState {
        case .connected:      return "Disconnect"
        case .connecting:     return "Connecting..."
        case .disconnecting:  return "Disconnecting..."
        default:              return "Connect"
        }
    }

    private var connectButtonColor: Color {
        vpnManager.connectionState.isConnected ? .red : .accentColor
    }

    // MARK: - Actions

    private func handleConnectTap() {
        errorMessage = nil

        if vpnManager.connectionState.isConnected {
            vpnManager.disconnect()
            return
        }

        guard let credentials = vpnManager.loadCredentials() else {
            showCredentials = true
            return
        }

        Task {
            do {
                try await vpnManager.connect(to: selectedServer, credentials: credentials)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - macOS Credentials Sheet

struct macOSCredentialsSheet: View {
    @EnvironmentObject var vpnManager: VPNManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var sharedSecret = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            Text("VPN Credentials")
                .font(.headline)
                .padding()

            Divider()

            CredentialsFormView(
                username: $username,
                password: $password,
                sharedSecret: $sharedSecret
            ) {
                saveCredentials()
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark")
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .padding()
        }
        .onAppear(perform: loadExistingCredentials)
    }

    private func loadExistingCredentials() {
        if let creds = vpnManager.loadCredentials() {
            username = creds.username
            password = creds.password
            sharedSecret = creds.sharedSecret
        }
    }

    private func saveCredentials() {
        let creds = VPNCredentials(
            username: username,
            password: password,
            sharedSecret: sharedSecret
        )
        vpnManager.saveCredentials(creds)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

// MARK: - Menu Bar Popover View

struct MenuBarView: View {
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VPN Connector")
                    .font(.headline)
                Spacer()
            }

            Divider()

            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(vpnManager.connectionState.displayText)
                    .font(.subheadline)
                Spacer()
                if let server = vpnManager.connectedServer {
                    Text(server.flag)
                }
            }

            if vpnManager.connectionState.isConnected {
                Text(vpnManager.connectedDuration.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(vpnManager.connectionState.isConnected ? "Disconnect" : "Open App") {
                if vpnManager.connectionState.isConnected {
                    vpnManager.disconnect()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .buttonStyle(.link)
        }
        .padding()
        .frame(width: 220)
    }

    private var statusColor: Color {
        switch vpnManager.connectionState {
        case .connected:  return .green
        case .connecting: return .blue
        default:          return .secondary
        }
    }
}
