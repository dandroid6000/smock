//
//  Stub.swift
//  Smock
//
//  Created by Dan Kane on 9/28/26.
//

#if DEBUG
/// Represents a stub with a list of matchers to compare against invocation parameters, and a return producer.
struct Stub: AnyStub {
    let matchers: [AnyArgumentMatcher]

    /// A return value producer.
    let producer: @Sendable (Args) throws -> (any Sendable)
}

/// Represents a stub with a list of matchers to compare against invocation parameters, and an async return producer.
struct AsyncStub: AnyStub {
    let matchers: [AnyArgumentMatcher]

    /// An async return value producer.
    let producer: @Sendable (Args) async throws -> (any Sendable)
}

/// Represents a stub with a list of matchers to compare against invocation parameters.
protocol AnyStub: Sendable {
    /// Matchers to compare against invocation parameters.
    var matchers: [AnyArgumentMatcher] { get }
}

/// A container which wraps a set of arguments and provides strongly-typed conveniences for access.
public struct Args {
    /// Argument errors.
    enum Error: Swift.Error {
        /// An invalid type was supplied when retrieving an argument.
        case invalidType
    }

    /// The number of arguments.
    public var count: Int { args.count }
    /// True if there are no arguments.
    public var isEmpty: Bool { args.isEmpty }

    /// The stored arguments.
    let args: [Any]

    init(_ args: [Any]) {
        self.args = args
    }

    /// Gets a `Bool` value at the given `index`.
    public func getBool(at index: Int) throws -> Bool { try self[index] }

    /// Gets a `Double` value at the given `index`.
    public func getDouble(at index: Int) throws -> Double { try self[index] }

    /// Gets a `Float` value at the given `index`.
    public func getFloat(at index: Int) throws -> Float { try self[index] }

    /// Gets an `Int` value at the given `index`.
    public func getInt(at index: Int) throws -> Int { try self[index] }

    /// Gets a `String` value at the given `index`.
    public func getString(at index: Int) throws -> String { try self[index] }

    /// Gets the value at the given `index` and casts it to `T`.
    ///
    /// - throws Error.invalidType if the cast fails.
    public subscript<T>(index: Int) -> T {
        get throws {
            guard let arg = args[index] as? T else {
                throw Error.invalidType
            }
            return arg
        }
    }
}
#endif
