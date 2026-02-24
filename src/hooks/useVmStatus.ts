import { useCachedPromise } from "@raycast/utils";
import { getVmInstanceView, getVmStartTime, parseVmStatus } from "../lib/azure-api";
import { getVmConfig } from "../lib/storage";
import { VmConfig, VmStatus } from "../lib/types";

interface UseVmStatusResult {
  config: VmConfig | undefined;
  status: VmStatus | undefined;
  isLoading: boolean;
  error: Error | undefined;
  revalidate: () => void;
}

async function fetchVmStatus(config: VmConfig): Promise<VmStatus> {
  const instanceView = await getVmInstanceView(config.subscriptionId, config.resourceGroup, config.vmName);
  const status = parseVmStatus(instanceView);

  if (status.powerState === "running") {
    try {
      const startedAt = await getVmStartTime(config.subscriptionId, config.resourceGroup, config.vmName);
      if (startedAt) {
        status.startedAt = startedAt;
      }
    } catch {
      // Activity log access may fail; uptime is non-critical
    }
  }

  return status;
}

export function useVmStatus(): UseVmStatusResult {
  const { data: config, isLoading: configLoading } = useCachedPromise(getVmConfig);

  const {
    data: status,
    isLoading: statusLoading,
    error,
    revalidate,
  } = useCachedPromise(fetchVmStatus, [config!], {
    execute: !!config,
  });

  return {
    config,
    status,
    isLoading: configLoading || statusLoading,
    error: error as Error | undefined,
    revalidate,
  };
}

export function formatUptime(startedAt: Date): string {
  const ms = Date.now() - startedAt.getTime();
  if (ms < 0) return "0m";

  const totalMinutes = Math.floor(ms / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours > 0) {
    return `${hours}h${String(minutes).padStart(2, "0")}m`;
  }
  return `${minutes}m`;
}
