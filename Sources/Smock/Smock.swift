// The Swift Programming Language
// https://docs.swift.org/swift-book

#if swift(>=6.0)
import Synchronization
#else
// Fallback to swift-mutex implementation
import Mutex
#endif

import IssueReporting

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
        print("Tracked method: \(Call.description(for: signature, params: paramArray))")
        let call = Call(params: paramArray)
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Tracks a property getter by its signature.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackGetter(_ signature: String) {
        print("Tracked getter: \(Call.description(for: signature))")
        let call = Call(params: []) // Empty params implies a `get` operation
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Tracks a property setter by its signature and assigned value.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackSetter<V: Sendable>(_ signature: String, value: V) {
        print("Tracked setter: \(Call.description(for: signature, params: [value]))")
        let call = Call(params: [value])
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Gets the next stubbed value for a member with the given signature that matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func getValue<each P, R>(for signature: String, params: repeat each P) throws -> R {
        let paramArray = toParamArray(repeat each params)
        print("Getting value for: \(Call.description(for: signature, params: paramArray))")

        let stub: Stub? = metadata.withLock { allMetadata in
            allMetadata[signature]?.getNextStub(matching: paramArray)
        }

        guard let stub else {
            return relaxedDefault("No matching stubs for \(Call.description(for: signature, params: paramArray))")
        }

        let args = Args(paramArray)
        guard let value = try stub.producer(args) as? R else {
            preconditionFailure("Incorrect type stubbed for \(Call.description(for: signature, params: paramArray))")
        }

        return value
    }

    /// Gets the next stubbed value for a member with the given signature that matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func getValue<each P, R>(for signature: String, params: repeat each P) async throws -> R {
        let paramArray = toParamArray(repeat each params)
        print("Getting value for: \(Call.description(for: signature, params: paramArray))")

        let stub: AsyncStub? = metadata.withLock { allMetadata in
            allMetadata[signature]?.getNextStub(matching: paramArray)
        }

        guard let stub else {
            return relaxedDefault("No matching stubs for \(Call.description(for: signature, params: paramArray))")
        }

        let args = Args(paramArray)
        guard let value = try await stub.producer(args) as? R else {
            preconditionFailure("Incorrect type stubbed for \(Call.description(for: signature, params: paramArray))")
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
            print("Verifying \(Call.description(for: signature, params: params))")
            return allMetadata[signature]?.verifyCalls(matching: params) ?? []
        }
    }

    // Used by verifyNoInteractions
    fileprivate func getAllCalls() -> [VerificationResult] {
        metadata.withLock { allMetadata in
            allMetadata.flatMap { (signature, metadata) -> [VerificationResult] in
                metadata.allCalls().map {
                    VerificationResult(signature: signature, call: $0)
                }
            }
        }
    }

    // Used by verifyNoMoreInteractions
    fileprivate func getUnverifiedCalls() -> [VerificationResult] {
        metadata.withLock { allMetadata in
            allMetadata.flatMap { (signature, metadata) -> [VerificationResult] in
                metadata.unverifiedCalls().map {
                    VerificationResult(signature: signature, call: $0)
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
    guard !allCalls.isEmpty else { return }

    let callMap = allCalls.sortedCallDescriptions()
    reportIssue("Expected no calls; found...\n\t\(callMap)", filePath: filePath, line: line)
}

/// Asserts that all invocations on the given mock have been verified.
public func verifyNoMoreInteractions<T>(_ mock: Smock<T>, filePath: StaticString = #filePath, line: UInt = #line) {
    let unverified = mock.getUnverifiedCalls()
    guard !unverified.isEmpty else { return }

    let callMap = unverified.sortedCallDescriptions()
    reportIssue("Unverified calls remaining...\n\t\(callMap)", filePath: filePath, line: line)
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

                // Property getters (0 params) and setters (1 param) should not match each other
                // All other cases should have equal param counts
                guard call.params.count == params.count else { return }

                // All parameters must match
                let isMatch = zip(params, call.params)
                    .allSatisfy { (matcher, callParam) in
                        matcher.matches(callParam)
                    }

                if isMatch {
                    // Track verification
                    if !didVerify, !call.isVerified {
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
#endif
