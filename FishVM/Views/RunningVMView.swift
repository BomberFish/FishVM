// bomberfish
// VMView.swift – FishVM
// created on 2024-10-21

import SwiftUI
import Virtualization

struct VirtualMachineView: NSViewRepresentable {
    let virtualMachine: VZVirtualMachine
    
    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.virtualMachine = virtualMachine
        view.automaticallyReconfiguresDisplay = UserDefaults.standard.bool(forKey: "AutoResizeDisplayWithWindow")
        view.capturesSystemKeys = true
        return view
    }
    
    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {}
}

struct RunningVMView: View {
    @ObservedObject var manager = VMManager.shared
    @FocusState var vmFocused: Bool
    var body: some View {
        Group {
            if let vm = manager.currentlyRunningVZVM {
//                ZStack {
                    VirtualMachineView(virtualMachine: vm)
                        .focusable(true)
                        .focused($vmFocused)
                        .onAppear {
                            vmFocused = true
                        }
//                }
//                    .scaleEffect(manager.currentlyRunningVZVM == nil ? 0.1 : 1)
            } else {
                ZStack(alignment: .center) {
                    Rectangle()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.thinMaterial)
                    Image(systemName: "play.slash.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
//                .scaleEffect(manager.currentlyRunningVZVM == nil ? 2 : 1)
            }
        }
        
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(vmFocused ? "Focused"  : "Click to focus", systemImage: vmFocused ? "lock.fill" : "cursorarrow.rays") {
                        vmFocused = true
                    }
                    Button(manager.currentlyRunningVZVM == nil ? "Start" : "Stop", systemImage: manager.currentlyRunningVZVM == nil ? "play" : "stop") {
                        if manager.currentlyRunningVZVM != nil {
                            try? manager.stopRunningVM()
                        }
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: manager.currentlyRunningVZVM)
        .navigationTitle(manager.currentlyRunningVM == nil ? "No VM running" : manager.currentlyRunningVM!.config.name)
    }
}

#Preview {
    RunningVMView()
}
