import Foundation

internal struct FlexibleDecoder: Decoder {
    let value: Any
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        if let arr = value as? [Any], arr.isEmpty {
            return KeyedDecodingContainer(FlexibleKeyedContainer<Key>(dict: [:], codingPath: codingPath))
        }
        guard let dict = value as? [String: Any] else {
            throw DecodingError.typeMismatch([String: Any].self,
                .init(codingPath: codingPath, debugDescription: "Expected a JSON object"))
        }
        return KeyedDecodingContainer(FlexibleKeyedContainer<Key>(dict: dict, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let arr = value as? [Any] else {
            throw DecodingError.typeMismatch([Any].self,
                .init(codingPath: codingPath, debugDescription: "Expected a JSON array"))
        }
        return FlexibleUnkeyedContainer(array: arr, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return FlexibleSingleValueContainer(value: value, codingPath: codingPath)
    }
}

// MARK: - Keyed Container

private struct FlexibleKeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    let dict: [String: Any]
    var codingPath: [CodingKey]
    var allKeys: [K] { dict.keys.compactMap { K(stringValue: $0) } }

    func contains(_ key: K) -> Bool { dict[key.stringValue] != nil }

    func decodeNil(forKey key: K) throws -> Bool {
        dict[key.stringValue] == nil || dict[key.stringValue] is NSNull
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        guard let val = dict[key.stringValue], !(val is NSNull) else { throw missing(key) }
        return "\(val)"
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        let val = dict[key.stringValue]
        if let b = val as? Bool { return b }
        if let n = val as? NSNumber { return n.boolValue }
        if let s = val as? String {
            if s.lowercased() == "true"  { return true  }
            if s.lowercased() == "false" { return false }
        }
        throw mismatch(Bool.self, key: key, found: val)
    }

    func decode(_ type: Double.Type,  forKey key: K) throws -> Double  { try num(key) { $0.doubleValue } }
    func decode(_ type: Float.Type,   forKey key: K) throws -> Float   { try num(key) { $0.floatValue  } }
    func decode(_ type: Int.Type,     forKey key: K) throws -> Int     { try num(key) { $0.intValue    } }
    func decode(_ type: Int8.Type,    forKey key: K) throws -> Int8    { try num(key) { Int8($0.intValue)    } }
    func decode(_ type: Int16.Type,   forKey key: K) throws -> Int16   { try num(key) { Int16($0.intValue)   } }
    func decode(_ type: Int32.Type,   forKey key: K) throws -> Int32   { try num(key) { Int32($0.intValue)   } }
    func decode(_ type: Int64.Type,   forKey key: K) throws -> Int64   { try num(key) { Int64($0.int64Value)  } }
    func decode(_ type: UInt.Type,    forKey key: K) throws -> UInt    { try num(key) { UInt($0.uintValue)    } }
    func decode(_ type: UInt8.Type,   forKey key: K) throws -> UInt8   { try num(key) { UInt8($0.uintValue)   } }
    func decode(_ type: UInt16.Type,  forKey key: K) throws -> UInt16  { try num(key) { UInt16($0.uintValue)  } }
    func decode(_ type: UInt32.Type,  forKey key: K) throws -> UInt32  { try num(key) { UInt32($0.uintValue)  } }
    func decode(_ type: UInt64.Type,  forKey key: K) throws -> UInt64  { try num(key) { UInt64($0.uint64Value) } }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        let val = dict[key.stringValue] ?? NSNull()
        return try T(from: FlexibleDecoder(value: val, codingPath: codingPath + [key]))
    }

    func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type, forKey key: K) throws -> KeyedDecodingContainer<NK> {
        let val = dict[key.stringValue] ?? [:]
        return try FlexibleDecoder(value: val, codingPath: codingPath + [key]).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        let val = dict[key.stringValue] ?? []
        return try FlexibleDecoder(value: val, codingPath: codingPath + [key]).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder { FlexibleDecoder(value: dict, codingPath: codingPath) }
    func superDecoder(forKey key: K) throws -> Decoder {
        FlexibleDecoder(value: dict[key.stringValue] ?? NSNull(), codingPath: codingPath + [key])
    }

    private func num<T>(_ key: K, extract: (NSNumber) -> T) throws -> T {
        let val = dict[key.stringValue]
        if let n = val as? NSNumber { return extract(n) }
        if let s = val as? String, let d = Double(s) { return extract(NSNumber(value: d)) }
        throw mismatch(T.self, key: key, found: val)
    }
    private func mismatch<T>(_ type: T.Type, key: K, found val: Any?) -> DecodingError {
        DecodingError.typeMismatch(type, .init(codingPath: codingPath + [key],
            debugDescription: "Cannot convert \(String(describing: val)) to \(type)"))
    }
    private func missing(_ key: K) -> DecodingError {
        DecodingError.keyNotFound(key, .init(codingPath: codingPath,
            debugDescription: "Key '\(key.stringValue)' not found"))
    }
}

