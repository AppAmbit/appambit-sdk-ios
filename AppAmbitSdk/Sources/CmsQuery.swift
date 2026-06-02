import Foundation

public final class CmsQuery<T: Decodable>: ICmsQuery, @unchecked Sendable {
    private let contentType: String
    private var queryParams: [(String, String)] = []
    private var isSearch: Bool = false

    init(contentType: String) {
        self.contentType = contentType
    }

    public func search(_ query: String) -> Self {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            isSearch = true
            queryParams.append(("q", trimmed))
        }
        return self
    }

    public func equals(_ field: String, _ value: String) -> Self {
        queryParams.append(("filter[\(field)]", value)); return self
    }

    public func notEquals(_ field: String, _ value: String) -> Self {
        queryParams.append(("filter[\(field)][neq]", value)); return self
    }

    public func contains(_ field: String, _ value: String) -> Self {
        queryParams.append(("filter[\(field)][contains]", value)); return self
    }

    public func startsWith(_ field: String, _ value: String) -> Self {
        queryParams.append(("filter[\(field)][starts_with]", value)); return self
    }

    public func greaterThan(_ field: String, _ value: Any) -> Self {
        queryParams.append(("filter[\(field)][gt]", "\(value)")); return self
    }

    public func greaterThanOrEqual(_ field: String, _ value: Any) -> Self {
        queryParams.append(("filter[\(field)][gte]", "\(value)")); return self
    }

    public func lessThan(_ field: String, _ value: Any) -> Self {
        queryParams.append(("filter[\(field)][lt]", "\(value)")); return self
    }

    public func lessThanOrEqual(_ field: String, _ value: Any) -> Self {
        queryParams.append(("filter[\(field)][lte]", "\(value)")); return self
    }

    public func inList(_ field: String, _ values: [String]) -> Self {
        queryParams.append(("filter[\(field)][in]", values.joined(separator: ","))); return self
    }

    public func notInList(_ field: String, _ values: [String]) -> Self {
        queryParams.append(("filter[\(field)][nin]", values.joined(separator: ","))); return self
    }

    public func orderByAscending(_ field: String) -> Self {
        queryParams.append(("sort", field)); return self
    }

    public func orderByDescending(_ field: String) -> Self {
        queryParams.append(("sort", "-\(field)")); return self
    }

    public func getPage(_ page: Int) -> Self {
        queryParams.append(("page", "\(page)")); return self
    }

    public func getPerPage(_ perPage: Int) -> Self {
        queryParams.append(("per_page", "\(perPage)")); return self
    }

    public func getList(completion: @escaping @Sendable ([T]) -> Void) {
        let endpoint = CmsEndpoint(contentType: contentType, queryItems: queryParams, isSearch: isSearch)
        Cms.apiService.executeRequest(endpoint, responseType: [String: JSONValue].self) { result in
            guard let responseDict = result.data else {
                debugPrint("Cms [fetch error]: \(String(describing: result.errorType))")
                completion([])
                return
            }
            guard case let .array(dataArray) = responseDict["data"] else {
                completion([])
                return
            }
            let items: [T] = dataArray.compactMap { Cms.decodeCmsItem($0) }
            completion(items)
        }
    }
}

// MARK: - ObjC Component

@objcMembers
public final class CmsQueryObjC: NSObject, @unchecked Sendable {
    private let contentType: String
    private let internalQuery: CmsQuery<JSONValue>

    init(contentType: String) {
        self.contentType = contentType
        self.internalQuery = CmsQuery<JSONValue>(contentType: contentType)
    }

    @objc(search:)
    public func search(_ query: String) -> Self { _ = internalQuery.search(query); return self }
    @objc(equals:value:)
    public func equals(_ field: String, _ value: String) -> Self { _ = internalQuery.equals(field, value); return self }
    @objc(notEquals:value:)
    public func notEquals(_ field: String, _ value: String) -> Self { _ = internalQuery.notEquals(field, value); return self }
    @objc(contains:value:)
    public func contains(_ field: String, _ value: String) -> Self { _ = internalQuery.contains(field, value); return self }
    @objc(startsWith:value:)
    public func startsWith(_ field: String, _ value: String) -> Self { _ = internalQuery.startsWith(field, value); return self }
    @objc(greaterThan:value:)
    public func greaterThan(_ field: String, _ value: Any) -> Self { _ = internalQuery.greaterThan(field, value); return self }
    @objc(greaterThanOrEqual:value:)
    public func greaterThanOrEqual(_ field: String, _ value: Any) -> Self { _ = internalQuery.greaterThanOrEqual(field, value); return self }
    @objc(lessThan:value:)
    public func lessThan(_ field: String, _ value: Any) -> Self { _ = internalQuery.lessThan(field, value); return self }
    @objc(lessThanOrEqual:value:)
    public func lessThanOrEqual(_ field: String, _ value: Any) -> Self { _ = internalQuery.lessThanOrEqual(field, value); return self }
    @objc(inList:values:)
    public func inList(_ field: String, _ values: [String]) -> Self { _ = internalQuery.inList(field, values); return self }
    @objc(notInList:values:)
    public func notInList(_ field: String, _ values: [String]) -> Self { _ = internalQuery.notInList(field, values); return self }
    @objc(orderByAscending:)
    public func orderByAscending(_ field: String) -> Self { _ = internalQuery.orderByAscending(field); return self }
    @objc(orderByDescending:)
    public func orderByDescending(_ field: String) -> Self { _ = internalQuery.orderByDescending(field); return self }
    @objc(getPage:)
    public func getPage(_ page: Int) -> Self { _ = internalQuery.getPage(page); return self }
    @objc(getPerPage:)
    public func getPerPage(_ perPage: Int) -> Self { _ = internalQuery.getPerPage(perPage); return self }

    @objc(getListWithCompletion:)
    public func getList(completion: @escaping @Sendable ([Any]) -> Void) {
        internalQuery.getList { items in
            completion(items.map { $0.toAny() })
        }
    }
}
