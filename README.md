# Azure VM Control

Monitor and control a single Azure Virtual Machine directly from the macOS menu bar.

## Features

- **Live Status** — See your VM's power state at a glance in the menu bar
- **Uptime Display** — Real-time elapsed time since the VM was started
- **Start / Deallocate** — Control your VM lifecycle without leaving your desktop
- **Smart Toggle** — One action that starts or stops based on current state
- **Notifications** — HUD confirmations for all operations
- **Auto-Refresh** — Configurable background polling (default: every 5 minutes)
- **Azure Portal Link** — Jump to the VM's portal page in one click

## Setup

### 1. Create Azure Credentials

You need a Service Principal with access to your VM. This is done entirely in the [Azure Portal](https://portal.azure.com) — no CLI tools required.

#### Register an App

1. Go to **Microsoft Entra ID** → **App registrations** → **New registration**
2. Enter a name (e.g. `raycast-azure-vm`), leave defaults, click **Register**
3. On the Overview page, copy:
   - **Application (client) ID**
   - **Directory (tenant) ID**

#### Create a Client Secret

1. In your app registration, go to **Certificates & secrets**
2. Click **New client secret**, add a description, choose an expiry
3. Click **Add** and **immediately copy the Value** (it's only shown once)

#### Assign Permissions

1. Navigate to your **Subscription** (or the specific **Resource Group** containing your VM)
2. Go to **Access control (IAM)** → **Add role assignment**
3. Select the role **Virtual Machine Contributor**
4. Under **Members**, choose **User, group, or service principal**, then search for the app you registered
5. Click **Review + assign**

### 2. Configure the Extension

1. Open Raycast and search for **"VM Status"** or **"Configure VM"**
2. You'll be prompted to enter your credentials in Extension Preferences:
   - **Tenant ID** — from step 1
   - **Client ID** — from step 1
   - **Client Secret** — from step 1
3. Run **"Configure VM"** to select your Subscription → Resource Group → Virtual Machine
4. The menu bar icon will appear showing your VM's live status

## Commands

| Command | Description |
|---------|-------------|
| **VM Status** | Menu bar icon showing live VM status with controls |
| **Configure VM** | Interactive picker to select which VM to monitor |

## Menu Bar

The menu bar displays the VM state with a colored indicator:

- 🟢 `2h30m` — Running (with uptime)
- 🔴 — Deallocated / Stopped
- 🟡 — Starting / Stopping / Deallocating
- ⚙️ — Not yet configured

Click the icon to access:

- VM info (name, resource group, status, uptime)
- Start / Deallocate / Toggle actions
- Refresh, Open in Azure Portal, Reconfigure

## Alternative: CLI Setup

If you already have the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) installed, you can create the Service Principal in one command:

```bash
az ad sp create-for-rbac \
  --name "raycast-azure-vm" \
  --role "Virtual Machine Contributor" \
  --scopes /subscriptions/<your-subscription-id>
```

This outputs `appId` (Client ID), `password` (Client Secret), and `tenant` (Tenant ID).

## Designed For

- Developers managing a single Azure VM
- Remote SSH workflows (e.g., VS Code Remote, Cursor)
- Cost-conscious usage with manual lifecycle control
- Minimal overhead — no Azure CLI dependency at runtime
