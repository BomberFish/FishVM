// bomberfish
// main.swift – FishVM
// created on 2024-10-19

import Foundation
import OSLog
import SwiftUI
import AVFoundation

public let defaultLogger = Logger(subsystem: "FishVM", category: "General")

defaultLogger.notice("FishVM init")

public let vmPath: String = NSHomeDirectory() + "/Virtual Machines/"
public let vmURL: URL = .homeDirectory.appendingPathComponent("Virtual Machines")

var isDir = false
let res = FileManager.default.fileExists(atPath: vmPath, isDirectory: &isDir)
defaultLogger.debug("VM Directory \(res ? "exists" : "does not exist") and is\(isDir ? "" : " not") a directory.")

if res && !isDir {
    defaultLogger.warning("Removing non-directory VM item")
    try! FileManager.default.removeItem(atPath: vmPath)
}
    
if !res || res && !isDir {
    defaultLogger.info("Creating new VM Directory")
    try! FileManager.default.createDirectory(atPath: vmPath, withIntermediateDirectories: true)
}

Task {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: // The user has previously granted access to the camera.
        break
        
    case .notDetermined: // The user has not yet been asked for camera access.
        await AVCaptureDevice.requestAccess(for: .audio)
        
    case .denied: // The user has previously denied access.
        break
        
        
    case .restricted: // The user can't grant access due to restrictions.
        break
    default:
        break
    }
}
    
FishVMApp.main()
