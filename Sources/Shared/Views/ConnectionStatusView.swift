import SwiftUI

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    @ObservedObject var vpnManager: VPNManager

    var body: some View {
        VStack(spacing: 12) {
            statusIndicator
            statusText
            if vpnManager.connectionState.isConnected {
                durationText
                serverNameText
            }
        }
        .padding()
        .background(statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sub-views

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 80, height: 80)

            if vpnManager.connectionState.isTransitioning {
                Circle()
                    .stroke(statusColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(vpnManager.connectionState.isConnected ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: vpnManager.connectionState.isTransitioning)
            }

            Image(systemName: statusIconName)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(statusColor)
        }
    }

    private var statusText: some View {
        Text(vpnManager.connectionState.displayText)
            .font(.headline)
            .foregroundStyle(statusColor)
    }

    private var durationText: some View {
        Label(vpnManager.connectedDuration.formattedDuration, systemImage: "clock")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var serverNameText: some View {
        Group {
            if let server = vpnManager.connectedServer {
                Label("\(server.flag) \(server.name)", systemImage: "server.rack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusBackground: Color {
        switch vpnManager.connectionState {
        case .connected:    return Color.green.opacity(0.08)
        case .connecting:   return Color.blue.opacity(0.08)
        case .disconnecting: return Color.orange.opacity(0.08)
        case .failed:       return Color.red.opacity(0.08)
        default:            return Color.secondary.opacity(0.08)
        }
    }

    private var statusColor: Color {
        switch vpnManager.connectionState {
        case .connected:    return .green
        case .connecting:   return .blue
        case .disconnecting: return .orange
        case .failed:       return .red
        default:            return .secondary
        }
    }

    private var statusIconName: String {
        switch vpnManager.connectionState {
        case .connected:    return "lock.fill"
        case .connecting:   return "lock.open.rotation"
        case .disconnecting: return "lock.open"
        case .failed:       return "exclamationmark.lock"
        default:            return "lock.open"
        }
    }
}
