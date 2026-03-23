import Foundation

// MARK: - Azure OAuth

struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Azure Resource Manager

struct ArmListResponse<T: Codable>: Codable {
    let value: [T]
    let nextLink: String?
}

struct Subscription: Codable, Identifiable, Hashable {
    let subscriptionId: String
    let displayName: String
    let state: String
    let tenantId: String

    var id: String { subscriptionId }
}

struct ResourceGroup: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let location: String
}

struct VirtualMachine: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let location: String
    let properties: VMProperties

    struct VMProperties: Codable, Hashable {
        let vmId: String
        let hardwareProfile: HardwareProfile?
        let provisioningState: String

        struct HardwareProfile: Codable, Hashable {
            let vmSize: String
        }
    }
}

struct InstanceViewStatus: Codable {
    let code: String
    let level: String
    let displayStatus: String
    let message: String?
    let time: String?
}

struct VmInstanceView: Codable {
    let computerName: String?
    let osName: String?
    let osVersion: String?
    let statuses: [InstanceViewStatus]
}

struct ActivityLogEvent: Codable {
    let eventTimestamp: String
    let operationName: OperationName
    let status: EventStatus
    let resourceId: String

    struct OperationName: Codable {
        let value: String
        let localizedValue: String
    }

    struct EventStatus: Codable {
        let value: String
        let localizedValue: String
    }
}

struct ActivityLogResponse: Codable {
    let value: [ActivityLogEvent]
    let nextLink: String?
}

// MARK: - App Configuration

struct VmConfig: Codable, Equatable {
    let subscriptionId: String
    let subscriptionName: String
    let resourceGroup: String
    let vmName: String
}

// MARK: - Power State

enum PowerState: String, Codable, CaseIterable {
    case running
    case deallocated
    case stopped
    case starting
    case stopping
    case deallocating
    case unknown
}

struct VmStatus: Equatable {
    let powerState: PowerState
    let displayStatus: String
    let provisioningState: String?
    let startedAt: Date?
}

// MARK: - Credentials

struct AzureCredentials: Codable, Equatable {
    let tenantId: String
    let clientId: String
    let clientSecret: String

    var isValid: Bool {
        !tenantId.isEmpty && !clientId.isEmpty && !clientSecret.isEmpty
    }
}