// MARK: - Unkeyed Container

private struct FlexibleUnkeyedContainer: UnkeyedDecodingContainer {
    let array: [Any]
    var codingPath: [CodingKey]
    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }
    var currentIndex: Int = 0

    private struct _Key: CodingKey {
        var intValue: Int?
        var stringValue: String { "\(intValue ?? 0)" }
        init(intValue: Int) { self.intValue = intValue }
        init?(stringValue: String) { nil }
    }

    private mutating func pop() -> Any {
        defer { currentIndex += 1 }
        return array[currentIndex]
    }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd, array[currentIndex] is NSNull else { return false }
        currentIndex += 1; return true
    }

    mutating func decode(_ type: String.Type) throws -> String { "\(pop())" }
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        let v = pop()
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        if let s = v as? String, let b = Bool(s.lowercased()) { return b }
        throw typeMismatch(Bool.self, value: v)
    }
    mutating func decode(_ type: Double.Type,  ) throws -> Double  { try num { $0.doubleValue } }
    mutating func decode(_ type: Float.Type,   ) throws -> Float   { try num { $0.floatValue  } }
    mutating func decode(_ type: Int.Type,     ) throws -> Int     { try num { $0.intValue    } }
    mutating func decode(_ type: Int8.Type,    ) throws -> Int8    { try num { Int8($0.intValue)    } }
    mutating func decode(_ type: Int16.Type,   ) throws -> Int16   { try num { Int16($0.intValue)   } }
    mutating func decode(_ type: Int32.Type,   ) throws -> Int32   { try num { Int32($0.intValue)   } }
    mutating func decode(_ type: Int64.Type,   ) throws -> Int64   { try num { Int64($0.int64Value)  } }
    mutating func decode(_ type: UInt.Type,    ) throws -> UInt    { try num { UInt($0.uintValue)    } }
    mutating func decode(_ type: UInt8.Type,   ) throws -> UInt8   { try num { UInt8($0.uintValue)   } }
    mutating func decode(_ type: UInt16.Type,  ) throws -> UInt16  { try num { UInt16($0.uintValue)  } }
    mutating func decode(_ type: UInt32.Type,  ) throws -> UInt32  { try num { UInt32($0.uintValue)  } }
    mutating func decode(_ type: UInt64.Type,  ) throws -> UInt64  { try num { UInt64($0.uint64Value) } }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let key = _Key(intValue: currentIndex)
        return try T(from: FlexibleDecoder(value: pop(), codingPath: codingPath + [key]))
    }

    mutating func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type) throws -> KeyedDecodingContainer<NK> {
        let key = _Key(intValue: currentIndex)
        return try FlexibleDecoder(value: pop(), codingPath: codingPath + [key]).container(keyedBy: type)
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let key = _Key(intValue: currentIndex)
        return try FlexibleDecoder(value: pop(), codingPath: codingPath + [key]).unkeyedContainer()
    }
    mutating func superDecoder() throws -> Decoder {
        FlexibleDecoder(value: pop(), codingPath: codingPath)
    }

    private mutating func num<T>(_ extract: (NSNumber) -> T) throws -> T {
        let v = pop()
        if let n = v as? NSNumber { return extract(n) }
        if let s = v as? String, let d = Double(s) { return extract(NSNumber(value: d)) }
        throw typeMismatch(T.self, value: v)
    }
    private func typeMismatch<T>(_ type: T.Type, value: Any) -> DecodingError {
        DecodingError.typeMismatch(type, .init(codingPath: codingPath,
            debugDescription: "Cannot decode \(type) from \(value)"))
    }
}

// MARK: - Single Value Container

private struct FlexibleSingleValueContainer: SingleValueDecodingContainer {
    let value: Any
    var codingPath: [CodingKey]

