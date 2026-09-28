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
    let producer: @Sendable (Args) throws -> (any Sendable)
}

/// Represents a stub with a list of matchers to compare against invocation parameters, and an async return producer.
struct AsyncStub: AnyStub {
    let matchers: [AnyArgumentMatcher]
    let producer: @Sendable (Args) async throws -> (any Sendable)
}

/// Represents a stub with a list of matchers to compare against invocation parameters.
protocol AnyStub: Sendable {
    var matchers: [AnyArgumentMatcher] { get }
}

/// A container which wraps a set of arguments and provides strongly-typed conveniences for access.
public struct Args {
    public var count: Int { args.count }
    public var isEmpty: Bool { args.isEmpty }

    let args: [Any]

    init(_ args: [Any]) {
        self.args = args
    }

    public func getBool(at index: Int) -> Bool { self[index] }
    public func getDouble(at index: Int) -> Double { self[index] }
    public func getFloat(at index: Int) -> Float { self[index] }
    public func getInt(at index: Int) -> Int { self[index] }
    public func getString(at index: Int) -> String { self[index] }

    public subscript<T>(index: Int) -> T {
        args[index] as! T
    }
}
#endif
