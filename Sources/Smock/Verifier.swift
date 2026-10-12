//
//  Verifier.swift
//  Smock
//
//  Created by Dan Kane on 6/18/26.
//

#if DEBUG
import IssueReporting

/// Ways to verify an invocation.
public enum Verification: CustomStringConvertible {
    /// The member was invoked *exactly* n times.
    case exactly(Int)
    /// The member was invoked *at least* n times.
    case atLeast(Int)
    /// The member was invoked *at most* n times.
    case atMost(Int)
    /// The member was never invoked.
    case never

    public var description: String {
        switch self {
        case .exactly(let target): "\(target)"
        case .atLeast(let target): "\(target) or more"
        case .atMost(let target): "\(target) or less"
        case .never: "0"
        }
    }

    func verify(count: Int) -> Bool {
        switch self {
        case .exactly(let target): count == target
        case .atLeast(let target): count >= target
        case .atMost(let target): count <= target
        case .never: count == 0
        }
    }
}

/// A base class for verifying matching `Call`s against a ``Verification`` case and notifying the test environment of failures.
public class Verifier<T> {
    fileprivate let mock: Smock<T>
    fileprivate let signature: String
    fileprivate let params: [AnyArgumentMatcher]

    internal init(mock: Smock<T>, signature: String, params: [AnyArgumentMatcher]) {
        self.mock = mock
        self.signature = signature
        self.params = params
    }

    /// Convenience for performing verification
    fileprivate func verify(
        params: [AnyArgumentMatcher] = [],
        by verification: Verification,
        filePath: StaticString,
        line: UInt
    ) -> VerificationResult {
        // Append inbound params to stored for comparison (see SmockMacro.mockSubscript())
        //  - getter: [] + [] -> []
        //  - setter: [] + ["newValue"] -> ["newValue"]
        //  - subscript read: [1, "default"] + [] -> [1, "default"]
        //  - subscript write: [1, "default"] + ["newValue"] -> [1, "default", "newValue"]
        //  - method: [1, "two"] + [] -> [1, "two"]
        let params = self.params + params
        let calls = mock.verifyCalls(for: signature, matching: params)

        if !verification.verify(count: calls.count) {
            let staticType = mock.isStatic ? "\(T.self)" : ""
            let callDescription = "\(staticType)\(Call.description(for: signature, params: params))"
            reportIssue(
                "Verification failed: \(callDescription)\n\tExpected: \(verification)\n\tActual: \(calls.count)",
                filePath: filePath,
                line: line
            )
        }

        // Retreive the relevant call for the result
        let verified = calls.last { $0.isVerified }
        return VerificationResult(signature: signature, call: verified, filePath: filePath, line: line)
    }
}

/// A ``Verifier`` for methods which matches call parameters to a list of ``ArgumentMatcher``s.
public class MethodVerifier<T, R>: Verifier<T> {
    /// Creates a new verifier for the given mock, member signature, and argument matchers.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public convenience init<each P>(mock: Smock<T>, signature: String, params: repeat ArgumentMatcher<each P>) {
        // Wrap ArgumentMatchers to store in array
        var paramArray: [AnyArgumentMatcher] = []
        repeat paramArray.append(each params as AnyArgumentMatcher)
        self.init(mock: mock, signature: signature, params: paramArray)
    }

    /// Asserts that the method was invoked in accordance with the given ``Verification``.
    ///
    ///  - parameters:
    ///    - returning: The return type of the method. This can be supplied to clarify a generic return type for the compiler.
    ///    - verification: The type of verification to perform.
    @discardableResult
    public func wasCalled(
        returning _: R.Type = R.self,
        _ verification: Verification = .atLeast(1),
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) -> VerificationResult {
        return verify(by: verification, filePath: filePath, line: line)
    }
}

/// A ``Verifier`` for properties which can verifiy property reads.
public class PropertyVerifier<T, R: Sendable>: Verifier<T> {
    /// Creates a new verifier for the given mock and member signature.
    /// - Warning: This method is called by generated code and should not be invoked directly.
    public convenience init<each P>(mock: Smock<T>, signature: String, params: repeat ArgumentMatcher<each P>) {
        // Wrap ArgumentMatchers to store in array
        var paramArray: [AnyArgumentMatcher] = []
        repeat paramArray.append(each params as AnyArgumentMatcher)
        self.init(mock: mock, signature: signature, params: paramArray)
    }

    /// Asserts that the property was read in accordance with the given ``Verification``.
    ///
    ///  - parameters:
    ///    - type: The property type. This can be supplied to clarify a generic type for the compiler.
    ///    - verification: The type of verification to perform.
    @discardableResult
    public func wasRead(
        type _: R.Type = R.self,
        _ verification: Verification = .atLeast(1),
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) -> VerificationResult {
        return verify(by: verification, filePath: filePath, line: line)
    }
}

/// A ``Verifier`` for *writable* properties which matches setter values to a provided ``ArgumentMatcher``.
public class WritablePropertyVerifier<T, R: Sendable>: PropertyVerifier<T, R> {
    /// Asserts that the property was set to the given `value` in accordance with the provided ``Verification``.
    ///
    ///  - parameters:
    ///    - value: A matcher for the expected value.
    ///    - verification: The type of verification to perform.
    @discardableResult
    public func wasSet(
        to value: ArgumentMatcher<R> = .any(),
        _ verification: Verification = .atLeast(1),
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) -> VerificationResult {
        let params = [value as AnyArgumentMatcher]
        return verify(params: params, by: verification, filePath: filePath, line: line)
    }
}

