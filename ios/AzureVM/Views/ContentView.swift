import SwiftUI

struct ContentView: View {
    @State private var hasCredentials = KeychainHelper.loadCredentials() != nil
    @State private var hasConfig = ConfigStore.loadVmConfig() != nil
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            if hasCredentials && hasConfig {
                DashboardView(
                    onReconfigure: {
                        hasConfig = false
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
