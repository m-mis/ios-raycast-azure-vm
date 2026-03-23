import SwiftUI

struct DashboardView: View {
    var onReconfigure: () -> Void
    var onShowSettings: () -> Void

    @State private var vmStatus: VmStatus?
    @State private var isLoading = true
    @State private var actionInFlight = false
    @State private var error: String?
    @State private var showStopConfirmation = false

    private var config: VmConfig? { ConfigStore.loadVmConfig() }

    private var effectiveState: PowerState {
        vmStatus?.powerState ?? .unknown
    }

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
            // Fast polling during transitions
            while !Task.isCancelled && effectiveState.display.isTransitioning {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await loadStatus(silent: true)
            }
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
            ZStack {
                Circle()
                    .fill(effectiveState.display.color.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: effectiveState.display.systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(effectiveState.display.color)
                    .symbolEffect(.pulse, isActive: effectiveState.display.isTransitioning)
            }

            VStack(spacing: 4) {
                Text(effectiveState.display.label)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(effectiveState.display.color)

                if effectiveState == .running, let startedAt = vmStatus?.startedAt {
                    Label(formatUptime(from: startedAt), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading && vmStatus == nil {
                ProgressView()
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

    // MARK: - Actions

    private func loadStatus(silent: Bool = false) async {
        guard let config else { return }
        if !silent { isLoading = true }
        error = nil
        do {
            vmStatus = try await AzureAPI.getVmStatus(config: config)
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
