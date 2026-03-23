import AppIntents

struct GetVMStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Azure VM Status"
    static var description = IntentDescription("Returns the current power state of your Azure VM.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let config = ConfigStore.loadVmConfig() else {
            throw $IntentError.noVmConfigured
        }

        let status = try await AzureAPI.getVmStatus(config: config)

        var result = "\(config.vmName): \(status.powerState.display.label)"
        if status.powerState == .running, let startedAt = status.startedAt {
            result += " (uptime: \(formatUptime(from: startedAt)))"
        }

        return .result(value: result)
    }

    enum $IntentError: Error, CustomLocalizedStringResourceConvertible {
        case noVmConfigured

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .noVmConfigured:
                return "No VM is configured. Open the Azure VM app to set one up."
            }
        }
    }
}
