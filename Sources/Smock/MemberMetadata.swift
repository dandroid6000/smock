//
//  SmockMetadata.swift
//  Smock
//
//  Created by Dan Kane on 9/29/26.
//

#if DEBUG
#if swift(>=6.0)
import Synchronization
#else
// Fallback to swift-mutex implementation
import Mutex
#endif

/// Internal class for holding metata for a given member, including stubs and invocation history.
///
/// As a `Sendable`, non-isolated class, all data is stored using Mutexes to ensure thread safety.
final class MemberMetadata: Sendable {
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
#endif
