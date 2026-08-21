import Foundation

@objcMembers
public final class CloudCodeCancellationToken: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}
