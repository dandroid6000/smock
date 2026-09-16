//
//  SmockTests.swift
//  Smock
//
//  Created by Dan Kane on 9/15/26.
//

import Testing

@testable import Smock

struct SmockTests {
    let mock = ExampleServiceMock()

    // MARK: - Strict/Relaxed

    @Test func `strict mock should crash for Void calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let mock = ExampleServiceMock() // Cannot capture external object
            // Act
            mock.voidMethod()
        }
    }

    @Test func `strict mock should crash for Optional calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let mock = ExampleServiceMock() // Cannot capture external object
            // Act
            _ = mock.optionalMethod()
        }
    }

    @Test func `strict mock should crash for non-Optional calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let mock = ExampleServiceMock() // Cannot capture external object
            // Act
            _ = mock.returningMethod()
        }
    }

    @Test
    func `relaxed mock should run Void calls with no stub`() async throws {
        // Arrange - no stubs
        let relaxedMock = ExampleServiceMock(relaxed: true)
        // Act - method does not fail
        relaxedMock.voidMethod()
    }

    @Test
    func `relaxed mock should return nil for Optional calls with no stub`() async throws {
        // Arrange - no stubs
        let relaxedMock = ExampleServiceMock(relaxed: true)
        // Act
        let result = relaxedMock.optionalMethod()
        // Assert
        #expect(result == nil)
    }

    @Test func `relaxed mock should crash for non-Optional calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let relaxedMock = ExampleServiceMock(relaxed: true) // Cannot capture external object
            // Act
            _ = relaxedMock.returningMethod()
        }
    }

    // MARK: - Stubbing

    @Test
    func `mock should return single response every time`() async throws {
        // Arrange
        let value = "one"

        when(mock).readOnlyProperty.thenReturn(value)

        // Act
        let read1 = mock.readOnlyProperty
        let read2 = mock.readOnlyProperty

        // Assert value is returned each time property is accessed
        #expect(read1 == value)
        #expect(read2 == value)
    }

    @Test
    func `mock should return ordered responses, repeating last`() async throws {
        // Arrange
        let value1 = "one"
        let value2 = "two"

        when(mock).readOnlyProperty
            .thenReturn(value1)
            .thenReturn(value2)

        // Act
        let read1 = mock.readOnlyProperty
        let read2 = mock.readOnlyProperty
        let read3 = mock.readOnlyProperty

        // Assert values are returned, repeating last
        #expect(read1 == value1)
        #expect(read2 == value2)
        #expect(read3 == value2)
    }

    @Test
    func `mock should run answer block at call time`() async throws {
        // Arrange
        let answer = "answer"
        let didInvokeAnswer = SendableBox(false)
        when(mock).readOnlyProperty.then {
            didInvokeAnswer.value = true
            return answer
        }

        // Act
        #expect(didInvokeAnswer.value == false) // not invoked yet
        let read1 = mock.readOnlyProperty

        // Assert
        #expect(didInvokeAnswer.value == true)
        #expect(read1 == answer)
    }

    @Test
    func `mock should track overloaded methods separately`() async throws {
        // Arrange
        when(mock).overloadedReturn().thenReturn()
        when(mock).overloadedReturn().thenReturn("value")
        when(mock).overloadedReturn().thenReturn(1)

        // Act
        mock.overloadedReturn() as Void
        let stringValue = mock.overloadedReturn() as String
        let intValue = mock.overloadedReturn() as Int

        // Assert
        let voidVerifier = verify(mock).overloadedReturn() as MethodVerifier<ExampleService, Void>
        voidVerifier.wasCalled(.exactly(1))

        let stringVerifier = verify(mock).overloadedReturn() as MethodVerifier<ExampleService, String>
        stringVerifier.wasCalled(.exactly(1))
        #expect(stringValue == "value")

        let intVerifier = verify(mock).overloadedReturn() as MethodVerifier<ExampleService, Int>
        intVerifier.wasCalled(.exactly(1))
        #expect(intValue == 1)
    }

    @Test
    func `mock should track overloaded params separately`() async throws {
        // Arrange
        when(mock).overloadedParam(param: .any(String.self)).thenReturn()
        when(mock).overloadedParam(param: .any(Int.self)).thenReturn()

        // Act
        mock.overloadedParam(param: "value")
        mock.overloadedParam(param: 1)

        // Assert - methods are tracked separately
        verify(mock).overloadedParam(param: .any(String.self)).wasCalled(.exactly(1))
        verify(mock).overloadedParam(param: .any(Int.self)).wasCalled(.exactly(1))
    }

    @Test
    func `mock supports stubbing variadic methods`() async throws {
        // Arrange
        when(mock).variadic(.any()).thenReturn()

        // Act
        mock.variadic(1, 2, 3)
        mock.variadic(1, 2)

        // Assert
        verify(mock).variadic([1, 2, 3]).wasCalled(.exactly(1))
        verify(mock).variadic([1, 2]).wasCalled(.exactly(1))
    }

    @Test
    func `mock should throw when stubbed`() async throws {
        // Arrange
        when(mock).throwingProperty
            .thenThrow(TestError.expected)
            .then { throw TestError.another }
        when(mock).throwingMethod()
            .thenReturn()
            .thenThrow(TestError.expected)
            .then { throw TestError.another }
            .then { /* no-op */ }

        // Act/Assert
        #expect(throws: TestError.expected) {
            try mock.throwingProperty // thenThrow
        }
        #expect(throws: TestError.another) {
            try mock.throwingProperty // then { throw }
        }

        try mock.throwingMethod() // thenReturn
        #expect(throws: TestError.expected) {
            try mock.throwingMethod() // thenThrow
        }
        #expect(throws: TestError.another) {
            try mock.throwingMethod() // then { throw }
        }
        try mock.throwingMethod() // then
        try mock.throwingMethod() // then (continued)
    }

    @Test
    func `mock should await when async`() async throws {
        // Arrange
        let clock = ContinuousClock()
        when(mock).asyncProperty
            .thenReturn(0)
            .then {
                // Return the duration of execution (>= 1)
                let start = clock.now
                try? await Task.sleep(for: .seconds(1)) // CANNOT THROW HERE
                let duration = clock.now - start
                return Int(duration.components.seconds)
            }
        when(mock).asyncThrowingProperty
            .thenThrow(TestError.expected)
            .then { throw TestError.another }
            .then {
                try await Task.sleep(for: .milliseconds(100)) // CAN THROW HERE
                return "awaited"
            }
        when(mock).asyncThrowingMethod()
            .thenThrow(TestError.expected)

        // Act
        let value = await mock.asyncProperty
        let duration = await mock.asyncProperty

        await #expect(throws: TestError.expected) {
            try await mock.asyncThrowingProperty
        }
        await #expect(throws: TestError.another) {
            try await mock.asyncThrowingProperty
        }
        let awaited = try await mock.asyncThrowingProperty

        await #expect(throws: TestError.expected) {
            try await mock.asyncThrowingMethod()
        }

        // Assert
        verify(mock).asyncProperty.wasRead()
        #expect(value == 0)
        #expect(duration == 1)
        #expect(awaited == "awaited")
    }

    // MARK: - Verification

    @Test
    func `mock should fail verification if property is not read`() {
        withKnownIssue {
            // Act - write, but no read
            mock.readWriteProperty = "new value"
            verify(mock).readWriteProperty.wasRead()
        }
    }

    @Test
    func `mock should fail verification if property is not set`() {
        withKnownIssue {
            // Arrange
            when(mock).readWriteProperty.thenReturn("value")

            // Act - read, but no write
            _ = mock.readWriteProperty
            verify(mock).readWriteProperty.wasSet()
        }
    }

    @Test
    func `mock should fail verification if method is not called`() {
        withKnownIssue {
            // Act - no calls
            verify(mock).voidMethod().wasCalled()
        }
    }

    @Test
    func `mock should track and verify property reads`() async throws {
        // Arrange
        when(mock).readOnlyProperty.thenReturn("value")

        // Act
        _ = mock.readOnlyProperty
        _ = mock.readOnlyProperty

        // Assert
        verify(mock).readOnlyProperty.wasRead(.exactly(2))
    }

    @Test
    func `mock should track and verify property writes`() async throws {
        // Act
        mock.readWriteProperty = "new value"
        mock.readWriteProperty = "another value"

        // Assert
        verify(mock).readWriteProperty.wasRead(.never) // distinct from writes

        // No param matches all writes
        verify(mock).readWriteProperty.wasSet(.exactly(2))

        // Explicit param only matches exact case
        verify(mock).readWriteProperty.wasSet(to: "another value", .exactly(1))
    }

    @Test
    func `mock should track and verify method calls`() async throws {
        // Arrange
        when(mock).twoArgMethod(.any(), .any()).thenReturn()

        // Act
        mock.twoArgMethod("one", 1)
        mock.twoArgMethod("two", 1)
        mock.twoArgMethod("three", 4)

        // Assert
        verify(mock).twoArgMethod(.any(), .any()).wasCalled(.exactly(3))
        verify(mock).twoArgMethod(.any(), 1).wasCalled(.exactly(2))
        verify(mock).twoArgMethod("three", 4).wasCalled(.exactly(1))
        verify(mock).twoArgMethod("three", 1).wasCalled(.never)
    }

    @Test
    func `mock should track verified calls and verify no more interactions`() async throws {
        // Arrange
        when(mock).twoArgMethod(.any(), .any()).thenReturn()

        // Act
        mock.twoArgMethod("one", 1)
        mock.twoArgMethod("two", 1)
        mock.twoArgMethod("three", 4)

        // Assert - verification 'verifies' in order
        let result1 = verify(mock).twoArgMethod(.any(), .any()).wasCalled()
        #expect(result1.calls.count == 3)
        #expect(result1.calls[0].isVerified)
        #expect(!result1.calls[1].isVerified)
        #expect(!result1.calls[2].isVerified)

        withKnownIssue {
            verifyNoMoreInteractions(mock)
        }

        // Verify again, 'verifies' next one
        let result2 = verify(mock).twoArgMethod(.any(), 1).wasCalled()
        #expect(result2.calls.count == 2)
        #expect(result2.calls[0].isVerified)
        #expect(result2.calls[1].isVerified)

        withKnownIssue {
            verifyNoMoreInteractions(mock)
        }

        // Verify again, 'verifies' last one
        let result3 = verify(mock).twoArgMethod("three", 4).wasCalled()
        #expect(result3.calls.count == 1)
        #expect(result3.calls[0].isVerified)

        // No more
        verifyNoMoreInteractions(mock)
    }

    @Test
    func `mock should verify no interactions`() async throws {
        verifyNoInteractions(mock)
    }

    @Test
    func `mock should fail to verify no interactions`() async throws {
        // Arrange
        when(mock).voidMethod().thenReturn()

        // Act
        mock.voidMethod()

        // Assert
        withKnownIssue {
            verifyNoInteractions(mock)
        }
    }

    @Test
    func `mock should verify order of interactions`() async throws {
        // Arrange
        when(mock).voidMethod().thenReturn()
        when(mock).readOnlyProperty.thenReturn("value")
        when(mock).optionalMethod().thenReturn(nil)

        // Act
        _ = mock.optionalMethod() // 1
        _ = mock.readOnlyProperty // 2
        mock.voidMethod() // 3

        // Assert
        inOrder {
            verify(mock).optionalMethod().wasCalled() // 1
            verify(mock).readOnlyProperty.wasRead() // 2
            verify(mock).voidMethod().wasCalled() // 3
        }

        withKnownIssue {
            inOrder {
                verify(mock).optionalMethod().wasCalled() // 1
                verify(mock).voidMethod().wasCalled() // 3 - still in order
                verify(mock).readOnlyProperty.wasRead() // 2 - out of order here
            }
        }

        withKnownIssue {
            inOrder {
                verify(mock).readOnlyProperty.wasRead() // 2
                verify(mock).voidMethod().wasCalled() // 3 - still in order
                verify(mock).optionalMethod().wasCalled() // 1 - out of order here
            }
        }
    }
}

enum TestError: Error {
    case expected
    case another
}

/// Wrapper which allows 'sending' mutable state across isolation context
final class SendableBox<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}
