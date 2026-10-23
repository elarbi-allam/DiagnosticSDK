import Foundation

final class LockedValue<Value>: @unchecked Sendable {

    private let lock = NSLock()
    private var storedValue: Value

    init(_ initialValue: Value) {
        storedValue = initialValue
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func update(_ newValue: Value) {
        lock.lock()
        storedValue = newValue
        lock.unlock()
    }
}
