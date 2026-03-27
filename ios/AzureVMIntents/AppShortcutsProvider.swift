import AppIntents

struct AzureVMShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetVMStatusIntent(),
            phrases: [
                "Check my Azure VM with \(.applicationName)",
                "Azure VM status with \(.applicationName)",
                "What's my VM status in \(.applicationName)",
            ],
            shortTitle: "VM Status",
            systemImageName: "server.rack"
        )

        AppShortcut(
            intent: StartVMIntent(),
            phrases: [
                "Start my Azure VM with \(.applicationName)",
                "Boot my VM with \(.applicationName)",
                "Turn on my Azure VM with \(.applicationName)",
            ],
            shortTitle: "Start VM",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: StopVMIntent(),
            phrases: [
                "Stop my Azure VM with \(.applicationName)",
                "Deallocate my VM with \(.applicationName)",
                "Turn off my Azure VM with \(.applicationName)",
            ],
            shortTitle: "Stop VM",
            systemImageName: "stop.fill"
        )

        AppShortcut(
            intent: ToggleVMIntent(),
            phrases: [
                "Toggle my Azure VM with \(.applicationName)",
                "Switch my Azure VM with \(.applicationName)",
            ],
            shortTitle: "Toggle VM",
            systemImageName: "power"
        )
    }
}
