import Foundation

class EventBatchPayload: Codable, DictionaryConvertible {
    var events: [EventEntity]

    enum CodingKeys: String, CodingKey {
        case events = "events"
    }

    init(events: [EventEntity]) {
        self.events = events
    }

    func toDictionary() -> [String: Any] {
        let eventsArray = events.map { $0.toDictionary() }
        return ["events": eventsArray]
    }
}
