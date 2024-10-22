// bomberfish
// String+LocalizedError.swift – FishVM
// created on 2024-10-19

import Foundation

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? {
        return self
    }
}
