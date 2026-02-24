export const ARM_BASE_URL = "https://management.azure.com";

export const API_VERSIONS = {
  subscriptions: "2022-12-01",
  resourceGroups: "2021-04-01",
  compute: "2024-07-01",
  activityLog: "2015-04-01",
} as const;

import { Color, Icon, Image } from "@raycast/api";

export interface PowerStateInfo {
  label: string;
  menuBarIcon: Image.ImageLike;
  tintColor: Color;
  isTransitioning: boolean;
}

export const POWER_STATE_MAP: Record<string, PowerStateInfo> = {
  running: {
    label: "Running",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.Green },
    tintColor: Color.Green,
    isTransitioning: false,
  },
  starting: {
    label: "Starting…",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.Orange },
    tintColor: Color.Orange,
    isTransitioning: true,
  },
  stopping: {
    label: "Stopping…",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.Orange },
    tintColor: Color.Orange,
    isTransitioning: true,
  },
  deallocating: {
    label: "Deallocating…",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.Orange },
    tintColor: Color.Orange,
    isTransitioning: true,
  },
  deallocated: {
    label: "Deallocated",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.Red },
    tintColor: Color.Red,
    isTransitioning: false,
  },
  stopped: {
    label: "Stopped",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.Red },
    tintColor: Color.Red,
    isTransitioning: false,
  },
  unknown: {
    label: "Unknown",
    menuBarIcon: { source: Icon.Monitor, tintColor: Color.SecondaryText },
    tintColor: Color.SecondaryText,
    isTransitioning: false,
  },
};

export const TOKEN_CACHE_KEY = "azure-token";
export const VM_CONFIG_KEY = "azure-vm-config";
