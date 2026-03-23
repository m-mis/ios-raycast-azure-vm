# Azure VM - iOS App

An iOS app to monitor and control your Azure Virtual Machine from your iPhone, with home screen widgets and Shortcuts integration.

## Features

- **Dashboard**: View VM status (running, stopped, deallocated) with color-coded indicators and uptime tracking
- **Start/Stop Controls**: Start or deallocate your VM directly from the app
- **iOS Widgets**: Small and medium home screen widgets showing VM status in real-time
- **Shortcuts Integration**: 4 App Intents for Siri & Shortcuts automation:
  - "Check my Azure VM" — get current status
  - "Start my Azure VM" — boot the VM
  - "Stop my Azure VM" — deallocate the VM
  - "Toggle my Azure VM" — smart start/stop

## Requirements

- iOS 17.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)
- Azure Service Principal with Reader + VM Contributor roles

## Setup

### 1. Generate Xcode Project

```bash
brew install xcodegen
cd ios
xcodegen generate
open AzureVM.xcodeproj
```

### 2. Configure Signing

1. Open the project in Xcode
2. Select each target (AzureVM, AzureVMWidgetExtension)
3. Set your **Development Team** in Signing & Capabilities
4. Ensure the **App Group** (`group.com.azure-vm`) is registered in your Apple Developer account
5. Ensure **Keychain Sharing** uses `group.com.azure-vm`

### 3. Add App Icon

Place a 1024x1024 PNG in `AzureVM/Assets.xcassets/AppIcon.appiconset/` and update the `Contents.json` with the filename.

### 4. Build & Run

Select your device or simulator and hit Run (Cmd+R).

## Azure Service Principal Setup

The app uses the same Service Principal credentials as the Raycast extension:

1. Go to [Azure Portal](https://portal.azure.com) → Azure Entra ID → App registrations
2. Create a new registration (or reuse the existing one)
3. Note the **Tenant ID** and **Application (Client) ID**
4. Create a new **Client Secret** under Certificates & secrets
5. Assign the Service Principal the **Reader** and **Virtual Machine Contributor** roles on your subscription

## Architecture

```
ios/
├── Shared/           # Shared code (app + widget + intents)
│   ├── Models.swift
│   ├── AzureAuth.swift
│   ├── AzureAPI.swift
│   ├── KeychainHelper.swift
│   ├── ConfigStore.swift
│   └── PowerStateInfo.swift
├── AzureVM/          # Main app target
│   ├── AzureVMApp.swift
│   └── Views/
├── AzureVMWidget/    # Widget extension
│   ├── AzureVMWidget.swift
│   └── WidgetViews.swift
└── AzureVMIntents/   # App Intents (in main app target)
    ├── GetVMStatusIntent.swift
    ├── StartVMIntent.swift
    ├── StopVMIntent.swift
    ├── ToggleVMIntent.swift
    └── AppShortcutsProvider.swift
```

Data sharing between app and widget uses:
- **Keychain** (App Group) for Azure credentials
- **UserDefaults** (App Group `group.com.azure-vm`) for VM configuration
