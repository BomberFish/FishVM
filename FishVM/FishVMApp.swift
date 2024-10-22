// bomberfish
// FishVMApp.swift – FishVM
// created on 2024-10-19

import SwiftUI

struct FishVMApp: App {
    var body: some Scene {
        Window("Manage VMs", id: "vmmanager") {
            ContentView()
                .windowFullScreenBehavior(.disabled)
        }
        .defaultLaunchBehavior(.presented)
        
        Window("Running VM", id: "runningvm") {
            RunningVMView()                .windowToolbarFullScreenVisibility(.onHover)
                .windowFullScreenBehavior(.enabled)
                .background(WindowAccessor {win in
                    win?.collectionBehavior = .fullScreenPrimary // We want to be able to fullscreen our VM
                })
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        .windowToolbarStyle(.unifiedCompact)
        
        Settings {
            PreferencesView()
        }
    }
}
