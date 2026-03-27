import SwiftUI

struct DashboardView: View {
    var onReconfigure: () -> Void
    var onShowSettings: () -> Void

    @State private var vmStatus: VmStatus?
    @State private var isLoading = true
    @State private var actionInFlight = false
    @State private var error: String?
    @State private var showStopConfirmation = false
    @State private var now = Date()
    @State private var localStartedAt: Date?

    private var config: VmConfig? { ConfigStore.loadVmConfig() }

    private var effectiveState: PowerState {
        vmStatus?.powerState ?? .unknown
    }

    private var runningStartDate: Date? {
        vmStatus?.startedAt ?? localStartedAt
    }

    private let uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard
                actionButtons
                infoSection
            }
            .padding()
        }
        .navigationTitle(config?.vmName ?? "Azure VM")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await loadStatus() }
                    }
                    Button("Open in Azure Portal", systemImage: "globe") {
                        if let config {
                            UIApplication.shared.open(AzureAPI.portalURL(config: config))
                        }
                    }
                    Divider()
                    Button("Change VM", systemImage: "arrow.triangle.2.circlepath") {
                        ConfigStore.clearVmConfig()
                        onReconfigure()
                    }
                    Button("Settings", systemImage: "gear") {
                        onShowSettings()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await loadStatus()
        }
        .task {
            await loadStatus()
        }
        .task(id: effectiveState) {
            guard effectiveState.display.isTransitioning else { return }
            while !Task.isCancelled && effectiveState.display.isTransitioning {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await loadStatus(silent: true)
            }
        }
        .onReceive(uptimeTimer) { _ in
            now = Date()
        }
        .confirmationDialog("Deallocate VM?", isPresented: $showStopConfirmation) {
            Button("Deallocate", role: .destructive) {
                Task { await deallocateVM() }
            }
        } message: {
            Text("This will stop and deallocate \(config?.vmName ?? "the VM"). You will stop being charged for compute.")
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            Image(systemName: effectiveState.display.systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(effectiveState.display.color)
                .symbolEffect(.pulse, isActive: effectiveState.display.isTransitioning)

            VStack(spacing: 6) {
                if effectiveState == .running, let startedAt = runningStartDate {
                    Text("Running for \(liveUptime(from: startedAt))")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(effectiveState.display.color)
                        .contentTransition(.numericText())
                } else {
                    Text(effectiveState.display.label)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(effectiveState.display.color)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        Group {
            if isLoading && vmStatus == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                HStack(spacing: 16) {
                    if !effectiveState.isRunning {
                        Button {
                            Task { await startVM() }
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(actionInFlight || effectiveState.display.isTransitioning)
                    }

                    if !effectiveState.isStopped {
                        Button {
                            showStopConfirmation = true
                        } label: {
                            Label("Deallocate", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(actionInFlight || effectiveState.display.isTransitioning)
                    }
                }
                .disabled(config == nil)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let config {
                LabeledContent("VM Name", value: config.vmName)
                LabeledContent("Resource Group", value: config.resourceGroup)
                LabeledContent("Subscription", value: config.subscriptionName)
            }
            if let prov = vmStatus?.provisioningState {
                LabeledContent("Provisioning", value: prov)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func liveUptime(from startDate: Date) -> String {
        let interval = Int(now.timeIntervalSince(startDate))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Actions

    private func loadStatus(silent: Bool = false) async {
        guard let config else { return }
        if !silent { isLoading = true }
        error = nil
        do {
            vmStatus = try await AzureAPI.getVmStatus(config: config)
            if let state = vmStatus?.powerState {
                AppIconManager.updateIcon(for: state)
                // Track local start time as fallback for uptime
                if state == .running && vmStatus?.startedAt == nil && localStartedAt == nil {
                    localStartedAt = Date()
                } else if !state.isRunning {
                    localStartedAt = nil
                }
            }
        } catch {
            if !silent { self.error = error.localizedDescription }
        }
        if !silent { isLoading = false }
    }

    private func startVM() async {
        guard let config else { return }
        actionInFlight = true
        do {
            try await AzureAPI.startVM(config: config)
            vmStatus = VmStatus(powerState: .starting, displayStatus: "Starting", provisioningState: nil, startedAt: nil)
        } catch {
            self.error = error.localizedDescription
        }
        actionInFlight = false
    }

    private func deallocateVM() async {
        guard let config else { return }
        actionInFlight = true
        do {
            try await AzureAPI.deallocateVM(config: config)
            vmStatus = VmStatus(powerState: .deallocating, displayStatus: "Deallocating", provisioningState: nil, startedAt: nil)
        } catch {
            self.error = error.localizedDescription
        }
        actionInFlight = false
    }
}
