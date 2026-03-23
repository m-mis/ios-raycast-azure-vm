import Foundation

enum AzureAPI {
    private static let baseURL = "https://management.azure.com"

    private static let apiVersions = (
        subscriptions: "2022-12-01",
        resourceGroups: "2021-04-01",
        compute: "2024-07-01",
        activityLog: "2015-04-01"
    )

    // MARK: - Generic ARM Fetch

    private static func armFetch<T: Decodable>(path: String, method: String = "GET") async throws -> T {
        let token = try await AzureAuth.shared.getAccessToken()
        let url: URL
        if path.hasPrefix("https://") {
            url = URL(string: path)!
        } else {
            url = URL(string: "\(baseURL)\(path)")!
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureError.invalidResponse
        }

        if method == "POST" && httpResponse.statusCode == 202 {
            // Async operation accepted
            return () as! T
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AzureError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func armPost(path: String) async throws {
        let token = try await AzureAuth.shared.getAccessToken()
        let url = URL(string: "\(baseURL)\(path)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureError.invalidResponse
        }

        guard httpResponse.statusCode == 202 || (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AzureError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }
    }

    // MARK: - Subscriptions

    static func listSubscriptions() async throws -> [Subscription] {
        let response: ArmListResponse<Subscription> = try await armFetch(
            path: "/subscriptions?api-version=\(apiVersions.subscriptions)"
        )
        return response.value
    }

    // MARK: - Resource Groups

    static func listResourceGroups(subscriptionId: String) async throws -> [ResourceGroup] {
        let response: ArmListResponse<ResourceGroup> = try await armFetch(
            path: "/subscriptions/\(subscriptionId)/resourcegroups?api-version=\(apiVersions.resourceGroups)"
        )
        return response.value
    }

    // MARK: - Virtual Machines

    static func listVirtualMachines(subscriptionId: String, resourceGroup: String) async throws -> [VirtualMachine] {
        let response: ArmListResponse<VirtualMachine> = try await armFetch(
            path: "/subscriptions/\(subscriptionId)/resourceGroups/\(resourceGroup)/providers/Microsoft.Compute/virtualMachines?api-version=\(apiVersions.compute)"
        )
        return response.value
    }

    static func getInstanceView(config: VmConfig) async throws -> VmInstanceView {
        return try await armFetch(
            path: "/subscriptions/\(config.subscriptionId)/resourceGroups/\(config.resourceGroup)/providers/Microsoft.Compute/virtualMachines/\(config.vmName)/instanceView?api-version=\(apiVersions.compute)"
        )
    }

    // MARK: - VM Actions

    static func startVM(config: VmConfig) async throws {
        try await armPost(
            path: "/subscriptions/\(config.subscriptionId)/resourceGroups/\(config.resourceGroup)/providers/Microsoft.Compute/virtualMachines/\(config.vmName)/start?api-version=\(apiVersions.compute)"
        )
    }

    static func deallocateVM(config: VmConfig) async throws {
        try await armPost(
            path: "/subscriptions/\(config.subscriptionId)/resourceGroups/\(config.resourceGroup)/providers/Microsoft.Compute/virtualMachines/\(config.vmName)/deallocate?api-version=\(apiVersions.compute)"
        )
    }

    // MARK: - Status Parsing

    static func getVmStatus(config: VmConfig) async throws -> VmStatus {
        let instanceView = try await getInstanceView(config: config)
        var status = parseVmStatus(instanceView: instanceView)

        if status.powerState == .running {
            let startTime = try? await getVmStartTime(config: config)
            status = VmStatus(
                powerState: status.powerState,
                displayStatus: status.displayStatus,
                provisioningState: status.provisioningState,
                startedAt: startTime
            )
        }

        return status
    }

    static func parseVmStatus(instanceView: VmInstanceView) -> VmStatus {
        let powerStatus = instanceView.statuses.first { $0.code.hasPrefix("PowerState/") }
        let provisioningStatus = instanceView.statuses.first { $0.code.hasPrefix("ProvisioningState/") }

        let powerState: PowerState
        if let code = powerStatus?.code {
            let state = code.replacingOccurrences(of: "PowerState/", with: "")
            powerState = PowerState(rawValue: state) ?? .unknown
        } else {
            powerState = .unknown
        }

        return VmStatus(
            powerState: powerState,
            displayStatus: powerStatus?.displayStatus ?? "Unknown",
            provisioningState: provisioningStatus?.displayStatus,
            startedAt: nil
        )
    }

    // MARK: - Uptime

    static func getVmStartTime(config: VmConfig) async throws -> Date? {
        let resourceId = "/subscriptions/\(config.subscriptionId)/resourceGroups/\(config.resourceGroup)/providers/Microsoft.Compute/virtualMachines/\(config.vmName)"

        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)

        let formatter = ISO8601DateFormatter()
        let filter = "eventTimestamp ge '\(formatter.string(from: sevenDaysAgo))' and eventTimestamp le '\(formatter.string(from: now))' and resourceUri eq '\(resourceId)'"

        var components = URLComponents(string: "\(baseURL)/subscriptions/\(config.subscriptionId)/providers/Microsoft.Insights/eventtypes/management/values")!
        components.queryItems = [
            URLQueryItem(name: "api-version", value: apiVersions.activityLog),
            URLQueryItem(name: "$filter", value: filter),
            URLQueryItem(name: "$select", value: "eventTimestamp,operationName,status"),
        ]

        let response: ActivityLogResponse = try await armFetch(path: components.url!.absoluteString)

        let startEvents = response.value
            .filter { $0.operationName.value == "Microsoft.Compute/virtualMachines/start/action" && $0.status.value == "Succeeded" }
            .compactMap { formatter.date(from: $0.eventTimestamp) }
            .sorted(by: >)

        return startEvents.first
    }

    // MARK: - Portal URL

    static func portalURL(config: VmConfig) -> URL {
        URL(string: "https://portal.azure.com/#@/resource/subscriptions/\(config.subscriptionId)/resourceGroups/\(config.resourceGroup)/providers/Microsoft.Compute/virtualMachines/\(config.vmName)/overview")!
    }
}
