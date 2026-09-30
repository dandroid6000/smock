//
//  SmockStatic.swift
//  Smock
//
//  Created by Dan Kane on 9/30/26.
//

#if DEBUG
#if swift(>=6.0)
import Synchronization
#else
// Fallback to swift-mutex implementation
import Mutex
#endif

/// A namespace for tracking static member metadata by type.
///
/// To access the static mock for a given type, use subscript access, for example:
/// ```swift
/// SmockStatic[MyService.self].relaxed = true
/// ```
public enum SmockStatic {
    /// A registry of static mocks by type
    fileprivate static let staticMocks = Mutex<[ObjectIdentifier: Any]>([:])

    public static subscript<T>(type: T.Type) -> Smock<T> {
        staticMocks.withLock { mocks in
            let objId = ObjectIdentifier(type)
            return mocks[objId] as? Smock<T> ?? {
                let new = Smock<T>(isStatic: true)
                mocks[objId] = new
                return new
            }()
        }
    }

    /// Removes all static mock instances.
    public static func reset() {
        staticMocks.withLock { $0.removeAll() }
    }
}

/// Clears all static stubs and tracked calls.
///
/// - SeeAlso: ``reset<T>(_ mock: Smock<T>, includeStatic: Bool = false)``
public func reset<T>(_ static: Smock<T>.Type) {
    reset(SmockStatic[T.self], includeStatic: false) // Explicitly avoid recursion
}

// MARK: - Static wrappers

extension Smock {
    /// Indicates whether the static mock will assume reasonable return values (e.g. `Void` or `nil`)  when members are not stubbed.
    public static var relaxed: Bool {
        get { SmockStatic[T.self].relaxed }
        set { SmockStatic[T.self].relaxed = newValue }
    }

    /// Tracks a static method invocation by its signature, and associated parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public static func trackMethod<each P: Sendable>(_ signature: String, params: repeat each P) {
        SmockStatic[T.self].trackMethod(signature, params: repeat each params)
    }

    /// Tracks a static property getter by its signature.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public static func trackGetter(_ signature: String) {
        SmockStatic[T.self].trackGetter(signature)
    }

    /// Tracks a static property setter by its signature, and assigned value.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public static func trackSetter<V: Sendable>(_ signature: String, value: V) {
        SmockStatic[T.self].trackSetter(signature, value: value)
    }

    /// Gets the next stubbed value for a member with the given signature which matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public static func getValue<each P, R>(for signature: String, params: repeat each P) throws -> R {
        try SmockStatic[T.self].getValue(for: signature, params: repeat each params)
    }

    /// Gets the next stubbed value for a member with the given signature which matches the provided parameters.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public static func getValue<each P, R>(for signature: String, params: repeat each P) async throws -> R {
        try await SmockStatic[T.self].getValue(for: signature, params: repeat each params)
    }
}
#endif
