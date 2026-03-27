import SwiftUI

struct VMSelectorView: View {
    var onSelected: () -> Void

    @State private var subscriptions: [Subscription] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        subscriptionList
            .navigationTitle("Select VM")
            .navigationDestination(for: Subscription.self) { sub in
                ResourceGroupStepView(subscription: sub, onSelected: onSelected)
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
                    NavigationLink(value: sub) {
                        VStack(alignment: .leading) {
                            Text(sub.displayName)
                                .font(.body)
                            Text(sub.subscriptionId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
}

// MARK: - Step 2: Resource Groups

private struct ResourceGroupStepView: View {
    let subscription: Subscription
    var onSelected: () -> Void

    @State private var resourceGroups: [ResourceGroup] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            Section("Select a Resource Group") {
                ForEach(resourceGroups) { rg in
                    NavigationLink(value: rg) {
                        VStack(alignment: .leading) {
                            Text(rg.name)
                                .font(.body)
                            Text(rg.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Resource Group")
        .navigationDestination(for: ResourceGroup.self) { rg in
            VMStepView(subscription: subscription, resourceGroup: rg, onSelected: onSelected)
        }
        .overlay {
            if isLoading && resourceGroups.isEmpty {
                ProgressView("Loading resource groups...")
            }
        }
        .task {
            await loadResourceGroups()
        }
    }

    private func loadResourceGroups() async {
        isLoading = true
        error = nil
        do {
            resourceGroups = try await AzureAPI.listResourceGroups(subscriptionId: subscription.subscriptionId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Step 3: Virtual Machines

private struct VMStepView: View {
    let subscription: Subscription
    let resourceGroup: ResourceGroup
    var onSelected: () -> Void

    @State private var virtualMachines: [VirtualMachine] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
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
        .task {
            await loadVMs()
        }
    }

    private func loadVMs() async {
        isLoading = true
        error = nil
        do {
            virtualMachines = try await AzureAPI.listVirtualMachines(
                subscriptionId: subscription.subscriptionId,
                resourceGroup: resourceGroup.name
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func selectVM(_ vm: VirtualMachine) {
        let config = VmConfig(
            subscriptionId: subscription.subscriptionId,
            subscriptionName: subscription.displayName,
            resourceGroup: resourceGroup.name,
            vmName: vm.name
        )
        ConfigStore.saveVmConfig(config)
        onSelected()
    }
}
