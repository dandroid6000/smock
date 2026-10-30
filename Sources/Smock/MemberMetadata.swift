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
    /// Serves as a unique identifier for the next `StubGroup` to be created. Using Mutex as Atomic is not part of swift-mutex.
    private let _stubCounter = Mutex(0)
    private let _stubGroups = Mutex<[StubGroup]>([])
    private let _calls = Mutex<[Call]>([])

    /// Gets the current value of `_stubCounter` and then increments it
    private func nextGroupId() -> Int {
        _stubCounter.withLock { id in
            defer { id += 1 }
            return id
        }
    }

    /// Creates a new `StubGroup` and advances the `_stubCounter`.
    /// - returns: The `id` of the new `StubGroup`.
    func addStubGroup(matchers: [AnyArgumentMatcher]) -> Int {
        let id = nextGroupId()
        let new = StubGroup(id: id, matchers: matchers)
        _stubGroups.withLock { $0.append(new) }
        return id
    }

    /// Adds a stub for the given `producer` to the `StubGroup` with the given `id`.
    func addStub(groupId: Int, producer: AnyProducer) {
        _stubGroups.withLock {
            if let index = $0.firstIndex(where: { $0.id == groupId}) {
                // Mutate in place
                $0[index].addProducer(producer)
            } else {
                print("⚠️ Unable to find StubGroup with id: \(groupId)")
            }
        }
    }

    func addCall(_ call: Call) {
        _calls.withLock { $0.append(call) }
    }

    /// Retrieves the next producer matching the given params. Stub groups are searched in reverse order (LIFO) until a match is found. If
    /// there is more than one stub in the group, they will be 'consumed' in FIFO order with the last one being returned indefinitely.
    func getNextProducer<T: AnyProducer>(matching params: [Any]) -> T? {
        _stubGroups.withLock { stubGroups in
            guard let index = stubGroups.lastIndex(where: { $0.matches(params: params)}) else {
                return nil
            }

            // Mutate in place
            return stubGroups[index].nextProducer() as? T // Cast should always succeed
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

    /// For testing
    func allStubs() -> [StubGroup] {
        _stubGroups.withLock { $0 }
    }
}
#endif
