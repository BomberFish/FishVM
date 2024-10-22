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
                Spacer()
            }
            Tab("Display", systemImage: "display") {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Toggle(
                        "Automatically resize guest display based on window size", isOn: $autoResize
                    )
                    Toggle("Close viewer window when connection to guest display is lost", isOn: $closeWindow)
                    Spacer()
                }
            }
            Tab("About", systemImage: "info.circle") {
                HStack {
                    Spacer()
                    Image("Icon")
                        .resizable()
                        .frame(width: 150, height: 150)
                    LazyVStack(alignment: .leading, spacing: 4) {
                        Text("FishVM")
                            .font(.largeTitle.weight(.bold))
                        Text(
                            "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
                        )
                        Text("© 2024 BomberFish")
                    }
                    Spacer()
                }
            }
        }
        .scenePadding()
        .toggleStyle(.checkbox)
        .tabViewStyle(.tabBarOnly)
        .toolbarTitleDisplayMode(.inlineLarge)
        .frame(minWidth: 250, maxWidth: 500, minHeight: 75, maxHeight: 900)
    }
}

#Preview {
    PreferencesView()
}
