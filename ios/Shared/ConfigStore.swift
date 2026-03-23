import Foundation

enum ConfigStore {
    private static let suiteName = "group.com.azure-vm"
    private static let vmConfigKey = "azure-vm-config"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func loadVmConfig() -> VmConfig? {
        guard let data = defaults?.data(forKey: vmConfigKey) else { return nil }
        return try? JSONDecoder().decode(VmConfig.self, from: data)
    }

    static func saveVmConfig(_ config: VmConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults?.set(data, forKey: vmConfigKey)
    }

    static func clearVmConfig() {
        defaults?.removeObject(forKey: vmConfigKey)
    }
}
