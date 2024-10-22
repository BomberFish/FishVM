// bomberfish
// FileManager+SwiftFriendly.swift – FishVM
// created on 2024-10-19

import Foundation

extension FileManager {
    /// Returns a Boolean value that indicates whether a file or directory exists at a specified path. Swift-friendly version.
    func fileExists(atPath path: String, isDirectory: inout Bool) -> Bool {
        var isDir : ObjCBool = false
        let res = self.fileExists(atPath: path, isDirectory: &isDir)
        isDirectory = isDir.boolValue
        return res
    }
}


