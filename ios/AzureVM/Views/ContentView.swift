import SwiftUI

struct ContentView: View {
    @State private var hasCredentials = KeychainHelper.loadCredentials() != nil
    @State private var hasConfig = ConfigStore.loadVmConfig() != nil
    @State private var showSettings = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            if hasCredentials && hasConfig {
                DashboardView(
                    onReconfigure: {
                        ConfigStore.clearVmConfig()
                        hasConfig = false
                        navigationPath = NavigationPath()
                    },
                    onShowSettings: {
                        showSettings = true
                    }
                )
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView(onSaved: {
                            hasCredentials = true
                            showSettings = false
                        })
                    }
                }
            } else if hasCredentials && !hasConfig {
                VMSelectorView(onSelected: {
                    hasConfig = true
                    navigationPath = NavigationPath()
                })
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gear") {
                            showSettings = true
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView(onSaved: {
                            hasCredentials = true
                            showSettings = false
                        })
                    }
                }
            } else {
                SettingsView(onSaved: {
                    hasCredentials = true
                })
            }
        }
    }
}
