import SwiftUI

struct PowerStateDisplay {
    let label: String
    let color: Color
    let systemImage: String
    let isTransitioning: Bool
}

extension PowerState {
    var display: PowerStateDisplay {
        switch self {
        case .running:
            return PowerStateDisplay(label: "Running", color: .green, systemImage: "checkmark.circle.fill", isTransitioning: false)
        case .starting:
            return PowerStateDisplay(label: "Starting...", color: .orange, systemImage: "arrow.up.circle.fill", isTransitioning: true)
        case .stopping:
            return PowerStateDisplay(label: "Stopping...", color: .orange, systemImage: "arrow.down.circle.fill", isTransitioning: true)
        case .deallocating:
            return PowerStateDisplay(label: "Deallocating...", color: .orange, systemImage: "arrow.down.circle.fill", isTransitioning: true)
        case .deallocated:
            return PowerStateDisplay(label: "Deallocated", color: .red, systemImage: "minus.circle.fill", isTransitioning: false)
        case .stopped:
            return PowerStateDisplay(label: "Stopped", color: .red, systemImage: "minus.circle.fill", isTransitioning: false)
        case .unknown:
            return PowerStateDisplay(label: "Unknown", color: .gray, systemImage: "questionmark.circle.fill", isTransitioning: false)
        }
    }

    var isRunning: Bool { self == .running }
    var isStopped: Bool { self == .deallocated || self == .stopped }
}

func formatUptime(from startDate: Date) -> String {
    let interval = Date().timeIntervalSince(startDate)
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60

    if hours > 0 {
        return "\(hours)h\(minutes)m"
    }
    return "\(minutes)m"
}
