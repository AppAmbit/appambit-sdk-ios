import Foundation

/// Returned by DB terminal operations. Call `cancel()` to suppress the completion
/// callback if it hasn't fired yet (e.g. the calling view controller was dismissed
/// before the response arrived).
@objcMembers
public final class DbCancellationToken: NSObject, @unchecked Sendable {

    private let lock = NSLock()
    private var _isCancelled = false

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCancelled
    }

    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        _isCancelled = true
    }
}
