// bomberfish
// VMCreationView.swift – FishVM
// created on 2024-10-19

import SwiftUI

struct VMCreationView: View {
    @ObservedObject var manager = VMManager.shared
    @State var vm: VMConfig = .init(name: "Virtual Machine", attachedUSBImagePath: nil, cpuCores: ProcessInfo.processInfo.processorCount / 2, ramAmount: 4096)
    @Environment(\.dismiss) var ds
    @State var diskSize: Int = 64
    @State var filename = "Select a disk image..."
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Name")
                TextField(text: $vm.name, label: {
                    Text("Name")
                })
                Spacer()
                IconPicker(icon: $vm.icon)
            }
            HStack {
                Slider(value: .convert($vm.cpuCores), in: 1.0...Float(ProcessInfo.processInfo.processorCount), step: 1.0, label: {
                    Text("CPU Cores")
                })
                
                TextField("#", value: $vm.cpuCores, formatter: NumberFormatter())
                    .frame(width: 20)
            }
            HStack {
                Text("RAM amount")
                //                Slider(value: .convert($vm.ramAmount), in: 512...16384, step: 1.0, label: {
                //                    Text("RAM")
                //                })
                Spacer()
                TextField("#", value: $vm.ramAmount, formatter: NumberFormatter())
                    .frame(width: 60)
                Text("MiB")
            }
            HStack {
                Text("Disk Size")
                Spacer()
                TextField("Size", value: $diskSize, formatter: NumberFormatter())
                    .frame(width: 40)
                Text("GiB")
            }
            HStack {
                Text("Display Resolution")
                Spacer()
                TextField("Width", value: $vm.fbWidth, formatter: NumberFormatter())
                    .frame(width: 60)
                Text("x")
                TextField("Height", value: $vm.fbHeight, formatter: NumberFormatter())
                    .frame(width: 60)
            }
            HStack(spacing: 3) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: vm.attachedUSBImagePath?.path() ?? "/usr"))
                    .resizable()
                    .frame(maxWidth: 16, maxHeight: 16)
                Text(filename)
                    .lineLimit(1)
                Spacer()
                Button("Select") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.diskImage]
                    panel.resolvesAliases = true
                    panel.canCreateDirectories = true
                    panel.canDownloadUbiquitousContents = false
                    panel.canResolveUbiquitousConflicts = false
                    panel.showsHiddenFiles = true
                    if panel.runModal() == .OK {
                        vm.attachedUSBImagePath = panel.url
                        self.filename = panel.url?.lastPathComponent ?? "Select a disk image..."
                    }
                }
                if let _ = vm.attachedUSBImagePath {
                    Button(action: {vm.attachedUSBImagePath = nil}, label: {
                        Image(systemName: "trash.fill")
                    })
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") {
                    ds()
                }   
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try manager.createVM(config: vm, diskSize: diskSize)
                    } catch {
                        defaultLogger.fault("\(error)")
                        try? FileManager.default.removeItem(atPath: vmURL.appendingPathComponent(vm.name + ".bundle").path())
                    }
                    ds()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

#Preview {
    VMCreationView()
}
