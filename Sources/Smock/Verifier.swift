//
//  Verifier.swift
//  Smock
//
//  Created by Dan Kane on 6/18/26.
//

#if DEBUG
/// Enumeration of ways to verify an invocation.
public enum Verification: CustomStringConvertible {
    /// The member was invoked *exactly* n times.
    case exactly(Int)
    /// The member was invoked *at least* n times.
    case atLeast(Int)
    /// The member was invoked *at most* n times.
    case atMost(Int)
    /// The member was never invoked..
    case never

    public var description: String {
        switch self {
        case .exactly(let target): "\(target)"
        case .atLeast(let target): "\(target) or more"
        case .atMost(let target): "\(target) or less"
        case .never: "never"
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
    fileprivate let params: [AnyArgumentMatcher] // will be `nil` for properties and set for methods

    internal init(mock: Smock<T>, signature: String, params: [AnyArgumentMatcher]) {
        self.mock = mock
        self.signature = signature
        self.params = params
    }

    /// Convenience for performing verification
    fileprivate func verify(
        params: [AnyArgumentMatcher]? = nil,
        by verification: Verification,
        filePath: StaticString,
        line: UInt
    ) -> VerificationResult {
        let calls = mock.verifyCalls(for: signature, matching: params ?? self.params)

        if !verification.verify(count: calls.count) {
            TestingBridge.record("Verification failed: \(signature); expected: \(verification), actual: \(calls.count)", file: filePath, line: line)
        }

        return VerificationResult(signature: signature, calls: calls, filePath: filePath, line: line)
    }
}

/// A ``Verifier`` for methods which matches calls parameters to a list of ``ArgumentMatcher``s.
public class MethodVerifier<T, R>: Verifier<T> {
    public convenience init<each P>(mock: Smock<T>, signature: String, params: repeat ArgumentMatcher<each P>) {
        // Wrap ArgumentMatchers to store in array
        var paramArray: [AnyArgumentMatcher] = []
        repeat paramArray.append(each params as AnyArgumentMatcher)
        self.init(mock: mock, signature: signature, params: paramArray)
    }

    /// Asserts that the method was invoked in accordance with the given ``Verification``.
    @discardableResult
    public func wasCalled(
        _ verification: Verification = .atLeast(1),
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) -> VerificationResult {
        return verify(by: verification, filePath: filePath, line: line)
    }
}

/// A ``Verifier`` for properties which can verifiy property reads.
public class PropertyVerifier<T, R: Sendable>: Verifier<T> {
    public convenience init(mock: Smock<T>, signature: String) {
        self.init(mock: mock, signature: signature, params: [])
    }

    /// Asserts that the property was read in accordance with the given ``Verification``.
    @discardableResult
    public func wasRead(
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

// MARK: - Order Verification

/// Contains details about member verification which can be used for further assertions, e.g. `inOrder`.
///
/// - SeeAlso: ``inOrder(_:)``
/// - SeeAlso: ``verifyNoMoreInteractions(_:file:line:)``
public class VerificationResult {
    let signature: String
    let calls: [Call]
    let filePath: StaticString
    let line: UInt

    init(signature: String, calls: [Call], filePath: StaticString, line: UInt) {
        self.signature = signature
        self.calls = calls
        self.filePath = filePath
        self.line = line
    }

    func description(for call: Call?) -> String {
        guard signature.contains("(") else {
            // Property
            let assignment = if let call, !call.params.isEmpty {
                " = \(call.params[0])"
            } else {
                ""
            }
            return ".\(signature)\(assignment)"
        }

        // Method
        let split = signature.split(separator: "(", maxSplits: 1)
        guard
            let call,
            let name = split.first,
            let paramString = split.last?.split(separator: ")", maxSplits: 1).first,
            !paramString.isEmpty
        else {
            return ".\(signature)"
        }

        let names = paramString.split(separator: ",").map { part in
            // e.g. "_ a: Int"
            String(part)
                .trimmingCharacters(in: .whitespaces)
                .split(separator: ":").first?
                .split(separator: " ").first ?? ""
        }
        let params = zip(names, call.params).map { name, param in
            if name == "_" {
                "\(param)"
            } else {
                "\(name): \(param)"
            }
        }.joined(separator: ", ")
        return ".\(name)(\(params))"
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
///     verify(mock).getAnotherValue.wasCalled()
///     verify(mock).didGetValue.wasSet() // PASS - was called after .getAnotherValue()
///     verify(mock).getValue().wasCalled() // FAIL - was called first
/// }
/// ```
public func inOrder(@InOrderBuilder _ builder: () -> [VerificationResult]) {
    let verifications = builder()

    // 2. Perform greedy chronological path matching
    var lastCall: Call? = nil
    var failedIndex: Int? = nil

    for (index, verification) in verifications.enumerated() {
        if verification.calls.isEmpty {
            // e.g. .never
            continue
        }

        // TODO: Make sure a, b, a situations are handled
        // Sort matching calls to ensure we evaluate chronologically
        let chronologicallySortedCalls = verification.calls
            .sorted { $0.timestamp < $1.timestamp }

        let nextCall: Call?
        if let lastTimestamp = lastCall?.timestamp {
            // Find the earliest call that occurred strictly after our previous verified step
            nextCall = chronologicallySortedCalls.first { $0.timestamp > lastTimestamp }
        } else {
            // First step simply gets the earliest call in its set
            nextCall = chronologicallySortedCalls.first
        }

        if let nextCall {
            lastCall = nextCall
        } else {
            failedIndex = index
            break
        }
    }

    // 3. Generate detailed, actionable diagnostics on failure
    if let failedIndex {
        let failedVerification = verifications[failedIndex]
        var message = "In-Order Verification Failed at call \(failedIndex + 1) of \(verifications.count)"
        message += "\n\tExpected: .\(failedVerification.signature)"

        if failedIndex > 0 {
            let prevVerification = verifications[failedIndex - 1]
            message += "\n\tto occur AFTER: \(prevVerification.description(for: lastCall))"
        }

        if failedVerification.calls.isEmpty {
            message += "\n\tReason: The method or property was never invoked."
        } else {
            message += "\n\tReason: All matching invocations occurred out of order (prior to preceding steps)."
//            message += "\n\tChronological invocations for this step:"
//            for (idx, call) in failedVerification.calls.sorted(by: { $0.timestamp < $1.timestamp }).enumerated() {
//                message += "\n  [\(idx + 1)] \(failedVerification.description(for: call))"
//            }
            
//            let callDescriptions = verifications
//                // 1. Pair each call with its parent Verification to retain the description context
//                .flatMap { verification in
//                    verification.calls.map { (verification: verification, call: $0) }
//                }
//                // 2. Sort all calls chronologically across all verifications
//                .sorted { $0.call.timestamp < $1.call.timestamp }
//                // 3. Map to the specific description using the parent verification
//                .map { pair in
//                    pair.verification.description(for: pair.call)
//                }
//            message += "\n\tChronological invocations"
//            for (idx, call) in callDescriptions.enumerated() {
//                message += "\n\t\t[\(idx + 1)] \(call)"
//            }
        }
        TestingBridge.record(message, file: failedVerification.filePath, line: failedVerification.line)
    }
}
#endif
