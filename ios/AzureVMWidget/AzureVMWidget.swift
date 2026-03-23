import WidgetKit
import SwiftUI

struct VMEntry: TimelineEntry {
    let date: Date
    let vmName: String
    let powerState: PowerState
    let uptime: String?
    let isPlaceholder: Bool

    static var placeholder: VMEntry {
        VMEntry(date: .now, vmName: "my-vm", powerState: .running, uptime: "2h30m", isPlaceholder: true)
    }

    static var notConfigured: VMEntry {
        VMEntry(date: .now, vmName: "Not configured", powerState: .unknown, uptime: nil, isPlaceholder: false)
    }
}

struct VMTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VMEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (VMEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }

        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VMEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)!
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> VMEntry {
        guard let config = ConfigStore.loadVmConfig() else {
            return .notConfigured
        }

        do {
            let status = try await AzureAPI.getVmStatus(config: config)

            var uptime: String?
            if status.powerState == .running, let startedAt = status.startedAt {
                uptime = formatUptime(from: startedAt)
            }

            return VMEntry(
                date: .now,
                vmName: config.vmName,
                powerState: status.powerState,
                uptime: uptime,
                isPlaceholder: false
            )
        } catch {
            return VMEntry(
                date: .now,
                vmName: config.vmName,
                powerState: .unknown,
                uptime: nil,
                isPlaceholder: false
            )
        }
    }
}

struct AzureVMWidget: Widget {
    let kind = "AzureVMWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VMTimelineProvider()) { entry in
            AzureVMWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Azure VM Status")
        .description("Monitor your Azure VM power state.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AzureVMWidgetBundle: WidgetBundle {
    var body: some Widget {
        AzureVMWidget()
    }
}
