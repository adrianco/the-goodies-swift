import Foundation

/// Vector clock for distributed state tracking
public struct VectorClock: Codable, Equatable {
    public var clocks: [String: String]
    
    public init(clocks: [String: String] = [:]) {
        self.clocks = clocks
    }
    
    /// Increment clock for given node
    public mutating func increment(for nodeId: String) {
        let current = Int(clocks[nodeId] ?? "0") ?? 0
        clocks[nodeId] = String(current + 1)
    }
    
    /// Check if this clock happens before another
    public func happensBefore(_ other: VectorClock) -> Bool {
        // Check if all components of this clock are <= the other clock
        for (nodeId, value) in clocks {
            guard let thisTime = Int(value),
                  let otherValue = other.clocks[nodeId],
                  let otherTime = Int(otherValue) else {
                // If the other clock doesn't have this component, we can't say we happen before
                if other.clocks[nodeId] == nil && Int(value) ?? 0 > 0 {
                    return false
                }
                continue
            }
            
            if thisTime > otherTime {
                return false
            }
        }
        
        // Check if at least one component is strictly less
        var hasStrictlyLess = false
        for (nodeId, otherValue) in other.clocks {
            let thisValue = clocks[nodeId] ?? "0"
            guard let thisTime = Int(thisValue),
                  let otherTime = Int(otherValue) else {
                continue
            }
            
            if thisTime < otherTime {
                hasStrictlyLess = true
                break
            }
        }
        
        // Special case: if this clock is empty and other is not, we happen before
        if clocks.isEmpty && !other.clocks.isEmpty {
            hasStrictlyLess = true
        }
        
        return hasStrictlyLess || self == other
    }
    
    /// Check if clocks are concurrent (neither happens before the other)
    public func isConcurrent(with other: VectorClock) -> Bool {
        return !happensBefore(other) && !other.happensBefore(self) && self != other
    }
    
    /// Merge with another clock, taking maximum of each component
    public mutating func merge(with other: VectorClock) {
        for (nodeId, value) in other.clocks {
            if let currentValue = clocks[nodeId],
               let current = Int(currentValue),
               let other = Int(value) {
                clocks[nodeId] = String(max(current, other))
            } else if let _ = Int(value) {
                clocks[nodeId] = value
            }
        }
    }
    
    /// Create a new clock that is the merge of two clocks
    public func merged(with other: VectorClock) -> VectorClock {
        var result = self
        result.merge(with: other)
        return result
    }
    
    /// Check if this clock dominates another (all components >= other)
    public func dominates(_ other: VectorClock) -> Bool {
        for (nodeId, otherValue) in other.clocks {
            guard let thisValue = clocks[nodeId],
                  let thisTime = Int(thisValue),
                  let otherTime = Int(otherValue) else {
                // If we don't have a component that other has, we don't dominate
                if clocks[nodeId] == nil && Int(otherValue) ?? 0 > 0 {
                    return false
                }
                continue
            }
            
            if thisTime < otherTime {
                return false
            }
        }
        return true
    }
    
    /// Get the total sum of all clock values (useful for debugging)
    public var totalTime: Int {
        clocks.values.compactMap { Int($0) }.reduce(0, +)
    }
    
    /// Get a human-readable description
    public var description: String {
        if clocks.isEmpty {
            return "VectorClock(empty)"
        }
        
        let sorted = clocks.sorted { $0.key < $1.key }
        let components = sorted.map { "\($0.key):\($0.value)" }.joined(separator: ", ")
        return "VectorClock(\(components))"
    }
}