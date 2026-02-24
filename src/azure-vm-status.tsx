import {
  Icon,
  MenuBarExtra,
  launchCommand,
  LaunchType,
  showHUD,
  openExtensionPreferences,
  open,
  Color,
} from "@raycast/api";
import { useEffect, useRef, useState } from "react";
import { useVmStatus, formatUptime } from "./hooks/useVmStatus";
import { startVm, deallocateVm, getPortalUrl } from "./lib/azure-api";
import { POWER_STATE_MAP } from "./lib/constants";
import { PowerState } from "./lib/types";

const FAST_POLL_MS = 10_000;

export default function AzureVmStatus() {
  const { config, status, isLoading, error, revalidate } = useVmStatus();
  const [actionInFlight, setActionInFlight] = useState(false);
  const [optimisticState, setOptimisticState] = useState<PowerState | null>(null);
  const pollTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const effectivePowerState = optimisticState ?? status?.powerState ?? "unknown";
  const stateInfo = POWER_STATE_MAP[effectivePowerState] ?? POWER_STATE_MAP.unknown;
  const isTransitioning = stateInfo.isTransitioning;

  // Fast polling during transitions
  useEffect(() => {
    if (isTransitioning || optimisticState) {
      pollTimer.current = setInterval(() => revalidate(), FAST_POLL_MS);
    }
    return () => {
      if (pollTimer.current) {
        clearInterval(pollTimer.current);
        pollTimer.current = null;
      }
    };
  }, [isTransitioning, optimisticState, revalidate]);

  // Clear optimistic state once real status catches up
  useEffect(() => {
    if (!status || !optimisticState) return;
    const realState = status.powerState;
    if (
      (optimisticState === "starting" && realState === "running") ||
      (optimisticState === "starting" && realState === "starting") ||
      (optimisticState === "deallocating" && realState === "deallocated") ||
      (optimisticState === "deallocating" && realState === "deallocating") ||
      (optimisticState === "deallocating" && realState === "stopped")
    ) {
      if (realState !== "starting" && realState !== "deallocating") {
        setOptimisticState(null);
      }
    } else {
      setOptimisticState(null);
    }
  }, [status?.powerState, optimisticState]);

  // No config yet
  if (!config && !isLoading) {
    return (
      <MenuBarExtra icon={{ source: Icon.Monitor, tintColor: Color.SecondaryText }} tooltip="Azure VM — Setup Required">
        <MenuBarExtra.Item
          title="Configure VM…"
          icon={Icon.Gear}
          onAction={() => launchCommand({ name: "configure-vm", type: LaunchType.UserInitiated })}
        />
        <MenuBarExtra.Item title="Open Extension Preferences" icon={Icon.Key} onAction={openExtensionPreferences} />
      </MenuBarExtra>
    );
  }

  // Auth or API error
  if (error && !status) {
    const isAuthError = error.message.includes("Authentication failed") || error.message.includes("401");
    return (
      <MenuBarExtra
        icon={{ source: Icon.Monitor, tintColor: Color.Red }}
        tooltip={`Azure VM — ${isAuthError ? "Auth Error" : "Error"}`}
      >
        <MenuBarExtra.Item
          title={isAuthError ? "Authentication Error" : "Connection Error"}
          icon={Icon.ExclamationMark}
        />
        <MenuBarExtra.Item title={error.message.slice(0, 100)} />
        <MenuBarExtra.Section>
          {isAuthError && (
            <MenuBarExtra.Item title="Fix Credentials…" icon={Icon.Key} onAction={openExtensionPreferences} />
          )}
          <MenuBarExtra.Item title="Retry" icon={Icon.ArrowClockwise} onAction={revalidate} />
        </MenuBarExtra.Section>
      </MenuBarExtra>
    );
  }

  const isRunning = effectivePowerState === "running";
  const isStopped = effectivePowerState === "deallocated" || effectivePowerState === "stopped";
  const actionsDisabled = actionInFlight || isTransitioning;

  let menuTitle = "";
  if (isRunning && status?.startedAt) {
    menuTitle = formatUptime(status.startedAt);
  }

  async function handleStart() {
    if (!config || isRunning || actionsDisabled) return;
    setOptimisticState("starting");
    setActionInFlight(true);
    try {
      await startVm(config.subscriptionId, config.resourceGroup, config.vmName);
      await showHUD(`Starting ${config.vmName}…`);
      revalidate();
    } catch (e) {
      setOptimisticState(null);
      await showHUD(`Failed to start VM: ${e instanceof Error ? e.message : "Unknown error"}`);
    } finally {
      setActionInFlight(false);
    }
  }

  async function handleDeallocate() {
    if (!config || isStopped || actionsDisabled) return;

    setOptimisticState("deallocating");
    setActionInFlight(true);
    try {
      await deallocateVm(config.subscriptionId, config.resourceGroup, config.vmName);
      await showHUD(`Deallocating ${config.vmName}…`);
      revalidate();
    } catch (e) {
      setOptimisticState(null);
      await showHUD(`Failed to deallocate VM: ${e instanceof Error ? e.message : "Unknown error"}`);
    } finally {
      setActionInFlight(false);
    }
  }

  async function handleToggle() {
    if (isRunning) {
      await handleDeallocate();
    } else if (isStopped) {
      await handleStart();
    }
  }

  return (
    <MenuBarExtra
      icon={stateInfo.menuBarIcon}
      title={menuTitle}
      tooltip={`Azure VM — ${config?.vmName ?? "Loading…"} — ${stateInfo.label}`}
      isLoading={isLoading || actionInFlight}
    >
      <MenuBarExtra.Section title="Virtual Machine">
        <MenuBarExtra.Item title={config?.vmName ?? "…"} icon={Icon.ComputerChip} />
        <MenuBarExtra.Item title={config?.resourceGroup ?? "…"} icon={Icon.Folder} />
        <MenuBarExtra.Item
          title={`Status: ${stateInfo.label}`}
          icon={{ source: Icon.CircleFilled, tintColor: stateInfo.tintColor }}
        />
        {isRunning && status?.startedAt && (
          <MenuBarExtra.Item title={`Uptime: ${formatUptime(status.startedAt)}`} icon={Icon.Clock} />
        )}
      </MenuBarExtra.Section>

      <MenuBarExtra.Section title="Actions">
        {!isRunning && (
          <MenuBarExtra.Item
            title={actionInFlight ? "Starting…" : "Start VM"}
            icon={Icon.Play}
            onAction={actionsDisabled ? undefined : handleStart}
          />
        )}
        {!isStopped && (
          <MenuBarExtra.Item
            title={actionInFlight ? "Deallocating…" : "Deallocate VM"}
            icon={Icon.Stop}
            onAction={actionsDisabled ? undefined : handleDeallocate}
          />
        )}
        {(isRunning || isStopped) && (
          <MenuBarExtra.Item
            title={isRunning ? "Toggle → Deallocate" : "Toggle → Start"}
            icon={Icon.Switch}
            onAction={actionsDisabled ? undefined : handleToggle}
            shortcut={{ modifiers: ["cmd"], key: "t" }}
          />
        )}
      </MenuBarExtra.Section>

      <MenuBarExtra.Section>
        <MenuBarExtra.Item
          title="Refresh"
          icon={Icon.ArrowClockwise}
          onAction={revalidate}
          shortcut={{ modifiers: ["cmd"], key: "r" }}
        />
        <MenuBarExtra.Item
          title="Open in Azure Portal"
          icon={Icon.Globe}
          onAction={() => config && open(getPortalUrl(config.subscriptionId, config.resourceGroup, config.vmName))}
          shortcut={{ modifiers: ["cmd"], key: "o" }}
        />
        <MenuBarExtra.Item
          title="Configure VM…"
          icon={Icon.Gear}
          onAction={() => launchCommand({ name: "configure-vm", type: LaunchType.UserInitiated })}
        />
        <MenuBarExtra.Item title="Extension Preferences…" icon={Icon.Key} onAction={openExtensionPreferences} />
      </MenuBarExtra.Section>
    </MenuBarExtra>
  );
}
