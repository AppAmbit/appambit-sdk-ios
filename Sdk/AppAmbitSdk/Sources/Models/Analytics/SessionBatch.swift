import Foundation

struct SessionsPayload: Codable, DictionaryConvertible {
    let sessions: [SessionBatch]
    func toDictionary() -> [String: Any] { ["sessions": sessions.map { $0.toDictionary() }] }
}

struct SessionBatch: Codable, DictionaryConvertible {
    let id: String
    let sessionId: String?
    let startedAt: Date?
    let endedAt: Date?

    var fingerPrint: String? {
        guard let s = startedAt, let e = endedAt else { return nil }
        let a = DateUtils.utcIsoFormatString(from: s)
        let b = DateUtils.utcIsoFormatString(from: e)
        return "\(a)-\(b)"
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case startedAt = "started_at"
        case endedAt   = "ended_at"
    }

    init(id: String = "", sessionId: String? = nil, startedAt: Date? = nil, endedAt: Date? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let sidInt = try c.decodeIfPresent(Int.self, forKey: .sessionId) {
            self.sessionId = String(sidInt)
        } else {
            self.sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        }

        if let rawStart = try c.decodeIfPresent(String.self, forKey: .startedAt) {
            self.startedAt = Self.parse(rawStart)
        } else { self.startedAt = nil }

        if let rawEnd = try c.decodeIfPresent(String.self, forKey: .endedAt) {
            self.endedAt = Self.parse(rawEnd)
        } else { self.endedAt = nil }

        self.id = ""
    }

    static func parse(_ s: String) -> Date? {
        if let d = DateUtils.utcIso8601FullFormatDate(from: s) { return d }
        if s.hasSuffix("Z") {
            let alt = String(s.dropLast()) + "+0000"
            if let d = DateUtils.utcIsoFormatDate(from: alt) { return d }
        }
        return DateUtils.utcIsoFormatDate(from: s)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func isoWithZ(_ d: Date) -> String {
            let s = DateUtils.utcIsoFormatString(from: d)
            return s.hasSuffix("+0000") ? String(s.dropLast(5)) + "Z" : s
        }
        if let startedAt { try c.encode(isoWithZ(startedAt), forKey: .startedAt) }
        if let endedAt   { try c.encode(isoWithZ(endedAt),   forKey: .endedAt) }
    }

    func toDictionary() -> [String: Any] {
        func isoWithZ(_ d: Date) -> String {
            let s = DateUtils.utcIsoFormatString(from: d)
            return s.hasSuffix("+0000") ? String(s.dropLast(5)) + "Z" : s
        }
        return [
            "started_at": startedAt.map { isoWithZ($0) } ?? NSNull(),
            "ended_at":   endedAt.map   { isoWithZ($0) } ?? NSNull()
        ]
    }
}
