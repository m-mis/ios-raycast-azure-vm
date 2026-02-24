// Azure OAuth token response
export interface TokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

// Azure Resource Manager list responses wrap items in a { value: T[] } envelope
export interface ArmListResponse<T> {
  value: T[];
  nextLink?: string;
}

export interface Subscription {
  subscriptionId: string;
  displayName: string;
  state: string;
  tenantId: string;
}

export interface ResourceGroup {
  id: string;
  name: string;
  location: string;
}

export interface VirtualMachine {
  id: string;
  name: string;
  location: string;
  properties: {
    vmId: string;
    hardwareProfile?: { vmSize: string };
    provisioningState: string;
  };
}

export interface InstanceViewStatus {
  code: string;
  level: "Info" | "Warning" | "Error";
  displayStatus: string;
  message?: string;
  time?: string;
}

export interface VmInstanceView {
  computerName?: string;
  osName?: string;
  osVersion?: string;
  statuses: InstanceViewStatus[];
}

export interface ActivityLogEvent {
  eventTimestamp: string;
  operationName: {
    value: string;
    localizedValue: string;
  };
  status: {
    value: string;
    localizedValue: string;
  };
  resourceId: string;
}

export interface ActivityLogResponse {
  value: ActivityLogEvent[];
  nextLink?: string;
}

// Stored VM configuration
export interface VmConfig {
  subscriptionId: string;
  subscriptionName: string;
  resourceGroup: string;
  vmName: string;
}

// Parsed power state from instance view
export type PowerState = "running" | "deallocated" | "stopped" | "starting" | "stopping" | "deallocating" | "unknown";

// Combined VM status used by the menu bar
export interface VmStatus {
  powerState: PowerState;
  displayStatus: string;
  provisioningState?: string;
  startedAt?: Date;
}
