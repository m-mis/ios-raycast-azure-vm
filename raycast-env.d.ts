/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Tenant ID - Azure Entra ID (Active Directory) Tenant ID */
  "tenantId": string,
  /** Client ID - Service Principal Application (Client) ID */
  "clientId": string,
  /** Client Secret - Service Principal client secret value */
  "clientSecret": string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `azure-vm-status` command */
  export type AzureVmStatus = ExtensionPreferences & {}
  /** Preferences accessible in the `configure-vm` command */
  export type ConfigureVm = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `azure-vm-status` command */
  export type AzureVmStatus = {}
  /** Arguments passed to the `configure-vm` command */
  export type ConfigureVm = {}
}

