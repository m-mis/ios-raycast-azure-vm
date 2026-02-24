import { getAccessToken } from "./azure-auth";
import { ARM_BASE_URL, API_VERSIONS } from "./constants";
import {
  ArmListResponse,
  Subscription,
  ResourceGroup,
  VirtualMachine,
  VmInstanceView,
  ActivityLogResponse,
  PowerState,
  VmStatus,
} from "./types";

async function armFetch<T>(path: string, method: "GET" | "POST" = "GET"): Promise<T> {
  const token = await getAccessToken();
  const url = path.startsWith("https://") ? path : `${ARM_BASE_URL}${path}`;

  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });

  if (method === "POST" && response.status === 202) {
    // async operation accepted — no response body
    return undefined as T;
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Azure API error (${response.status}): ${errorText}`);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}

export async function listSubscriptions(): Promise<Subscription[]> {
  const data = await armFetch<ArmListResponse<Subscription>>(
    `/subscriptions?api-version=${API_VERSIONS.subscriptions}`,
  );
  return data.value;
}

export async function listResourceGroups(subscriptionId: string): Promise<ResourceGroup[]> {
  const data = await armFetch<ArmListResponse<ResourceGroup>>(
    `/subscriptions/${subscriptionId}/resourcegroups?api-version=${API_VERSIONS.resourceGroups}`,
  );
  return data.value;
}

export async function listVirtualMachines(subscriptionId: string, resourceGroup: string): Promise<VirtualMachine[]> {
  const data = await armFetch<ArmListResponse<VirtualMachine>>(
    `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines?api-version=${API_VERSIONS.compute}`,
  );
  return data.value;
}

export async function getVmInstanceView(
  subscriptionId: string,
  resourceGroup: string,
  vmName: string,
): Promise<VmInstanceView> {
  return armFetch<VmInstanceView>(
    `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}/instanceView?api-version=${API_VERSIONS.compute}`,
  );
}

export async function startVm(subscriptionId: string, resourceGroup: string, vmName: string): Promise<void> {
  await armFetch<void>(
    `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}/start?api-version=${API_VERSIONS.compute}`,
    "POST",
  );
}

export async function deallocateVm(subscriptionId: string, resourceGroup: string, vmName: string): Promise<void> {
  await armFetch<void>(
    `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}/deallocate?api-version=${API_VERSIONS.compute}`,
    "POST",
  );
}

function parsePowerState(code: string): PowerState {
  const state = code.replace("PowerState/", "");
  const valid: PowerState[] = ["running", "deallocated", "stopped", "starting", "stopping", "deallocating"];
  return valid.includes(state as PowerState) ? (state as PowerState) : "unknown";
}

export function parseVmStatus(instanceView: VmInstanceView): VmStatus {
  const powerStatus = instanceView.statuses.find((s) => s.code.startsWith("PowerState/"));
  const provisioningStatus = instanceView.statuses.find((s) => s.code.startsWith("ProvisioningState/"));

  return {
    powerState: powerStatus ? parsePowerState(powerStatus.code) : "unknown",
    displayStatus: powerStatus?.displayStatus ?? "Unknown",
    provisioningState: provisioningStatus?.displayStatus,
  };
}

export async function getVmStartTime(
  subscriptionId: string,
  resourceGroup: string,
  vmName: string,
): Promise<Date | undefined> {
  const resourceId = `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}`;

  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const filter = [
    `eventTimestamp ge '${sevenDaysAgo.toISOString()}'`,
    `eventTimestamp le '${now.toISOString()}'`,
    `resourceUri eq '${resourceId}'`,
  ].join(" and ");

  const params = new URLSearchParams({
    "api-version": API_VERSIONS.activityLog,
    $filter: filter,
    $select: "eventTimestamp,operationName,status",
  });

  const data = await armFetch<ActivityLogResponse>(
    `/subscriptions/${subscriptionId}/providers/Microsoft.Insights/eventtypes/management/values?${params.toString()}`,
  );

  // Find the most recent successful start event
  const startEvents = data.value
    .filter(
      (e) =>
        e.operationName.value === "Microsoft.Compute/virtualMachines/start/action" && e.status.value === "Succeeded",
    )
    .sort((a, b) => new Date(b.eventTimestamp).getTime() - new Date(a.eventTimestamp).getTime());

  if (startEvents.length > 0) {
    return new Date(startEvents[0].eventTimestamp);
  }

  return undefined;
}

export function getPortalUrl(subscriptionId: string, resourceGroup: string, vmName: string): string {
  return `https://portal.azure.com/#@/resource/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}/overview`;
}
