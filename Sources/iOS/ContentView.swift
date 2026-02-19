import SwiftUI

// MARK: - iOS Root View

struct iOSRootView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedServer: VPNServer = VPNServer.allServers[0]
    @State private var showCredentials = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ConnectionStatusView(vpnManager: vpnManager)
                        .padding(.horizontal)

                    connectButton
                        .padding(.horizontal)

                    serverSection(title: "Japan", servers: VPNServer.japanServers)
                    serverSection(title: "China", servers: VPNServer.chinaServers)
                }
                .padding(.vertical)
            }
            .navigationTitle("VPN Connector")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCredentials = true
                    } label: {
                        Image(systemName: "key.fill")
                    }
                }
            }
            .sheet(isPresented: $showCredentials) {
                iOSCredentialsSheet()
                    .environmentObject(vpnManager)
            }
            .alert("Connection Error", isPresented: $showError) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sub-views

    private var connectButton: some View {
        Button {
            handleConnectTap()
        } label: {
            HStack {
                if vpnManager.connectionState.isTransitioning {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
                Text(connectButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(connectButtonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(vpnManager.connectionState.isTransitioning)
        .animation(.easeInOut, value: vpnManager.connectionState)
    }

    private var connectButtonTitle: String {
        switch vpnManager.connectionState {
        case .connected:      return "Disconnect"
        case .connecting:     return "Connecting..."
        case .disconnecting:  return "Disconnecting..."
        default:              return "Connect to \(selectedServer.name)"
        }
    }

    private var connectButtonColor: Color {
        switch vpnManager.connectionState {
        case .connected, .disconnecting: return .red
        default: return .accentColor
        }
    }

    private func serverSection(title: String, servers: [VPNServer]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(servers) { server in
                    Button {
                        selectedServer = server
                    } label: {
                        ServerRowView(
                            server: server,
                            isSelected: selectedServer.id == server.id,
                            isConnected: vpnManager.connectedServer?.id == server.id
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    if server.id != servers.last?.id {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func handleConnectTap() {
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
                showError = true
            }
        }
    }
}

// MARK: - iOS Credentials Sheet

struct iOSCredentialsSheet: View {
    @EnvironmentObject var vpnManager: VPNManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var sharedSecret = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            CredentialsFormView(
                username: $username,
                password: $password,
                sharedSecret: $sharedSecret
            ) {
                saveCredentials()
            }
            .navigationTitle("VPN Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saved {
                        Label("Saved", systemImage: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            }
            .onAppear(perform: loadExistingCredentials)
        }
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
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}
