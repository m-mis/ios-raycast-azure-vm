import { LocalStorage } from "@raycast/api";
import { VM_CONFIG_KEY } from "./constants";
import { VmConfig } from "./types";

export async function getVmConfig(): Promise<VmConfig | undefined> {
  const raw = await LocalStorage.getItem<string>(VM_CONFIG_KEY);
  if (!raw) return undefined;
  try {
    return JSON.parse(raw) as VmConfig;
  } catch {
    return undefined;
  }
}

export async function saveVmConfig(config: VmConfig): Promise<void> {
  await LocalStorage.setItem(VM_CONFIG_KEY, JSON.stringify(config));
}

export async function clearVmConfig(): Promise<void> {
  await LocalStorage.removeItem(VM_CONFIG_KEY);
}
