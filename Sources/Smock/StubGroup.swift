//
//  StubGroup.swift
//  Smock
//
//  Created by Dan Kane on 9/28/26.
//

#if DEBUG
/// Represents a sequential group of stubs with a list of matchers to compare against invocation parameters.
struct StubGroup: Sendable {
    let id: Int
    let matchers: [AnyArgumentMatcher]
    private(set) var producers: [AnyProducer] = []

    // Tracks how many times this stub group has been invoked
    private(set) var executionCount = 0

    /// Adds the given `producer` to the stored list.
    mutating func addProducer(_ producer: AnyProducer) {
        producers.append(producer)
    }

    /// Returns the next producer in the sequence, capping at the last one
    mutating func nextProducer() -> AnyProducer {
        let index = min(executionCount, producers.count - 1)
        executionCount += 1
        return producers[index]
    }

    /// Returns `true` if the given `params` satisfy the stored `matchers`.
    func matches(params: [Any]) -> Bool {
        zip(matchers, params).allSatisfy { $0.matches($1) }
    }
}

// MARK: - Producer

/// Represents a closure that accepts `Args` and returns a value.
struct Producer: AnyProducer {
    let producer: @Sendable (Args) throws -> any Sendable

    init(_ producer: @Sendable @escaping (Args) throws -> any Sendable) {
        self.producer = producer
    }

    func callAsFunction(_ params: [Any]) throws -> any Sendable {
        let args = Args(params)
        return try producer(args)
    }
}

/// Represents an async closure that accepts `Args` and returns a value.
struct AsyncProducer: AnyProducer {
    let producer: @Sendable (Args) async throws -> any Sendable

    init(_ producer: @Sendable @escaping (Args) async throws -> any Sendable) {
        self.producer = producer
    }

    func callAsFunction(_ params: [Any]) async throws -> any Sendable {
        let args = Args(params)
        return try await producer(args)
    }
}

/// Represents `Producer` or `AsyncProducer`.
protocol AnyProducer: Sendable {}

// MARK: - Args

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
    public func getBool(at index: Int) -> Bool { self[index] }

    /// Gets a `Double` value at the given `index`.
    public func getDouble(at index: Int) -> Double { self[index] }

    /// Gets a `Float` value at the given `index`.
    public func getFloat(at index: Int) -> Float { self[index] }

    /// Gets an `Int` value at the given `index`.
    public func getInt(at index: Int) -> Int { self[index] }

    /// Gets a `String` value at the given `index`.
    public func getString(at index: Int) -> String { self[index] }

    /// Gets the value at the given `index` and casts it to `T`.
    public func get<T>(_ type: T.Type = T.self, at index: Int) -> T { self[index] }

    /// Gets the value at the given `index` and casts it to `T`.
    public subscript<T>(index: Int) -> T {
        get {
            guard let arg = args[index] as? T else {
                preconditionFailure("Invalid type for argument at index \(index): \(T.self)")
            }
            return arg
        }
    }
}
#endif
