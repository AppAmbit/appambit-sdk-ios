import Foundation

enum Queues {
    static let state = DispatchQueue(label: "com.appambit.state", qos: .userInitiated)
    static let db = DispatchQueue(label: "com.appambit.db", qos: .utility)
    static let diskRoot = DispatchQueue(label: "com.appambit.disk.root", qos: .utility)

    static let crashFiles = DispatchQueue(
        label: "com.appambit.crash.files",
        qos: .utility,
        target: diskRoot
    )

    static let batch = DispatchQueue(label: "com.appambit.batch", qos: .utility)

    static let netDecode = DispatchQueue(
        label: "com.appambit.net.decode",
        qos: .userInitiated,
        attributes: .concurrent
    )

    static let token = DispatchQueue(
        label: "com.appambit.token",
        qos: .utility,
        attributes: .concurrent
    )
}
