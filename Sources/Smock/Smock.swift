// The Swift Programming Language
// https://docs.swift.org/swift-book

#if swift(>=6.0)
import Synchronization
#else
// Fallback to swift-mutex implementation
import Mutex
#endif

import IssueReporting

/// Marks this type as `Mockable`, generating associated types including a `Mock`, `StubBuilder`, and `Verifier`, as well as typed functions
/// for generating instances.
///
/// Types are conditionally compiled for DEBUG builds only, as they are intended to only be used in tests.
///
/// - Note: This macro can only be attached to a `protocol` definition.
@attached(peer, names: suffixed(Mock), suffixed(StubBuilder), suffixed(Verifier), named(when), named(verify))
public macro Mockable() = #externalMacro(module: "SmockMacros", type: "MockableMacro")

#if DEBUG
enum SmockError: Error {
    case strict
    case stubNotFound
}

/// The base class for all mocks, including internal functionality for stubbing and retrieving values, as well as tracking and verifying member invocations.
// Note: Class is non-final, so cannot directly conform to Sendable
// - Applying @unchecked and using Mutex to ensure thread safety
open class Smock<T>: @unchecked Sendable {
    /// Indicates whether the mock will assume reasonable return values (e.g. `Void` or `nil`)  when members are not stubbed.
    public let relaxed: Bool

    /// Generic type is needed to generate type-specific `when` methods that instantiate the correct stubber
    let mockedType: T.Type = T.self

    private let metadata = Mutex<[String: SmockMetadata]>([:])

    /// Creates a new instance of the mock.
    ///
    /// - parameter relaxed: If `true`, the mock will assume reasonable return values (e.g. `Void` or `nil`)  when members are not stubbed.
    public required init(relaxed: Bool = false) {
        self.relaxed = relaxed
    }

    /// Tracks a method invocation by its signature and associated parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackMethod<each P: Sendable>(_ signature: String, params: repeat each P) {
        var paramArray: [any Sendable] = []
        repeat paramArray.append(each params)
        print("Tracked method: \(signature) with params: \(paramArray)")
        let call = Call(params: paramArray)
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Tracks a property getter by its signature.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackGetter(_ signature: String) {
        print("Tracked getter: \(signature)")
        let call = Call(params: []) // Empty params implies a `get` operation
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Tracks a property setter by its signature and assigned value.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackSetter<V: Sendable>(_ signature: String, value: V) {
        print("Tracked setter: \(signature), value: \(value)")
        let call = Call(params: [value])
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Gets the next stubbed value for a member with the given signature that matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func getValue<each P, R>(for signature: String, params: repeat each P) throws -> R {
        let paramArray = toParamArray(repeat each params)
        print("Getting value for: \(signature) with params: \(paramArray)")

        let stub: Stub? = metadata.withLock { allMetadata in
            allMetadata[signature]?.getNextStub(matching: paramArray)
        }

        guard let stub else {
            return relaxedDefault("No matching stubs for `\(signature)` with params: \(paramArray)")
        }

        let args = Args(paramArray)
        guard let value = try stub.producer(args) as? R else {
            preconditionFailure("Incorrect type stubbed for `\(signature)` with params: \(paramArray)")
        }

        return value
    }

    /// Gets the next stubbed value for a member with the given signature that matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func getValue<each P, R>(for signature: String, params: repeat each P) async throws -> R {
        let paramArray = toParamArray(repeat each params)
        print("Getting value for: \(signature) with params: \(paramArray)")

        let stub: AsyncStub? = metadata.withLock { allMetadata in
            allMetadata[signature]?.getNextStub(matching: paramArray)
        }

        guard let stub else {
            return relaxedDefault("No matching stubs for `\(signature)` with params: \(paramArray)")
        }

        let args = Args(paramArray)
        guard let value = try await stub.producer(args) as? R else {
            preconditionFailure("Incorrect type stubbed for `\(signature)` with params: \(paramArray)")
        }

        return value
    }

    // Used by (Throwing)ReturnBuilder classes
    func stubProducer(
        _ producer: @escaping @Sendable (Args) throws -> (any Sendable),
        for signature: String,
        params: [AnyArgumentMatcher]
    ) {
        getOrCreateMetadata(for: signature)
            .addStub(Stub(matchers: params, producer: producer))
    }

    // Used by Async(Throwing)ReturnBuilder classes
    func stubAsyncProducer(
        _ producer: @escaping @Sendable (Args) async throws -> (any Sendable),
        for signature: String,
        params: [AnyArgumentMatcher]
    ) {
        getOrCreateMetadata(for: signature)
            .addStub(AsyncStub(matchers: params, producer: producer))
    }

    // Used by Verifier classes
    func verifyCalls(for signature: String, matching params: [AnyArgumentMatcher]) -> [Call] {
        metadata.withLock { allMetadata in
            guard let metadata = allMetadata[signature] else {
                print("No calls for `\(signature)`")
                return []
            }

            print("Verifying: \(signature) with params: \(params)")

            return metadata.verifyCalls(matching: params)
        }
    }

    // Used by verifyNoInteractions
    fileprivate func getAllCalls() -> [VerificationResult] {
        metadata.withLock { allMetadata in
            allMetadata.compactMap { (signature, metadata) in
                let calls = metadata.allCalls()
                guard !calls.isEmpty else { return nil }
                return VerificationResult(signature: signature, calls: calls, filePath: "", line: 0) // file/line are ignored
            }
        }
    }

    // Used by verifyNoMoreInteractions
    fileprivate func getUnverifiedCalls() -> [VerificationResult] {
        metadata.withLock { allMetadata in
            allMetadata.reduce(into: []) { unverified, metadata in
                let signature = metadata.key
                let calls = metadata.value.unverifiedCalls()
                if !calls.isEmpty {
                    let result = VerificationResult(signature: signature, calls: calls, filePath: "", line: 0) // file/line are ignored
                    unverified.append(result)
                }
            }
        }
    }

    private func getOrCreateMetadata(for signature: String) -> SmockMetadata {
        metadata.withLock { allMetadata in
            allMetadata[signature] ?? {
                let new = SmockMetadata()
                allMetadata[signature] = new
                return new
            }()
        }
    }

    private func relaxedDefault<R>(_ description: String) -> R {
        switch R.self {
        // Void
        case is Void.Type where relaxed:
            () as! R

        // Optionals
        case let type as any ExpressibleByNilLiteral.Type where relaxed:
            type.init(nilLiteral: ()) as! R

        default:
            preconditionFailure(description)
        }
    }
}

/// Asserts that no invocations occurred on the given mock.
public func verifyNoInteractions<T>(_ mock: Smock<T>, filePath: StaticString = #filePath, line: UInt = #line) {
    let allCalls = mock.getAllCalls()
    if !allCalls.isEmpty {
        let callMap = allCalls.flatMap { result in
            result.calls.map { result.description(for: $0) }
        }.joined(separator: "\n\t")
        reportIssue("Expected no calls; found...\n\t\(callMap)", filePath: filePath, line: line)
    }
}

/// Asserts that all invocations on the given mock have been verified.
public func verifyNoMoreInteractions<T>(_ mock: Smock<T>, filePath: StaticString = #filePath, line: UInt = #line) {
    let unverified = mock.getUnverifiedCalls()
    if !unverified.isEmpty {
        let callMap = unverified.flatMap { result in
            result.calls.map { result.description(for: $0) }
        }.joined(separator: "\n\t")
        reportIssue("Unverified calls remaining...\n\t\(callMap)", filePath: filePath, line: line)
    }
}

// MARK: - SmockMetadata

/// Internal class for holding metata for a given member, including stubs and invocation history.
///
/// As a `Sendable`, non-isolated class, all data is stored using Mutexes to ensure thread safety.
final class SmockMetadata: Sendable {
    // Cannot expose mutable properties on Sendable type -> use Mutex
    private let _stubs = Mutex<[AnyStub]>([])
    private let _calls = Mutex<[Call]>([])

