// bomberfish
// WindowAccessorView.swift – FishVM
// created on 2024-10-21

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            if let window = nsView.window {
                self.callback(window)
            }
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