// MARK: Global Verification

/// Asserts that no invocations occurred on the given mock.
public func verifyNoInteractions<T>(_ mock: Smock<T>, filePath: StaticString = #filePath, line: UInt = #line) {
    let allCalls = mock.getAllCalls()
    guard !allCalls.isEmpty else { return }

    let callMap = allCalls.sortedCallDescriptions()
    let staticType = mock.isStatic ? "static " : ""
    reportIssue("Expected no \(staticType)calls; found...\n\t\(callMap)", filePath: filePath, line: line)
}

/// Asserts that no static invocations occurred on the given type.
public func verifyNoInteractions<T>(_ staticType: Smock<T>.Type, filePath: StaticString = #filePath, line: UInt = #line) {
    verifyNoInteractions(SmockStatic[T.self], filePath: filePath, line: line)
}

/// Asserts that all invocations on the given mock have been verified.
public func verifyNoMoreInteractions<T>(_ mock: Smock<T>, filePath: StaticString = #filePath, line: UInt = #line) {
    let unverified = mock.getUnverifiedCalls()
    guard !unverified.isEmpty else { return }

    let callMap = unverified.sortedCallDescriptions()
    let staticType = mock.isStatic ? "static " : ""
    reportIssue("Unverified \(staticType)calls remaining...\n\t\(callMap)", filePath: filePath, line: line)
}

/// Asserts that all static invocations on the given type have been verified.
public func verifyNoMoreInteractions<T>(_ staticType: Smock<T>.Type, filePath: StaticString = #filePath, line: UInt = #line) {
    verifyNoMoreInteractions(SmockStatic[T.self], filePath: filePath, line: line)
}

// MARK: - Order Verification

/// Contains details about member verification which can be used for further assertions, e.g. `inOrder`.
///
/// - SeeAlso: ``inOrder(_:)``
/// - SeeAlso: ``verifyNoMoreInteractions(_:file:line:)``
public class VerificationResult: CustomStringConvertible {
    let signature: String
    let call: Call? // nil means no calls (e.g. .never)
    let filePath: StaticString
    let line: UInt

    public var description: String {
        Call.description(for: signature, params: call?.params)
    }

    init(signature: String, call: Call?, filePath: StaticString = "", line: UInt = 0) {
        self.signature = signature
        self.call = call
        self.filePath = filePath
        self.line = line
    }
}

extension [VerificationResult] {
    func sortedCallDescriptions() -> String {
        // De-dup by timestamp
        var timestamps = Set<ContinuousClock.Instant>()
        return self.compactMap { result -> (call: Call, signature: String)? in
            guard let call = result.call else { return nil }
            return (call: call, signature: result.signature)
        }
        .sorted(by: { $0.call.timestamp <= $1.call.timestamp })
        .lazy // delay string generation until joined
        .filter { timestamps.insert($0.call.timestamp).inserted } // de-dup
        .map { $0.call.description(for: $0.signature) }
        .joined(separator: "\n\t")
    }
}

/// Result builder that collects ``VerificationResult``s for further processing.
@resultBuilder
public struct InOrderBuilder {
    public static func buildBlock(_ components: VerificationResult...) -> [VerificationResult] {
        components
    }

    public static func buildOptional(_ component: [VerificationResult]?) -> [VerificationResult] {
        component ?? []
    }

    public static func buildEither(first component: [VerificationResult]) -> [VerificationResult] {
        component
    }

    public static func buildEither(second component: [VerificationResult]) -> [VerificationResult] {
        component
    }
}

/// Ensures that the provided ``VerificationResult``s represent calls that were made in chronological order.
///
/// **Example:**
/// ```swift
/// let mock = MyServiceMock()
/// mock.getValue()
/// mock.getAnotherValue()
/// mock.didGetValue = true
/// inOrder {
///     verify(mock).getAnotherValue().wasCalled()
///     verify(mock).didGetValue.wasSet() // PASS - was called after .getAnotherValue()
///     verify(mock).getValue().wasCalled() // FAIL - out of order
/// }
/// ```
public func inOrder(@InOrderBuilder _ builder: () -> [VerificationResult]) {
    let verifications = builder()

    // Each VerificationResult will contain 0 or 1 calls at this point
    var inOrder: [VerificationResult] = []
    for (index, verification) in verifications.enumerated() {
        guard
            let call = verification.call,
            let lastVerification = inOrder.last(where: { $0.call != nil }),
            let lastCall = lastVerification.call,
            lastCall.timestamp >= call.timestamp // Fail
        else {
            // Pass (includes nil/.never)
            inOrder.append(verification)
            continue
        }

        // Log the failure
        var message = "In-Order Verification Failed at step \(index + 1) of \(verifications.count)"
        message += "\n\tExpected: \(verification)"
        message += "\n\tto occur AFTER: \(lastVerification)"

        var callMap = inOrder.map {
            if $0.call != nil {
                "✅ \($0)"
            } else {
                "❎ \($0)"
            }
        }
        callMap.append("❌ \(verification)")
        message += "\nChronological invocations for this step:\n\t\(callMap.joined(separator: "\n\t"))"

        reportIssue(message, filePath: verification.filePath, line: verification.line)
        break
    }
}
#endif
