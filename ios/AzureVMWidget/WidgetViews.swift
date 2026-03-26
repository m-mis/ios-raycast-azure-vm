import SwiftUI
import WidgetKit

struct AzureVMWidgetView: View {
    let entry: VMEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(entry.powerState.display.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: entry.powerState.display.systemImage)
                    .font(.title2)
                    .foregroundStyle(entry.powerState.display.color)
            }

            Text(entry.vmName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(entry.powerState.display.label)
                .font(.caption2)
                .foregroundStyle(entry.powerState.display.color)
                .fontWeight(.semibold)

            if entry.powerState == .running, let startedAt = entry.startedAt {
                Text(startedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(entry.powerState.display.color.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: entry.powerState.display.systemImage)
                    .font(.title)
                    .foregroundStyle(entry.powerState.display.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.vmName)
                    .font(.headline)
                    .lineLimit(1)

                Text(entry.powerState.display.label)
                    .font(.subheadline)
                    .foregroundStyle(entry.powerState.display.color)
                    .fontWeight(.semibold)

                if entry.powerState == .running, let startedAt = entry.startedAt {
                    Label {
                        Text(startedAt, style: .relative)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}