    func decodeNil() -> Bool { value is NSNull }
    func decode(_ type: String.Type) throws -> String { "\(value)" }
    func decode(_ type: Bool.Type) throws -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String {
            if s.lowercased() == "true"  { return true  }
            if s.lowercased() == "false" { return false }
        }
        throw mismatch(Bool.self)
    }
    func decode(_ type: Double.Type,  ) throws -> Double  { try num { $0.doubleValue } }
    func decode(_ type: Float.Type,   ) throws -> Float   { try num { $0.floatValue  } }
    func decode(_ type: Int.Type,     ) throws -> Int     { try num { $0.intValue    } }
    func decode(_ type: Int8.Type,    ) throws -> Int8    { try num { Int8($0.intValue)    } }
    func decode(_ type: Int16.Type,   ) throws -> Int16   { try num { Int16($0.intValue)   } }
    func decode(_ type: Int32.Type,   ) throws -> Int32   { try num { Int32($0.intValue)   } }
    func decode(_ type: Int64.Type,   ) throws -> Int64   { try num { Int64($0.int64Value)  } }
    func decode(_ type: UInt.Type,    ) throws -> UInt    { try num { UInt($0.uintValue)    } }
    func decode(_ type: UInt8.Type,   ) throws -> UInt8   { try num { UInt8($0.uintValue)   } }
    func decode(_ type: UInt16.Type,  ) throws -> UInt16  { try num { UInt16($0.uintValue)  } }
    func decode(_ type: UInt32.Type,  ) throws -> UInt32  { try num { UInt32($0.uintValue)  } }
    func decode(_ type: UInt64.Type,  ) throws -> UInt64  { try num { UInt64($0.uint64Value) } }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: FlexibleDecoder(value: value, codingPath: codingPath))
    }

    private func num<T>(_ extract: (NSNumber) -> T) throws -> T {
        if let n = value as? NSNumber { return extract(n) }
        if let s = value as? String, let d = Double(s) { return extract(NSNumber(value: d)) }
        throw mismatch(T.self)
    }
    private func mismatch<T>(_ type: T.Type) -> DecodingError {
        DecodingError.typeMismatch(type, .init(codingPath: codingPath,
            debugDescription: "Cannot decode \(type) from \(value)"))
    }
}

// MARK: - JSON Handling

public enum JSONValue: Codable, @unchecked Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Bool.self) { self = .bool(x) }
        else if let x = try? container.decode(Int.self) { self = .int(x) }
        else if let x = try? container.decode(Double.self) { self = .double(x) }
        else if let x = try? container.decode(String.self) {
            if let intVal = Int(x) { self = .int(intVal) }
            else if let doubleVal = Double(x) { self = .double(doubleVal) }
            else if x.lowercased() == "true" { self = .bool(true) }
            else if x.lowercased() == "false" { self = .bool(false) }
            else { self = .string(x) }
        }
        else if let x = try? container.decode([String: JSONValue].self) { self = .object(x) }
        else if let x = try? container.decode([JSONValue].self) { self = .array(x) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Wrong type for JSONValue") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .int(let x): try container.encode(x)
        case .double(let x): try container.encode(x)
        case .bool(let x): try container.encode(x)
        case .object(let x): try container.encode(x)
        case .array(let x): try container.encode(x)
        case .null: try container.encodeNil()
        }
    }

    public func toAny() -> Any {
        switch self {
        case .string(let x): return x
        case .int(let x): return x
        case .double(let x): return x
        case .bool(let x): return x
        case .object(let x): return x.mapValues { $0.toAny() }
        case .array(let x): return x.map { $0.toAny() }
        case .null: return NSNull()
        }
    }
}

public struct AnyDecodable: Decodable, CustomStringConvertible, @unchecked Sendable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let string = try? container.decode(String.self) {
            if let intVal = Int(string) { value = intVal }
            else if let doubleVal = Double(string) { value = doubleVal }
            else if string.lowercased() == "true" { value = true }
            else if string.lowercased() == "false" { value = false }
            else { value = string }
        }
        else if let dict = try? container.decode([String: AnyDecodable].self) { value = dict }
        else if let array = try? container.decode([AnyDecodable].self) { value = array }
        else if container.decodeNil() { value = "null" }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable invalid") }
    }
    
    public var description: String {
        if let dict = value as? [String: AnyDecodable] {
            return "{" + dict.map { "\($0.key): \($0.value.description)" }.joined(separator: ", ") + "}"
        }
        if let array = value as? [AnyDecodable] {
            return "[" + array.map { $0.description }.joined(separator: ", ") + "]"
        }
        return "\(value)"
    }
}
