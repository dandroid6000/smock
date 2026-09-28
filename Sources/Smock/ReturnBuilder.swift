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
    internal let mock: Smock<T>
    internal let signature: String
    internal let params: [AnyArgumentMatcher]

    internal init(mock: Smock<T>, signature: String, params: [AnyArgumentMatcher]) {
        self.mock = mock
        self.signature = signature
        self.params = params
    }

    /// Creates a new builder for the given mock, member signature, and argument matchers.
    public convenience init<each P>(mock: Smock<T>, signature: String, params: repeat ArgumentMatcher<each P>) {
        // Wrap ArgumentMatchers to store in array
        var paramArray: [AnyArgumentMatcher] = []
        repeat paramArray.append(each params as AnyArgumentMatcher)
        self.init(mock: mock, signature: signature, params: paramArray)
    }

    /// Stubs the given `value` to be returned when the associated member is invoked.
    @discardableResult
    public func thenReturn(_ value: R) -> Self {
        print("Will return \(value) for \(Call.description(for: signature, params: params))")
        stubByType({ _ in value })
        return self
    }

    @discardableResult
    public func then(_ answer: @escaping @Sendable (Args) -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        stubByType(answer)
        return self
    }

    @discardableResult
    public func then(_ answer: @escaping @Sendable () -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        stubByType({ _ in answer() })
        return self
    }

    /// Invokes the correct stub method (async vs sync) by class type
    fileprivate func stubByType(_ answer: @escaping @Sendable (Args) -> R) {
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
    @discardableResult
    public func then(_ answer: @escaping @Sendable (Args) async -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        mock.stubAsyncProducer(answer, for: signature, params: params)
        return self
    }

    @discardableResult
    public func then(_ answer: @escaping @Sendable () async -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        mock.stubAsyncProducer({ _ in await answer() }, for: signature, params: params)
        return self
    }
}

// MARK: - ThrowingReturnBuilder

public class ThrowingReturnBuilder<T, R: Sendable>: ReturnBuilder<T, R>, @unchecked Sendable {
    /// Stubs the given `error` to be thrown then the associated member is invoked..
    @discardableResult
    public func thenThrow(_ error: Error) -> Self {
        print("Will throw `\(error)` for \(Call.description(for: signature, params: params))")
        stubByType({ _ in throw error })
        return self
    }

    @discardableResult
    public override func then(_ answer: @escaping @Sendable (Args) throws -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        stubByType(answer)
        return self
    }

    @discardableResult
    public override func then(_ answer: @escaping @Sendable () throws -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        stubByType({ _ in try answer() })
        return self
    }

    /// Invokes the correct stub method (async vs sync) by class type
    fileprivate override func stubByType(_ answer: @escaping @Sendable (Args) throws -> R) {
        if self is AsyncThrowingReturnBuilder<T, R> {
            mock.stubAsyncProducer(answer, for: signature, params: params)
        } else {
            mock.stubProducer(answer, for: signature, params: params)
        }
    }
}

// MARK: - AsyncThrowingReturnBuilder

public final class AsyncThrowingReturnBuilder<T, R: Sendable>: ThrowingReturnBuilder<T, R>, @unchecked Sendable {
    @discardableResult
    public func then(_ answer: @escaping @Sendable (Args) async throws -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        mock.stubAsyncProducer(answer, for: signature, params: params)
        return self
    }

    @discardableResult
    public func then(_ answer: @escaping @Sendable () async throws -> R) -> Self {
        print("Will invoke answer() for \(Call.description(for: signature, params: params))")
        mock.stubAsyncProducer({ _ in try await answer() }, for: signature, params: params)
        return self
    }
}
#endif
