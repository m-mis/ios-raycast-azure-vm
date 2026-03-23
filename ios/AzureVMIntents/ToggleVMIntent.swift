import AppIntents

struct ToggleVMIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Azure VM"
    static var description = IntentDescription("Starts the VM if stopped, or deallocates it if running.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let config = ConfigStore.loadVmConfig() else {
            throw IntentError.noVmConfigured
        }

        let status = try await AzureAPI.getVmStatus(config: config)

        if status.powerState.isRunning {
            try await AzureAPI.deallocateVM(config: config)
            return .result(value: "Deallocating \(config.vmName)...")
        } else if status.powerState.isStopped {
            try await AzureAPI.startVM(config: config)
            return .result(value: "Starting \(config.vmName)...")
        } else {
            return .result(value: "\(config.vmName) is currently \(status.powerState.display.label). Cannot toggle now.")
        }
    }

    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case noVmConfigured

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .noVmConfigured:
                return "No VM is configured. Open the Azure VM app to set one up."
            }
        }
    }
}
