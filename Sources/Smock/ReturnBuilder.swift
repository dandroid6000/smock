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
    let mock: Smock<T>
    let signature: String
    let stubGroupId: Int
    fileprivate let callDescription: String

    /// Configures the builder to stub the provided `mock` instance.
    internal init(mock: Smock<T>, signature: String, params: [AnyArgumentMatcher]) {
        self.mock = mock
        self.signature = signature

        // Create a new stub group for this builder
        self.stubGroupId = mock.createStubGroup(for: signature, matchers: params)

        // Track the call description for loggin purposes
        self.callDescription = "\(mock.staticType)\(Call.description(for: signature, params: params))"
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
    public func then(return value: R) -> Self {
        smockLogger.debug("[STUB] Will return \(String(describing: value)) for \(self.callDescription)")
        stubByType({ _ in value })
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping (Args) -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer(_) for \(self.callDescription)")
        stubByType(answer)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping () -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer() for \(self.callDescription)")
        stubByType({ _ in answer() })
        return self
    }

    /// Invokes the correct stub method (async vs sync) by class type
    fileprivate func stubByType(_ answer: @Sendable @escaping (Args) -> R) {
        if self is AsyncReturnBuilder<T, R> {
            mock.stubAsyncProducer(answer, for: signature, stubGroupId: stubGroupId)
        } else {
            mock.stubProducer(answer, for: signature, stubGroupId: stubGroupId)
        }
    }
}

public extension ReturnBuilder where R == Void {
    /// A convenience for `Void` return types to simply complete when the associated member is invoked.
    @discardableResult
    func thenReturn() -> Self {
        then(return: ())
    }
}

// MARK: - AsyncReturnBuilder

public final class AsyncReturnBuilder<T, R: Sendable>: ReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping (Args) async -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer(_) for \(self.callDescription)")
        mock.stubAsyncProducer(answer, for: signature, stubGroupId: stubGroupId)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping () async -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer() for \(self.callDescription)")
        mock.stubAsyncProducer({ _ in await answer() }, for: signature, stubGroupId: stubGroupId)
        return self
    }
}

// MARK: - ThrowingReturnBuilder

public class ThrowingReturnBuilder<T, R: Sendable>: ReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `error` to be thrown then the associated member is called.
    @discardableResult
    public func then(throw error: Error) -> Self {
        smockLogger.debug("[STUB] Will throw `\(error)` for \(self.callDescription)")
        stubByType({ _ in throw error })
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public override func then(_ answer: @Sendable @escaping (Args) throws -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer(_) for \(self.callDescription)")
        stubByType(answer)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public override func then(_ answer: @Sendable @escaping () throws -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer() for \(self.callDescription)")
        stubByType({ _ in try answer() })
        return self
    }

    /// Invokes the correct stub method (async vs sync) by class type (overridden to support throwing closures)
    fileprivate override func stubByType(_ answer: @Sendable @escaping (Args) throws -> R) {
        if self is AsyncThrowingReturnBuilder<T, R> {
            mock.stubAsyncProducer(answer, for: signature, stubGroupId: stubGroupId)
        } else {
            mock.stubProducer(answer, for: signature, stubGroupId: stubGroupId)
        }
    }
}

// MARK: - AsyncThrowingReturnBuilder

public final class AsyncThrowingReturnBuilder<T, R: Sendable>: ThrowingReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping (Args) async throws -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer(_) for \(self.callDescription)")
        mock.stubAsyncProducer(answer, for: signature, stubGroupId: stubGroupId)
        return self
    }

    /// Stubs the given `answer` to be invoked when the associated member is called.
    @discardableResult
    public func then(_ answer: @Sendable @escaping () async throws -> R) -> Self {
        smockLogger.debug("[STUB] Will invoke answer() for \(self.callDescription)")
        mock.stubAsyncProducer({ _ in try await answer() }, for: signature, stubGroupId: stubGroupId)
        return self
    }
}
#endif
