import AppIntents

struct StartVMIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Azure VM"
    static var description = IntentDescription("Starts your configured Azure virtual machine.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let config = ConfigStore.loadVmConfig() else {
            throw IntentError.noVmConfigured
        }

        let status = try await AzureAPI.getVmStatus(config: config)
        if status.powerState.isRunning {
            return .result(value: "\(config.vmName) is already running.")
        }

        try await AzureAPI.startVM(config: config)
        return .result(value: "Starting \(config.vmName)...")
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
