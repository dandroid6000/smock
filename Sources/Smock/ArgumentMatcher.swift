//
//  ArgumentMatcher.swift
//  Smock
//
//  Created by Dan Kane on 6/16/26.
//

/// A typed matcher that can be used to stub or verify mock behavior.
///
/// The matcher can be initialized by most literal types, or using the `.any` or `.equalTo(_:)` cases.
public enum ArgumentMatcher<T: Sendable>: AnyArgumentMatcher {
    /// Matches any argument.
    ///
    /// - parameter type: The argument type. Defaults to `T.self`, but can be passed explicitly to disambiguate
    ///                   methods with overloaded argument types.
    case any(T.Type = T.self)

    /// Matches arguments equal to the provided value.
    ///
    /// - Note: Values conforming to `Equatable` will be evaluated as such. Non-Equatable reference types will be evaluated
    /// as matching if and only if they refer to the same object (`===` semantics). Non-Equatable value types will never match.
    case equalTo(T)

    func matches(_ other: Any) -> Bool {
        // Ensure types match
        guard other is T else { return false }

        // Always match .any
        guard case .equalTo(let value) = self else { return true }

        if let equatableValue = value as? any Equatable {
            // Compare if Equatable
            return Self.isEqual(equatableValue, other)
        } else {
            // Fallback to reference identity (will be false for value types)
            let valueRef = value as AnyObject
            let otherRef = other as AnyObject
            return valueRef === otherRef
        }
    }
}

// MARK: Literal conformance

// e.g., `true` is interpreted as `.equalTo(true)`
extension ArgumentMatcher: ExpressibleByBooleanLiteral where T == BooleanLiteralType {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .equalTo(value)
    }
}

// e.g., `2` is interpreted as `.equalTo(2)`
extension ArgumentMatcher: ExpressibleByIntegerLiteral where T == IntegerLiteralType {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .equalTo(value)
    }
}

// e.g., `1.5` is interpreted as `.equalTo(1.5)`
extension ArgumentMatcher: ExpressibleByFloatLiteral where T == FloatLiteralType {
    public init(floatLiteral value: FloatLiteralType) {
        self = .equalTo(value)
    }
}

// e.g., `"foo"` is interpreted as `.equalTo("foo")`
extension ArgumentMatcher: ExpressibleByStringLiteral, ExpressibleByExtendedGraphemeClusterLiteral, ExpressibleByUnicodeScalarLiteral where T == StringLiteralType {
    public init(stringLiteral value: StringLiteralType) {
        self = .equalTo(value)
    }

    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self = .equalTo(value)
    }

    public init(unicodeScalarLiteral value: StringLiteralType) {
        self = .equalTo(value)
    }
}

// e.g., `[1,2,3]` is interpreted as `.equalTo([1,2,3])`
extension ArgumentMatcher: ExpressibleByArrayLiteral where T: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: T.ArrayLiteralElement...) {
        if let array = elements as? T {
            self = .equalTo(array)
        } else {
            fatalError("Unsupported array literal for \(T.self)")
        }
    }
}

// e.g., `{"id":123}` is interpreted as `.equalTo({"id":123})`
extension ArgumentMatcher: ExpressibleByDictionaryLiteral where T: ExpressibleByDictionaryLiteral, T.Key: Hashable {
    public init(dictionaryLiteral elements: (T.Key, T.Value)...) {
        if let dictionary = Dictionary(uniqueKeysWithValues: elements) as? T {
            self = .equalTo(dictionary)
        } else {
            fatalError("Unsupported dictionary literal for \(T.self)")
        }
    }
}

// MARK: - AnyArgumentMatcher

// Type-erased protocol
protocol AnyArgumentMatcher: Sendable {
    /// Indicates whether this matcher matches the value of `other`.
    func matches(_ other: Any) -> Bool
}

extension AnyArgumentMatcher {
    /// Generic method to cast and compare Equatable types
    static func isEqual<T: Equatable>(_ lhs: T, _ rhs: Any) -> Bool {
        guard let rhsTyped = rhs as? T else { return false }
        return lhs == rhsTyped
    }
}
