import SwiftUI

// MARK: - Server Row View

struct ServerRowView: View {
    let server: VPNServer
    let isSelected: Bool
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 14) {
            flagBadge
            serverInfo
            Spacer()
            connectionBadge
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Sub-views

    private var flagBadge: some View {
        Text(server.flag)
            .font(.title2)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
    }

    private var serverInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(server.name)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            Text(server.country)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionBadge: some View {
        Group {
            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .labelStyle(.iconOnly)
                    .imageScale(.large)
            } else if isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Credentials Form View (Shared)

struct CredentialsFormView: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var sharedSecret: String
    var onSave: () -> Void

    var body: some View {
        Form {
            Section("VPN Account") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section("IKEv2 Pre-Shared Key") {
                SecureField("Shared Secret", text: $sharedSecret)
            }

            Section {
                Button("Save Credentials", action: onSave)
                    .disabled(username.isEmpty || password.isEmpty || sharedSecret.isEmpty)
            }
        }
    }
}
