//
//  ReturnBuilder.swift
//  Smock
//
//  Created by Dan Kane on 6/17/26.
//

#if DEBUG
/// A stongly-typed builder used to stub return values for a mock.
// Note: Class is non-final, so cannot directly conform to Sendable
// - Applying @unchecked and using immutable values to ensure thread safety
public class ReturnBuilder<T, R: Sendable>: @unchecked Sendable {
    fileprivate let mock: Smock<T>
    fileprivate let signature: String
    fileprivate let params: [AnyArgumentMatcher]

    // Used for logging
    fileprivate var callDescription: String {
        let staticType = mock.isStatic ? "\(T.self)" : ""
        return "\(staticType)\(Call.description(for: signature, params: params))"
    }

    /// Configures the builder to stub the provided `mock` instance.
    internal init(mock: Smock<T>, signature: String, params: [AnyArgumentMatcher]) {
        self.mock = mock
        self.signature = signature
        self.params = params
    }

    /// Creates a new builder for the given mock, member signature, and argument matchers.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public convenience init<each P>(mock: Smock<T>, signature: String, params: repeat ArgumentMatcher<each P>) {
        // Wrap ArgumentMatchers to store in array
        var paramArray: [AnyArgumentMatcher] = []
        repeat paramArray.append(each params as AnyArgumentMatcher)
        self.init(mock: mock, signature: signature, params: paramArray)
    }

    /// Stubs the given `value` to be returned when the associated member is called.
    @discardableResult
    public func thenReturn(_ value: R) -> Self {
        print("Will return \(value) for \(callDescription)")
        stubByType({ _ in value })
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping (Args) -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        stubByType(answer)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping () -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        stubByType({ _ in answer() })
        return self
    }

    /// Invokes the correct stub method (async vs sync) by class type
    fileprivate func stubByType(_ answer: @Sendable @escaping (Args) -> R) {
        if self is AsyncReturnBuilder<T, R> {
            mock.stubAsyncProducer(answer, for: signature, params: params)
        } else {
            mock.stubProducer(answer, for: signature, params: params)
        }
    }
}

public extension ReturnBuilder where R == Void {
    /// A convenience for `Void` return types to simply complete when the associated member is invoked.
    @discardableResult
    func thenReturn() -> Self {
        thenReturn(())
    }
}

// MARK: - AsyncReturnBuilder

public final class AsyncReturnBuilder<T, R: Sendable>: ReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping (Args) async -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        mock.stubAsyncProducer(answer, for: signature, params: params)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping () async -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        mock.stubAsyncProducer({ _ in await answer() }, for: signature, params: params)
        return self
    }
}

// MARK: - ThrowingReturnBuilder

public class ThrowingReturnBuilder<T, R: Sendable>: ReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `error` to be thrown then the associated member is called.
    @discardableResult
    public func thenThrow(_ error: Error) -> Self {
        print("Will throw `\(error)` for \(callDescription)")
        stubByType({ _ in throw error })
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public override func then(_ answer: @Sendable @escaping (Args) throws -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        stubByType(answer)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public override func then(_ answer: @Sendable @escaping () throws -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        stubByType({ _ in try answer() })
        return self
    }

    /// Invokes the correct stub method (async vs sync) by class type (overridden to support throwing closures)
    fileprivate override func stubByType(_ answer: @Sendable @escaping (Args) throws -> R) {
        if self is AsyncThrowingReturnBuilder<T, R> {
            mock.stubAsyncProducer(answer, for: signature, params: params)
        } else {
            mock.stubProducer(answer, for: signature, params: params)
        }
    }
}

// MARK: - AsyncThrowingReturnBuilder

public final class AsyncThrowingReturnBuilder<T, R: Sendable>: ThrowingReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping (Args) async throws -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        mock.stubAsyncProducer(answer, for: signature, params: params)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping () async throws -> R) -> Self {
        print("Will invoke answer() for \(callDescription)")
        mock.stubAsyncProducer({ _ in try await answer() }, for: signature, params: params)
        return self
    }
}
#endif
