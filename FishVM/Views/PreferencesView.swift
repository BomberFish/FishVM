// bomberfish
// PreferencesView.swift – FishVM
// created on 2024-10-21

import SwiftUI

struct PreferencesView: View {
    @AppStorage("AutoResizeDisplayWithWindow") var autoResize = false
    @AppStorage("CloseWindowOnShutdown") var closeWindow = false
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Text("Nothing here yet!")
                }
            }
            Tab("Display", systemImage: "display") {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Toggle(
                        "Automatically resize guest display based on window size", isOn: $autoResize
                    )
                    Toggle("Close viewer window when connection to guest display is lost", isOn: $closeWindow)

                }
            }
            Tab("About", systemImage: "info.circle") {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Text("FishVM")
                        .font(.largeTitle.weight(.bold))
                    Text(
                        "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
                    )
                    Text("© 2024 BomberFish")
                }
            }
        }
        .scenePadding()
        .toggleStyle(.checkbox)
        .tabViewStyle(.tabBarOnly)
        .toolbarTitleDisplayMode(.inlineLarge)
        .frame(minWidth: 250, minHeight: 75)
    }
}

#Preview {
    PreferencesView()
}
