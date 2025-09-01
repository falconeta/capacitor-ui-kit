import Foundation

@objc public class CapacitorUIKit: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
