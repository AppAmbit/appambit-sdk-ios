import Foundation

@objcMembers
public final class CloudCode: NSObject {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var service: CloudCodeService?

    static func initialize(service: CloudCodeService) {
        lock.lock()
        self.service = service
        lock.unlock()
    }

    #if DEBUG
    static func resetForTesting() {
        lock.lock()
        service = nil
        lock.unlock()
    }
    #endif

    @discardableResult
    public static func call(
        _ function: String,
        method: CloudCodeHttpMethod = .post,
        query: [String: String]? = nil,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completion: @escaping @Sendable (CloudCodeResponse?, Error?) -> Void
    ) -> CloudCodeCancellationToken {
        guard let service = currentService() else {
            let token = CloudCodeCancellationToken()
            DispatchQueue.main.async {
                completion(nil, CloudCodeError.notInitialized)
            }
            return token
        }
        return service.call(
            function: function,
            method: method,
            query: query,
            body: body,
            headers: headers,
            completion: completion
        )
    }

    @nonobjc
    @discardableResult
    public static func call<T: Decodable>(
        _ function: String,
        method: CloudCodeHttpMethod = .post,
        query: [String: String]? = nil,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil,
        as type: T.Type,
        completion: @escaping @Sendable (CloudCodeResult<T>?, CloudCodeError?) -> Void
    ) -> CloudCodeCancellationToken {
        guard let service = currentService() else {
            let token = CloudCodeCancellationToken()
            DispatchQueue.main.async {
                completion(nil, CloudCodeError.notInitialized)
            }
            return token
        }
        return service.call(
            function: function,
            method: method,
            query: query,
            body: body,
            headers: headers,
            as: type,
            completion: completion
        )
    }

    private static func currentService() -> CloudCodeService? {
        lock.lock()
        defer { lock.unlock() }
        return service
    }
}