    func addStub(_ stub: AnyStub) {
        _stubs.withLock { $0.append(stub) }
    }

    func addCall(_ call: Call) {
        _calls.withLock { $0.append(call) }
    }

    /// Retrieves the next stub matching the given params. If there is more than one match, the first stub will be 'consumed' until there is
    /// only one left, which will be returned indefinitely. If the stub is an error, it will be thrown.
    func getNextStub<T: AnyStub>(matching params: [Any]) -> T? {
        _stubs.withLock { stubs in
            guard !stubs.isEmpty else { return nil }

            // Filter stubs by matching params (includes .any)
            let matches = stubs.enumerated().filter { (_, stub) in
                stub is T && zip(stub.matchers, params).allSatisfy { $0.matches($1) }
            }

            guard !matches.isEmpty else { return nil }

            let match = matches[0]
            // The last stub gets returned indefinitely, others are consumed
            if matches.count > 1 {
                stubs.remove(at: match.offset)
            }

            return match.element as? T // Will always be T due to filter
        }
    }

    /// Retrieves all calls matching the given parameters. The first *unverified* maching call will be marked as verified.
    func verifyCalls(matching params: [AnyArgumentMatcher]) -> [Call] {
        _calls.withLock { calls in
            guard !calls.isEmpty else { return [] }

            // Find all calls matching params, marking the first unverified call
            var didVerify: Bool = false
            return calls.indices.reduce(into: []) { matches, index in
                var call = calls[index]

                // Methods will always have the same count
                let isMatch = if call.params.count == params.count {
                    // All parameters must match
                    zip(params, call.params).allSatisfy { (matcher, callParam) in
                        matcher.matches(callParam)
                    }
                } else {
                    // Property getters (0 params) and setters (1 param) should not match each other
                    false
                }

                if isMatch {
                    // Track verification
                    if !call.isVerified, !didVerify {
                        call.isVerified = true
                        calls[index] = call // replace with mutated call
                        didVerify = true
                    }
                    matches.append(call)
                }
            }
        }
    }

    /// Retrieves all recorded calls.
    func allCalls() -> [Call] {
        _calls.withLock { $0 }
    }

    /// Retrieves all calls that have not been marked as verified.
    func unverifiedCalls() -> [Call] {
        _calls.withLock { $0.filter { !$0.isVerified }  }
    }
}

private func toParamArray<each P>(_ params: repeat each P) -> [Any] {
    var paramArray: [Any] = []
    repeat paramArray.append(each params)
    return paramArray
}

/// Represents a member invocation, tracking when it occurred, what parameters were supplied (if any), and whether or not it has been verified.
struct Call: Sendable {
    let timestamp: ContinuousClock.Instant = ContinuousClock.now
    let params: [any Sendable]
    var isVerified: Bool = false
}

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
