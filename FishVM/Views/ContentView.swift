// bomberfish
// ContentView.swift – FishVM
// created on 2024-10-19

import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = VMManager.shared
    @State private var selectedVM: VirtualMachine? = VMManager.shared.vms.first
    @State var showingCreationSheet = false
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @State var filename: String = "Select a disk image..."
    
    @ViewBuilder var detail: some View {
        if let selectedVM {
            
            let vm: Binding<VirtualMachine> = Binding(get: {
                self.selectedVM ?? .init(path: .init(fileURLWithPath: "/"), config: .init(name: "", attachedUSBImagePath: nil, cpuCores: 0, ramAmount: 0))
            }, set: {
                self.selectedVM = $0
                do {
                    try self.selectedVM?.saveConfig()
                } catch {
                    defaultLogger.error("\(error)")
                }
            })
            
            List {
                Group {
                    HStack {
                        Text("Icon")
                        Spacer()
                        IconPicker(icon: vm.config.icon)
                    }
                    HStack {
                        Slider(value: .convert(vm.config.cpuCores), in: 1.0...Float(ProcessInfo.processInfo.processorCount), step: 1.0, label: {
                            Text("CPU Cores")
                        })
                        
                        TextField("#", value: vm.config.cpuCores, formatter: NumberFormatter())
                            .frame(width: 20)
                    }
                    HStack {
                        Text("RAM amount")
                        Spacer()
                        TextField("#", value: vm.config.ramAmount, formatter: NumberFormatter())
                            .frame(width: 60)
                        Text("MiB")
                    }
                    HStack {
                        Text("Display Resolution")
                        Spacer()
                        TextField("Width", value: vm.config.fbWidth, formatter: NumberFormatter())
                            .frame(width: 60)
                        Text("x")
                        TextField("Height", value: vm.config.fbHeight, formatter: NumberFormatter())
                            .frame(width: 60)
                    }
                    HStack(spacing: 3) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: selectedVM.config.attachedUSBImagePath?.path() ?? "/usr"))
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
                                self.selectedVM?.config.attachedUSBImagePath = panel.url
                                self.filename = panel.url?.lastPathComponent ?? "Select a disk image..."
                            }
                        }
                        if let _ = vm.config.attachedUSBImagePath.wrappedValue {
                            Button(action: {self.selectedVM?.config.attachedUSBImagePath = nil}, label: {
                                Image(systemName: "trash.fill")
                            })
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .backgroundStyle(.tertiary)
        }  else {
            ContentUnavailableView("No VMs", systemImage: "laptopcomputer.slash", description: Text("Try creating one by pressing the plus button."))
                .navigationTitle("FishVM")
        }
    }
    
    @ViewBuilder var sidebar: some View {
        List(manager.vms, selection: $selectedVM) {vm in
            Group {
                switch vm.config.icon.type {
                case .system:
                    Label(title: {
                        Text(vm.config.name)
                    }, icon: {
                        Image(systemName: vm.config.icon.name)
                            .foregroundStyle(.accent)
                            .font(.system(size: 14))
                    })
                case .assetCatalog:
                    Label(title: {
                        Text(vm.config.name)
                    }, icon: {
                        Image(vm.config.icon.name)
                            .resizable()
                            .frame(maxWidth: 14, minHeight: 14, maxHeight: 14)
                    })
                        
                }
            }
                .tag(vm)
                .contextMenu {
                    Button("Start") {
                        if let _ = manager.currentlyRunningVM {
                            try? manager.stopRunningVM()
                        }
                        do {
                            try manager.startVM(vm)
                            openWindow(id: "runningvm")
                        } catch {
                            defaultLogger.error("\(error)")
                        }
                        
                    }
                    Button("Delete") {
                        if manager.currentlyRunningVM == vm {
                            dismissWindow(id: "runningvm")
                            try? manager.stopRunningVM()
                        }
                        do {
                            try manager.deleteVM(vm)
                            selectedVM = VMManager.shared.vms.first
                        } catch {
                            defaultLogger.error("\(error)")
                        }
                    }
                }
        }
    }
    
    var body: some View {
        NavigationSplitView(sidebar: {sidebar}, detail: {detail})
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if let selectedVM {
                        Button("Start the selected VM", systemImage: "play") {
                            if let _ = manager.currentlyRunningVM {
                                try? manager.stopRunningVM()
                            }
                            do {
                                try manager.startVM(selectedVM)
                                openWindow(id: "runningvm")
                            } catch {
                                defaultLogger.error("\(error)")
                            }
                        }
                    }
                    Button("Create a new VM", systemImage: "plus") {
                        showingCreationSheet = true
                    }
                }
            }
        }
        .navigationTitle(selectedVM == nil ? "FishVM" : selectedVM!.config.name)
        .sheet(isPresented: $showingCreationSheet, content: {VMCreationView()})
        .onChange(of: manager.windowCloseEvent) {_,_ in
            dismissWindow(id: "runningvm")
        }
        .onChange(of: selectedVM) {old,new in
            if let i = manager.vms.firstIndex(where: {$0 == old}),
               let vm = new {
                manager.vms[i] = vm
            }
        }
        .onChange(of: selectedVM) {_,_ in
            self.filename = selectedVM?.config.attachedUSBImagePath?.lastPathComponent ?? "Select a disk image..."
        }
        .onAppear {
            self.filename = selectedVM?.config.attachedUSBImagePath?.lastPathComponent ?? "Select a disk image..."
        }
    }
}

#Preview {
    ContentView()
}
