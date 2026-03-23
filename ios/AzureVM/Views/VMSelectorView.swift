import SwiftUI

struct VMSelectorView: View {
    var onSelected: () -> Void

    @State private var path = NavigationPath()
    @State private var subscriptions: [Subscription] = []
    @State private var resourceGroups: [ResourceGroup] = []
    @State private var virtualMachines: [VirtualMachine] = []
    @State private var selectedSubscription: Subscription?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        subscriptionList
            .navigationTitle("Select VM")
            .navigationDestination(for: String.self) { step in
                if step == "resourceGroups" {
                    resourceGroupList
                } else if step == "vms" {
                    vmList
                }
            }
    }

    // MARK: - Step 1: Subscriptions

    private var subscriptionList: some View {
        List {
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            Section("Select a Subscription") {
                ForEach(subscriptions) { sub in
                    Button {
                        selectedSubscription = sub
                        Task { await loadResourceGroups(subscriptionId: sub.subscriptionId) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(sub.displayName)
                                .font(.body)
                            Text(sub.subscriptionId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .overlay {
            if isLoading && subscriptions.isEmpty {
                ProgressView("Loading subscriptions...")
            }
        }
        .task {
            await loadSubscriptions()
        }
    }

    // MARK: - Step 2: Resource Groups

    private var resourceGroupList: some View {
        List {
            Section("Select a Resource Group") {
                ForEach(resourceGroups) { rg in
                    Button {
                        Task { await loadVMs(subscriptionId: selectedSubscription!.subscriptionId, resourceGroup: rg.name) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(rg.name)
                                .font(.body)
                            Text(rg.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Resource Group")
        .overlay {
            if isLoading && resourceGroups.isEmpty {
                ProgressView("Loading resource groups...")
            }
        }
    }

    // MARK: - Step 3: Virtual Machines

    private var vmList: some View {
        List {
            Section("Select a Virtual Machine") {
                ForEach(virtualMachines) { vm in
                    Button {
                        selectVM(vm)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(vm.name)
                                .font(.body)
                            HStack {
                                Text(vm.location)
                                if let size = vm.properties.hardwareProfile?.vmSize {
                                    Text("·")
                                    Text(size)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Virtual Machine")
        .overlay {
            if isLoading && virtualMachines.isEmpty {
                ProgressView("Loading VMs...")
            }
        }
    }

    // MARK: - Data Loading

    private func loadSubscriptions() async {
        isLoading = true
        error = nil
        do {
            subscriptions = try await AzureAPI.listSubscriptions()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadResourceGroups(subscriptionId: String) async {
        isLoading = true
        error = nil
        resourceGroups = []
        do {
            resourceGroups = try await AzureAPI.listResourceGroups(subscriptionId: subscriptionId)
            path.append("resourceGroups")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadVMs(subscriptionId: String, resourceGroup: String) async {
        isLoading = true
        error = nil
        virtualMachines = []
        do {
            virtualMachines = try await AzureAPI.listVirtualMachines(subscriptionId: subscriptionId, resourceGroup: resourceGroup)
            path.append("vms")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func selectVM(_ vm: VirtualMachine) {
        guard let sub = selectedSubscription else { return }
        let config = VmConfig(
            subscriptionId: sub.subscriptionId,
            subscriptionName: sub.displayName,
            resourceGroup: vm.location,
            vmName: vm.name
        )
        ConfigStore.saveVmConfig(config)
        onSelected()
    }
}
