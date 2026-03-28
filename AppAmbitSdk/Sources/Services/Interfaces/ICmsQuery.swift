import Foundation

public protocol ICmsQuery {
    associatedtype T: Decodable
    func search(_ query: String) -> Self
    func equals(_ field: String, _ value: String) -> Self
    func notEquals(_ field: String, _ value: String) -> Self
    func contains(_ field: String, _ value: String) -> Self
    func startsWith(_ field: String, _ value: String) -> Self
    func greaterThan(_ field: String, _ value: Any) -> Self
    func greaterThanOrEqual(_ field: String, _ value: Any) -> Self
    func lessThan(_ field: String, _ value: Any) -> Self
    func lessThanOrEqual(_ field: String, _ value: Any) -> Self
    func inList(_ field: String, _ values: [String]) -> Self
    func notInList(_ field: String, _ values: [String]) -> Self
    func orderByAscending(_ field: String) -> Self
    func orderByDescending(_ field: String) -> Self
    func getPage(_ page: Int) -> Self
    func getPerPage(_ perPage: Int) -> Self
    func getList(completion: @escaping @Sendable ([T]) -> Void)
}
