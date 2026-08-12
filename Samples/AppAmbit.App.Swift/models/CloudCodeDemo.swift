import Foundation

struct CloudCodeDemo: Identifiable {
    let id: String
    let section: String
    let title: String
    let slug: String
    let detail: String
    let prerequisite: String
    let action: CloudCodeDemoAction?
}

enum CloudCodeDemoAction {
    case setupDatabase
    case createTask
    case listTasks
    case completeTask
    case deleteTask
    case inspector
    case jsonValues
    case nullContract
    case responseShapes
    case controlledError
    case timeout
    case readPosts
    case publishPost
    case runtimeContext
    case push
    case createOrder
    case summary
}
