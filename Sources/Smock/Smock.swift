// The Swift Programming Language
// https://docs.swift.org/swift-book

#if DEBUG
#if swift(>=6.0)
import Synchronization
#else
// Fallback to swift-mutex implementation
import Mutex
#endif

import IssueReporting

enum SmockError: Error {
    case strict
    case stubNotFound
}

/// The base class for all mocks, including internal functionality for stubbing and retrieving values, as well as tracking and verifying member invocations.
// Note: Class is non-final, so cannot directly conform to Sendable
// - Applying @unchecked and using Mutex to ensure thread safety
open class Smock<T>: @unchecked Sendable {
    /// Indicates whether the mock will assume reasonable return values (e.g. `Void` or `nil`)  when members are not stubbed.
    public var relaxed: Bool

    /// Indicates whether this mock represents static members (distinct from instance members).
    let isStatic: Bool

    /// Generic type is needed to generate type-specific `when` methods that instantiate the correct stubber
    let mockedType: T.Type = T.self

    fileprivate let metadata = Mutex<[String: MemberMetadata]>([:])

    private var staticType: String { isStatic ? "\(T.self)" : "" }

    /// Creates a new instance of the mock.
    ///
    /// - parameter relaxed: If `true`, the mock will assume reasonable return values (e.g. `Void` or `nil`)  when members are not stubbed.
    public required init(relaxed: Bool = false) {
        self.relaxed = relaxed
        self.isStatic = false
    }

    /// Internal initializer for static instances.
    init(isStatic: Bool) {
        self.relaxed = false
        self.isStatic = isStatic
    }

    /// Tracks a method invocation by its signature and associated parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackMethod<each P: Sendable>(_ signature: String, params: repeat each P) {
        var paramArray: [any Sendable] = []
        repeat paramArray.append(each params)
        print("Tracked method: \(staticType)\(Call.description(for: signature, params: paramArray))")
        let call = Call(params: paramArray)
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Tracks a property getter by its signature.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackGetter(_ signature: String) {
        print("Tracked getter: \(staticType)\(Call.description(for: signature))")
        let call = Call(params: []) // Empty params implies a `get` operation
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Tracks a property setter by its signature and assigned value.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func trackSetter<V: Sendable>(_ signature: String, value: V) {
        print("Tracked setter: \(staticType)\(Call.description(for: signature, params: [value]))")
        let call = Call(params: [value])
        getOrCreateMetadata(for: signature)
            .addCall(call)
    }

    /// Gets the next stubbed value for a member with the given signature that matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func getValue<each P, R>(for signature: String, params: repeat each P) throws -> R {
        let paramArray = toParamArray(repeat each params)
        print("Getting value for: \(staticType)\(Call.description(for: signature, params: paramArray))")

        let metadata = metadata.withLock { $0[signature] }
        let stub: Stub? = metadata?.getNextStub(matching: paramArray)

        guard let stub else {
            return relaxedDefault("No matching stubs for \(staticType)\(Call.description(for: signature, params: paramArray))")
        }

        let args = Args(paramArray)
        guard let value = try stub.producer(args) as? R else {
            preconditionFailure("Incorrect type stubbed for \(staticType)\(Call.description(for: signature, params: paramArray))")
        }

        return value
    }

    /// Gets the next stubbed value for a member with the given signature that matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public final func getValue<each P, R>(for signature: String, params: repeat each P) async throws -> R {
        let paramArray = toParamArray(repeat each params)
        print("Getting value for: \(staticType)\(Call.description(for: signature, params: paramArray))")

        let metadata = metadata.withLock { $0[signature] }
        let stub: AsyncStub? = metadata?.getNextStub(matching: paramArray)

        guard let stub else {
            return relaxedDefault("No matching stubs for \(staticType)\(Call.description(for: signature, params: paramArray))")
        }

        let args = Args(paramArray)
        guard let value = try await stub.producer(args) as? R else {
            preconditionFailure("Incorrect type stubbed for \(staticType)\(Call.description(for: signature, params: paramArray))")
        }

        return value
    }

    // Used by (Throwing)ReturnBuilder classes
    func stubProducer(
        _ producer: @Sendable @escaping (Args) throws -> (any Sendable),
        for signature: String,
        params: [AnyArgumentMatcher]
    ) {
        getOrCreateMetadata(for: signature)
            .addStub(Stub(matchers: params, producer: producer))
    }

    // Used by Async(Throwing)ReturnBuilder classes
    func stubAsyncProducer(
        _ producer: @Sendable @escaping (Args) async throws -> (any Sendable),
        for signature: String,
        params: [AnyArgumentMatcher]
    ) {
        getOrCreateMetadata(for: signature)
            .addStub(AsyncStub(matchers: params, producer: producer))
    }

    // Used by Verifier classes
    func verifyCalls(for signature: String, matching params: [AnyArgumentMatcher]) -> [Call] {
        metadata.withLock { allMetadata in
            print("Verifying \(staticType)\(Call.description(for: signature, params: params))")
            return allMetadata[signature]?.verifyCalls(matching: params) ?? []
        }
    }

    // Used by verifyNoInteractions
    func getAllCalls() -> [VerificationResult] {
        metadata.withLock { allMetadata in
            allMetadata.flatMap { (signature, metadata) -> [VerificationResult] in
                metadata.allCalls().map {
                    VerificationResult(signature: signature, call: $0)
                }
            }
        }
    }

    // Used by verifyNoMoreInteractions
    func getUnverifiedCalls() -> [VerificationResult] {
        metadata.withLock { allMetadata in
            allMetadata.flatMap { (signature, metadata) -> [VerificationResult] in
                metadata.unverifiedCalls().map {
                    VerificationResult(signature: signature, call: $0)
                }
            }
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

    private func getOrCreateMetadata(for signature: String) -> MemberMetadata {
        metadata.withLock { allMetadata in
            allMetadata[signature] ?? {
                let new = MemberMetadata()
                allMetadata[signature] = new
                return new
            }()
        }
    }
}

/// Clears all stubs and tracked calls.
///
/// - parameter includeStatic: If `true`, static metadata will be reset as well.
///
/// - SeeAlso: ``reset<T>(_ static: Smock<T>.Type)``
public func reset<T>(_ mock: Smock<T>, includeStatic: Bool = false) {
    mock.metadata.withLock { $0.removeAll()}
    if includeStatic {
        reset(Smock<T>.self)
    }
}

/// Converts a strongly-typed parameter pack to `[Any]`.
private func toParamArray<each P>(_ params: repeat each P) -> [Any] {
    var paramArray: [Any] = []
    repeat paramArray.append(each params)
    return paramArray
}
#endif
