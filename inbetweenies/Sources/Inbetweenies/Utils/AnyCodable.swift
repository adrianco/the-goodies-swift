import Foundation

/// Type-erased Codable wrapper for heterogeneous JSON
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Cannot encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Equatable Conformance

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case let (lhs as [Any], rhs as [Any]):
            return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { 
                AnyCodable($0.0) == AnyCodable($0.1)
            }
        case let (lhs as [String: Any], rhs as [String: Any]):
            return lhs.keys == rhs.keys && lhs.keys.allSatisfy { key in
                guard let lhsValue = lhs[key], let rhsValue = rhs[key] else { return false }
                return AnyCodable(lhsValue) == AnyCodable(rhsValue)
            }
        default:
            return false
        }
    }
}

// MARK: - Hashable Conformance

extension AnyCodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch value {
        case let bool as Bool:
            hasher.combine(bool)
        case let int as Int:
            hasher.combine(int)
        case let double as Double:
            hasher.combine(double)
        case let string as String:
            hasher.combine(string)
        case is NSNull:
            hasher.combine(0)
        default:
            hasher.combine(ObjectIdentifier(type(of: value)))
        }
    }
}

// MARK: - Convenience Accessors

public extension AnyCodable {
    var boolValue: Bool? {
        value as? Bool
    }
    
    var intValue: Int? {
        value as? Int
    }
    
    var doubleValue: Double? {
        value as? Double
    }
    
    var stringValue: String? {
        value as? String
    }
    
    var arrayValue: [Any]? {
        value as? [Any]
    }
    
    var dictionaryValue: [String: Any]? {
        value as? [String: Any]
    }
    
    var isNull: Bool {
        value is NSNull
    }
}