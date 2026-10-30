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
    func `new stubs include the builder's argument matchers`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.any(Int.self)]
        let builder = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params)

        // Act
        builder.then(return: 1)

        // Assert
    }

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
        let stubGroup = try #require(builder.getCurrentStubs())
        let stubs = stubGroup.producers as! [Producer]
        #expect(stubs.count == 1)

        // Verify matchers
        #expect(stubGroup.matchers.count == 1)
        let matcher = stubGroup.matchers.first as! ArgumentMatcher<Int>
        guard case .any = matcher else {
            Issue.record("Incorrect matcher")
            return
        }

        // Verify producer (always produces the same value)
        let value1 = try stubs[0].callAsFunction([1]) as? Int
        #expect(value1 == expectedValue)

        let value2 = try stubs[0].callAsFunction([2]) as? Int
        #expect(value2 == expectedValue)
    }

    @Test
    func `then(answer:) adds a stub to the mock which invokes the closure`() async throws {
        // Arrange
        let signature = "test"
        let params = [ArgumentMatcher.equalTo(4)]
        let builder = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params)

        // Act (add 1 to input)
        builder.then { args in
            let input: Int = try! args[0]
            return input + 1
        }

        // Assert
        let stubGroup = try #require(builder.getCurrentStubs())
        let stubs = stubGroup.producers as! [Producer]
        #expect(stubs.count == 1)

        // Verify matchers
        #expect(stubGroup.matchers.count == 1)
        let matcher = stubGroup.matchers.first as! ArgumentMatcher<Int>
        guard case .equalTo(4) = matcher else {
            Issue.record("Incorrect matcher")
            return
        }

        // Verify producer (result = parameter + 1)
        let value1 = try stubs[0].callAsFunction([1]) as? Int
        #expect(value1 == 2)

        let value2 = try stubs[0].callAsFunction([2]) as? Int
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
        let stubGroup = try #require(builder.getCurrentStubs())
        let stubs = stubGroup.producers as! [Producer]
        #expect(stubs.count == 1)

        // Verify matchers
        #expect(stubGroup.matchers.count == 1)
        let matcher = stubGroup.matchers.first as! ArgumentMatcher<Int>
        guard case .any = matcher else {
            Issue.record("Incorrect matcher")
            return
        }

        // Verify producer (Void)
        let value = try stubs[0].callAsFunction([1])
        #expect(value is Void)
    }

    @Test
    func `fluent stubbing adds stubs to the same stub group`() async throws {
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
        let stubGroup = try #require(builder.getCurrentStubs())
        let stubs = stubGroup.producers as! [Producer]
        #expect(stubs.count == 3)

        // Verify matchers
        #expect(stubGroup.matchers.count == 1)
        let matcher = stubGroup.matchers.first as! ArgumentMatcher<Int>
        guard case .any = matcher else {
            Issue.record("Incorrect matcher")
            return
        }

        // Verify producers
        let value1 = try stubs[0].callAsFunction([1]) as? Int
        #expect(value1 == 1)

        let value2 = try stubs[1].callAsFunction([1]) as? Int
        #expect(value2 == 2)

        let value3 = try stubs[2].callAsFunction([1]) as? Int
        #expect(value3 == 3)
    }

    @Test
    func `multiple builders add stub groups in order`() async throws {
        // Arrange (only available where R == Void)
        let signature = "test"
        let params1 = [ArgumentMatcher.any(Int.self)]
        let builder1 = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params1)

        let params2 = [ArgumentMatcher.equalTo(4)]
        let builder2 = ReturnBuilder<Any, Int>(mock: mock, signature: signature, params: params2)

        // Act
        builder1.then(return: 1)
        builder2.then(return: 2)

        // Assert
        let stubGroups = getStubGroups(for: signature)
        #expect(stubGroups.count == 2)

        // Verify matchers
        #expect(stubGroups[0].matchers.count == 1)
        let matcher1 = stubGroups[0].matchers.first as! ArgumentMatcher<Int>
        guard case .any = matcher1 else {
            Issue.record("Incorrect matcher")
            return
        }

        #expect(stubGroups[1].matchers.count == 1)
        let matcher2 = stubGroups[1].matchers.first as! ArgumentMatcher<Int>
        guard case .equalTo(4) = matcher2 else {
            Issue.record("Incorrect matcher")
            return
        }
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
        let stubs = builder.getCurrentStubs()?.producers as! [AsyncProducer]
        #expect(stubs.count == 1)

        // Verify producer
        #expect(tracker.value == 0)
        _ = try await stubs[0].callAsFunction([1])
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
        let stubs = builder.getCurrentStubs()?.producers as! [Producer]
        #expect(stubs.count == 1)

        // Verify producer (Void)
        #expect(throws: TestError.self) {
            try stubs[0].callAsFunction([1])
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
        let stubs = builder.getCurrentStubs()?.producers as! [Producer]
        #expect(stubs.count == 1)

        // Verify producer (Void)
        #expect(throws: TestError.self) {
            try stubs[0].callAsFunction([1])
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
        let stubs = builder.getCurrentStubs()?.producers as! [AsyncProducer]
        #expect(stubs.count == 1)

        // Verify producer
        #expect(tracker.value == 0)
        await #expect(throws: TestError.self) {
            _ = try await stubs[0].callAsFunction([1])
        }
        #expect(tracker.value == 1) // tracker is updated BEFORE throwing
    }

    private func getStubGroups(for signature: String) -> [StubGroup] {
        mock.metadata.withLock {
            $0[signature]?.allStubs() ?? []
        }
    }
}

// MARK: - Convenience

private extension ReturnBuilder {
    func getCurrentStubs() -> StubGroup? {
        mock.metadata.withLock {
            $0[self.signature]?.allStubs().first { $0.id == self.stubGroupId }
        }
    }
}
