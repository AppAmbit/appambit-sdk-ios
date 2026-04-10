import Foundation

private let getListLock = NSLock()

public final class CmsQuery<T: Decodable>: ICmsQuery, @unchecked Sendable {
    private let contentType: String
    private var whereClause: String = ""
    private var args: [String] = []
    private var orderBy: String?
    private var page: Int?
    private var perPage: Int?

    init(contentType: String) {
        self.contentType = contentType
    }

    private func addCondition(_ field: String, _ op: String, _ value: String) {
        if !whereClause.isEmpty { whereClause += " AND " }
        let lowerValue = value.lowercased()
        if lowerValue == "true" {
            whereClause += "json_extract(jitem.value, '$.\(field)') \(op) 1"
        } else if lowerValue == "false" {
            whereClause += "json_extract(jitem.value, '$.\(field)') \(op) 0"
        } else {
            whereClause += "json_extract(jitem.value, '$.\(field)') \(op) ?"
            args.append(value)
        }
    }

    private func addNumericCondition(_ field: String, _ op: String, _ value: Any) {
        if !whereClause.isEmpty { whereClause += " AND " }
        whereClause += "CAST(json_extract(jitem.value, '$.\(field)') AS REAL) \(op) ?"
        args.append("\(value)")
    }

    public func search(_ query: String) -> Self {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if !whereClause.isEmpty { whereClause += " AND " }
            whereClause += "jitem.value LIKE ?"
            args.append("%\(trimmed)%")
        }
        return self
    }

    public func equals(_ field: String, _ value: String) -> Self { addCondition(field, "=", value); return self }
    public func notEquals(_ field: String, _ value: String) -> Self { addCondition(field, "!=", value); return self }
    public func contains(_ field: String, _ value: String) -> Self { addCondition(field, "LIKE", "%\(value)%"); return self }
    public func startsWith(_ field: String, _ value: String) -> Self { addCondition(field, "LIKE", "\(value)%"); return self }
    public func greaterThan(_ field: String, _ value: Any) -> Self { addNumericCondition(field, ">", value); return self }
    public func greaterThanOrEqual(_ field: String, _ value: Any) -> Self { addNumericCondition(field, ">=", value); return self }
    public func lessThan(_ field: String, _ value: Any) -> Self { addNumericCondition(field, "<", value); return self }
    public func lessThanOrEqual(_ field: String, _ value: Any) -> Self { addNumericCondition(field, "<=", value); return self }

    public func inList(_ field: String, _ values: [String]) -> Self {
        if !whereClause.isEmpty { whereClause += " AND " }
        appendListCondition(field, values, negate: false)
        return self
    }

    public func notInList(_ field: String, _ values: [String]) -> Self {
        if !whereClause.isEmpty { whereClause += " AND " }
        appendListCondition(field, values, negate: true)
        return self
    }

    private func appendListCondition(_ field: String, _ values: [String], negate: Bool) {
        var plainValues: [String] = []
        var jsonValues: [String] = []

        for val in values {
            if let data = val.data(using: .utf8), let _ = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                jsonValues.append(val)
            } else {
                plainValues.append(val)
            }
        }

        if !negate {
            var orClauses: [String] = []

            if !plainValues.isEmpty {
                let placeholders = Array(repeating: "?", count: plainValues.count).joined(separator: ", ")
                orClauses.append("json_extract(jitem.value, '$.\(field)') IN (\(placeholders))")
                args.append(contentsOf: plainValues)
                    for plainVal in plainValues {
                    orClauses.append("EXISTS (SELECT 1 FROM json_each(json_extract(jitem.value, '$.\(field)')) WHERE json_each.value = ?)")
                    args.append(plainVal)
                }
            }

            for jsonVal in jsonValues {
                orClauses.append("json_extract(jitem.value, '$.\(field)') = json(?)")
                args.append(jsonVal)
            }

            if orClauses.isEmpty {
                whereClause += "1 = 0"
                return
            }

            if orClauses.count == 1 {
                whereClause += orClauses[0]
            } else {
                whereClause += "(" + orClauses.joined(separator: " OR ") + ")"
            }

        } else {
            var andClauses: [String] = []

            if !plainValues.isEmpty {
                let placeholders = Array(repeating: "?", count: plainValues.count).joined(separator: ", ")
                andClauses.append("json_extract(jitem.value, '$.\(field)') NOT IN (\(placeholders))")
                args.append(contentsOf: plainValues)
                for plainVal in plainValues {
                    andClauses.append("NOT EXISTS (SELECT 1 FROM json_each(json_extract(jitem.value, '$.\(field)')) WHERE json_each.value = ?)")
                    args.append(plainVal)
                }
            }

            for jsonVal in jsonValues {
                let extracted = "json_extract(jitem.value, '$.\(field)')"
                andClauses.append("(\(extracted) IS NULL OR \(extracted) != json(?))")
                args.append(jsonVal)
            }

            if andClauses.isEmpty {
                whereClause += "1 = 1"
                return
            }

            if andClauses.count == 1 {
                whereClause += andClauses[0]
            } else {
                whereClause += "(" + andClauses.joined(separator: " AND ") + ")"
            }
        }
    }

    public func orderByAscending(_ field: String) -> Self {
        self.orderBy = "json_extract(jitem.value, '$.\(field)') ASC"
        return self
    }

    public func orderByDescending(_ field: String) -> Self {
        self.orderBy = "json_extract(jitem.value, '$.\(field)') DESC"
        return self
    }

    public func getPage(_ page: Int) -> Self { self.page = page; return self }
    public func getPerPage(_ perPage: Int) -> Self { self.perPage = perPage; return self }

    public func getList(completion: @escaping @Sendable ([T]) -> Void) {
        if page == 0 || perPage == 0 { completion([]); return }
        let limit = perPage ?? -1
        let offset = perPage != nil ? ((page ?? 1) - 1) * perPage! : 0

        getListLock.lock()
        let isFetched = Cms.fetchedContentTypes.contains(contentType)
        getListLock.unlock()

        if isFetched {
            let cached = queryLocalCache(orderBy: orderBy, limit: limit, offset: offset)
            completion(cached)
            return
        }

        let cached = queryLocalCache(orderBy: orderBy, limit: limit, offset: offset)
        if cached.isEmpty {
            fetchAndReturn(orderBy: orderBy, limit: limit, offset: offset, completion: completion)
        } else {
            completion(cached)
            refreshCacheInBackground()
        }
    }

    private func queryLocalCache(orderBy: String?, limit: Int, offset: Int) -> [T] {
        do {
            let jsonList = try Cms.storageService.queryCmsData(
                contentType: contentType,
                whereClause: whereClause.isEmpty ? nil : whereClause,
                args: args.isEmpty ? nil : args,
                orderBy: orderBy,
                limit: limit,
                offset: offset
            )
            return jsonList.compactMap { Cms.decodeCmsItem($0) }
        } catch {
            return []
        }
    }

    private func fetchAndReturn(orderBy: String?, limit: Int, offset: Int, completion: @escaping @Sendable ([T]) -> Void) {
        fetchAllRemoteDataSync { _ in
            completion(self.queryLocalCache(orderBy: orderBy, limit: limit, offset: offset))
        }
    }

    private func refreshCacheInBackground() {
        fetchAllRemoteDataSync { _ in }
    }

    private func fetchAllRemoteDataSync(completion: @escaping @Sendable (Bool) -> Void) {
        let endpoint = CmsEndpoint(contentType: contentType, page: 1)
        
        Cms.apiService.executeRequest(endpoint, responseType: [String: JSONValue].self) { result in
            guard let responseDict = result.data else {
                debugPrint("Cms [fetch error]: Unable to decode JSON or response is nil. Result error: \(String(describing: result.errorType))")
                completion(false)
                return
            }

            Cms.fetchedContentTypes.insert(self.contentType)

            guard case let .array(dataArray) = responseDict["data"] else {
                self.storeRawDict(responseDict, completion: completion)
                return
            }

            var totalPages = 1
            if case let .object(metaObj) = responseDict["meta"],
               case let .int(lastPage) = metaObj["last_page"] {
                totalPages = lastPage
            }

            if totalPages <= 1 {
                self.storeRawDict(responseDict, completion: completion)
            } else {
                self.fetchRemainingPages(startPage: 2, totalPages: totalPages) { finalExtraItems in
                    var allItems = dataArray
                    allItems.append(contentsOf: finalExtraItems)
                    var localDict = responseDict
                    localDict["data"] = .array(allItems)
                    self.storeRawDict(localDict, completion: completion)
                }
            }
        }
    }

    private func fetchRemainingPages(startPage: Int, totalPages: Int, completion: @escaping @Sendable ([JSONValue]) -> Void) {
        
        @Sendable func fetchPage(_ page: Int, accumulatedItems: [JSONValue]) {
            guard page <= totalPages else {
                completion(accumulatedItems)
                return
            }

            let endpoint = CmsEndpoint(contentType: contentType, page: page)
            Cms.apiService.executeRequest(endpoint, responseType: [String: JSONValue].self) { result in
                var nextItems = accumulatedItems
                if let dict = result.data, case let .array(nextData) = dict["data"] {
                    nextItems.append(contentsOf: nextData)
                }
                fetchPage(page + 1, accumulatedItems: nextItems)
            }
        }

        fetchPage(startPage, accumulatedItems: [])
    }

    private func storeRawDict(_ dict: [String: JSONValue], completion: @escaping @Sendable (Bool) -> Void) {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(dict)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { completion(false); return }
            
            let existing = try? Cms.storageService.getCmsData(contentType)
            if existing == jsonString {
                debugPrint("Cms [store skip]: Data unchanged for \(contentType)")
                completion(true)
                return
            }
            
            try Cms.storageService.putCmsData(contentType, jsonString)
            completion(true)
        } catch {
            debugPrint("Cms [store error]: \(error)")
            completion(false)
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
