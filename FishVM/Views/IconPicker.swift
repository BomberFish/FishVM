// bomberfish
// IconPickerView.swift – FishVM
// created on 2024-10-22

import SwiftUI
import OSLog
import AssetCatalogWrapper

fileprivate let logger = Logger(subsystem: "FishVM", category: "Icon Picker")

struct IconPicker: View {
    @Binding var icon: Icon
    @State var showingPopup = false
    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .frame(width: 80, height: 80)
                .foregroundStyle(Color(NSColor.secondarySystemFill))                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .inset(by: 2) // inset value should be same as lineWidth in .stroke
                        .stroke(Color(NSColor.tertiarySystemFill), lineWidth: 2)
                )
                .cornerRadius(14)
            Group {
                switch icon.type {
                case .system:
                    Image(systemName: icon.name)
                        .foregroundStyle(.accent)
                        .font(.system(size: 40))
                case .assetCatalog:
                    Image(icon.name)
                        .resizable()
                        .frame(width: 40, height: 40)
                }
            }
            .onTapGesture {
                showingPopup.toggle()
            }
            
        }
        .popover(isPresented: $showingPopup) {
            IconPickerPopup(selectedIcon: $icon)
        }
    }
}

struct IconPickerPopup: View {
    @Binding var selectedIcon: Icon
    @State var icons = [
        Icon(type: .system, name: "desktopcomputer"),
        Icon(type: .system, name: "laptopcomputer"),
        Icon(type: .system, name: "pc"),
        Icon(type: .system, name: "display")
    ]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: .init(repeating: .init(), count: 4), spacing: 8) {
                ForEach(icons) {icon in
                    Group {
                        switch icon.type {
                        case .system:
                            Image(systemName: icon.name)
                                .foregroundStyle(.accent)
                                .font(.system(size: 40))
                        case .assetCatalog:
                            Image(icon.name)
                                .resizable()
                                .frame(width: 40, height: 40)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .onTapGesture {
                        selectedIcon = icon
                    }
                    .background(selectedIcon == icon ? Color(NSColor.labelColor).opacity(0.1) : Color.transparent)
                    .cornerRadius(8, antialiased: false)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500, maxHeight: 500)
        .onAppear {
//            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            let assetCatalogURL = Bundle.main.bundleURL.appendingPathComponent(Bundle.main.resourceURL!.appendingPathComponent("Assets.car").path())
                guard FileManager.default.fileExists(atPath: assetCatalogURL.path()) else { fatalError("Application bundle is corrupt. We cannot continue execution safely. (Reason: File \(assetCatalogURL.path()) does not exist)") }
                if let (catalog, renditions) = try? AssetCatalogWrapper.shared.renditions(forCarArchive: assetCatalogURL) {
                    for rendition in renditions {
                        if rendition.type == .image || rendition.type == .imageSet || rendition.type == .multiSizeImageSet {
                            for subrendition in rendition.renditions {
                                logger.debug("Found subrendition: \(subrendition.name)")
                                if subrendition.name != "Icon" && subrendition.name != "AppIcon" && !subrendition.name.starts(with: "ZZZZPackedAsset") {
                                    logger.notice("VALID RENDITION: \(subrendition.name)")
                                    icons.append(Icon(type: .assetCatalog, name: subrendition.name))
                                }
                            }
                        }
                    }
                }
                
//            }
        }
    }
}

#Preview {
    @Previewable @State var icon: Icon = .init(type: .system, name: "pc")
    VStack(alignment: .leading) {
        IconPicker(icon: $icon)
            .padding()
        Spacer()
    }
    .frame(width: 300, height: 200)
}
