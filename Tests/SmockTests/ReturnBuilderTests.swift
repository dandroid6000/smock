//
//  ReturnBuilderTests.swift
//  Smock
//
//  Created by Dan Kane on 10/28/26.
//

import Testing

@testable import Smock

struct ReturnBuilderTests {

    let mock = Smock<Any>()

    // MARK: - ReturnBuilder

    @Test
    func `then(return:) adds a stub to the mock which returns the value`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params)

        // Act
        let expectedValue = 1
        builder.then(return: expectedValue)

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [Stub]
        #expect(stubs.count == 1)

        // Verify matchers
        let stub = stubs[0]
        #expect(stub.matchers.count == 1)
        let matcher = try #require(stub.matchers.first as? ArgumentMatcher<Int>)
        guard case .any = matcher else {
            Issue.record("Incorrect matcher type")
            return
        }

        // Verify producer (always produces the same value)
        let value1 = try stub.producer(Args([1])) as? Int
        #expect(value1 == expectedValue)

        let value2 = try stub.producer(Args([2])) as? Int
        #expect(value2 == expectedValue)
    }

    @Test
    func `then(answer:) adds a stub to the mock which invokes the closure`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params)

        // Act (add 1 to input)
        builder.then { args in
            let input: Int = try! args[0]
            return input + 1
        }

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [Stub]
        #expect(stubs.count == 1)

        // Verify matchers
        let stub = stubs[0]
        #expect(stub.matchers.count == 1)
        let matcher = try #require(stub.matchers.first as? ArgumentMatcher<Int>)
        guard case .any = matcher else {
            Issue.record("Incorrect matcher type")
            return
        }

        // Verify producer (result = parameter + 1)
        let value1 = try stub.producer(Args([1])) as? Int
        #expect(value1 == 2)

        let value2 = try stub.producer(Args([2])) as? Int
        #expect(value2 == 3)
    }

    @Test
    func `thenReturn() adds a stub to the mock which does nothing`() async throws {
        // Arrange (only available where R == Void)
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ReturnBuilder<Any, Void>(mock: mock, signature: signature, params: params)

        // Act
        builder.thenReturn()

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [Stub]
        #expect(stubs.count == 1)

        // Verify matchers
        let stub = stubs[0]
        #expect(stub.matchers.count == 1)
        let matcher = try #require(stub.matchers.first as? ArgumentMatcher<Int>)
        guard case .any = matcher else {
            Issue.record("Incorrect matcher type")
            return
        }

        // Verify producer (Void)
        let value = try stub.producer(Args([1]))
        #expect(value is Void)
    }

    @Test
    func `fluent stubbing adds stubs to the mock with the same signature and matchers`() async throws {
        // Arrange (only available where R == Void)
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params)

        // Act
        builder
            .then(return: 1)
            .then(return: 2)
            .then(return: 3)

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [Stub]
        #expect(stubs.count == 3)

        // Verify matchers are all the same
        try stubs.forEach { stub in
            #expect(stub.matchers.count == 1)
            let matcher = try #require(stub.matchers.first as? ArgumentMatcher<Int>)
            guard case .any = matcher else {
                Issue.record("Incorrect matcher type")
                return
            }
        }

        // Verify producers
        let value1 = try stubs[0].producer(Args([1])) as? Int
        #expect(value1 == 1)

        let value2 = try stubs[1].producer(Args([1])) as? Int
        #expect(value2 == 2)

        let value3 = try stubs[2].producer(Args([1])) as? Int
        #expect(value3 == 3)
    }

    // MARK: - AsyncReturnBuilder

    @Test
    func `then(answer:) adds a stub to the mock with an async producer`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = AsyncReturnBuilder<Any, Void>(mock: mock, signature: signature, params: params)

        let tracker = SendableBox(0)

        // Act
        builder.then { args in
            let input: Int = try! args[0]
            await tracker.update(to: input)
        }

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [AsyncStub]
        #expect(stubs.count == 1)

        // Verify producer
        #expect(tracker.value == 0)
        _ = try await stubs[0].producer(Args([1]))
        #expect(tracker.value == 1)
    }

    // MARK: - ThrowingReturnBuilder

    @Test
    func `then(throws:) adds a stub to the mock which throws the error`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ThrowingReturnBuilder<Any, Void>(mock: mock, signature: signature, params: params)

        // Act
        builder.then(throw: TestError.expected)

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [Stub]
        #expect(stubs.count == 1)

        // Verify producer (Void)
        #expect(throws: TestError.self) {
            try stubs[0].producer(Args([1]))
        }
    }

    @Test
    func `then(answer:) adds a stub to the mock with a throwing producer`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ThrowingReturnBuilder<Any, Void>(mock: mock, signature: signature, params: params)

        // Act
        builder.then {
            throw TestError.expected
        }

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [Stub]
        #expect(stubs.count == 1)

        // Verify producer (Void)
        #expect(throws: TestError.self) {
            try stubs[0].producer(Args([1]))
        }
    }

    // MARK: - AsyncThrowingReturnBuilder

    @Test
    func `then(answer:) adds a stub to the mock with an async throwing producer`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = AsyncThrowingReturnBuilder<Any, Void>(mock: mock, signature: signature, params: params)

        let tracker = SendableBox(0)

        // Act
        builder.then { args in
            let input: Int = try args[0]
            await tracker.update(to: input)
            throw TestError.expected
        }

        // Assert
        let stubs = getCurrentStubs(for: signature) as! [AsyncStub]
        #expect(stubs.count == 1)

        // Verify producer
        #expect(tracker.value == 0)
        await #expect(throws: TestError.self) {
            _ = try await stubs[0].producer(Args([1]))
        }
        #expect(tracker.value == 1) // tracker is updated BEFORE throwing
    }

    // MARK: - Convenience

    private func getCurrentStubs(for signature: String) -> [AnyStub] {
        mock.metadata.withLock({ $0[signature] })?.allStubs() ?? []
    }
}
