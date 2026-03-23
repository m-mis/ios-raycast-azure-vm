import AppIntents

struct StopVMIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Azure VM"
    static var description = IntentDescription("Deallocates your configured Azure virtual machine.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let config = ConfigStore.loadVmConfig() else {
            throw IntentError.noVmConfigured
        }

        let status = try await AzureAPI.getVmStatus(config: config)
        if status.powerState.isStopped {
            return .result(value: "\(config.vmName) is already stopped.")
        }

        try await AzureAPI.deallocateVM(config: config)
        return .result(value: "Deallocating \(config.vmName)...")
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
