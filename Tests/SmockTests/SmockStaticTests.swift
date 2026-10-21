//
//  SmockStaticTests.swift
//  Smock
//
//  Created by Dan Kane on 9/30/26.
//

import Testing

@testable import Smock

// Tests must be run serially since they deal with global state
@Suite(.serialized)
class SmockStaticTests {
    let staticMock = SmockStatic[ExampleService.self]

    deinit {
        // Clean the slate after each test
        SmockStatic.reset()
    }

    // MARK: - Strict/Relaxed

    @Test func `strict static mock should crash for Void calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Act
            ExampleServiceMock.staticVoidMethod()
        }
    }

    @Test func `strict static mock should crash for Optional calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Act
            _ = ExampleServiceMock.staticOptionalMethod()
        }
    }

    @Test func `strict static mock should crash for non-Optional calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Act
            _ = ExampleServiceMock.staticReturningMethod()
        }
    }

    @Test
    func `relaxed static mock should run Void calls with no stub`() async throws {
        // Arrange - no stubs
        ExampleServiceMock.relaxed = true
        // Act - method does not fail
        ExampleServiceMock.staticVoidMethod()
    }

    @Test
    func `relaxed static mock should return nil for Optional calls with no stub`() async throws {
        // Arrange - no stubs
        ExampleServiceMock.relaxed = true
        // Act
        let result = ExampleServiceMock.staticOptionalMethod()
        // Assert
        #expect(result == nil)
    }

    @Test func `relaxed static mock should crash for non-Optional calls with no stub`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            ExampleServiceMock.relaxed = true
            // Act
            _ = ExampleServiceMock.staticReturningMethod()
        }
    }

    // MARK: - Stubbing

    @Test
    func `static mock should stub and return values`() async throws {
        // Arrange
        when(ExampleServiceMock.self).staticProperty.then(return: 1)
        when(ExampleServiceMock.self).staticReturningMethod().then(return: 2)

        // Act
        let read1 = ExampleServiceMock.staticProperty
        let read2 = ExampleServiceMock.staticReturningMethod()

        // Assert
        #expect(read1 == 1)
        #expect(read2 == 2)
    }

    @Test
    func `static mock should stub and run answer blocks`() async throws {
        // Arrange
        let didInvokeAnswer1 = SendableBox(false)
        let didInvokeAnswer2 = SendableBox(false)
        when(ExampleServiceMock.self).staticVoidMethod().then {
            didInvokeAnswer1.value = true
        }
        when(ExampleServiceMock.self).staticAsyncMethod().then {
            didInvokeAnswer2.value = true
        }

        // Act
        ExampleServiceMock.staticVoidMethod()
        await ExampleServiceMock.staticAsyncMethod()

        // Assert
        #expect(didInvokeAnswer1.value == true)
        #expect(didInvokeAnswer2.value == true)
    }

    @Test
    func `reset should clear static stubbed data`() async throws {
        await #expect(processExitsWith: .failure) {
            when(ExampleServiceMock.self).staticProperty.then(return: 1)

            let value = ExampleServiceMock.staticProperty
            verify(ExampleServiceMock.self).staticProperty.wasRead()
            #expect(value == 1)

            reset(ExampleServiceMock.self)

            // No longer stubbed
            _ = ExampleServiceMock.staticProperty
        }
    }

    // MARK: - Verification

    @Test
    func `static mock should track property reads`() {
        // Arrange
        when(ExampleServiceMock.self).staticProperty.then(return: 1)

        // Act
        ExampleServiceMock.staticProperty = 2 // write but no read
        withKnownIssue {
            verify(ExampleServiceMock.self).staticProperty.wasRead()
        }

        _ = ExampleServiceMock.staticProperty

        // Assert
        verify(ExampleServiceMock.self).staticProperty.wasRead()
    }

    @Test
    func `static mock should track property writes`() {
        // Arrange
        when(ExampleServiceMock.self).staticProperty.then(return: 1)

        // Act
        _ = ExampleServiceMock.staticProperty // read but no write
        withKnownIssue {
            verify(ExampleServiceMock.self).staticProperty.wasSet()
        }

        ExampleServiceMock.staticProperty = 2

        // Assert
        verify(ExampleServiceMock.self).staticProperty.wasSet()
    }

    @Test
    func `static mock should track method calls`() {
        // Arrange
        when(ExampleServiceMock.self).staticVoidMethod().thenReturn()

        // Act
        withKnownIssue {
            verify(ExampleServiceMock.self).staticVoidMethod().wasCalled()
        }

        ExampleServiceMock.self.staticVoidMethod()

        // Assert
        verify(ExampleServiceMock.self).staticVoidMethod().wasCalled()
    }

    @Test
    func `static mock should verify no more interactions`() async throws {
        // Arrange
        ExampleServiceMock.relaxed = true

        // Act
        ExampleServiceMock.staticVoidMethod()
        _ = ExampleServiceMock.staticOptionalMethod()

        // Assert - verification 'verifies' in order
        let result1 = verify(ExampleServiceMock.self).staticVoidMethod().wasCalled()
        let call1 = try #require(result1.call)
        #expect(call1.isVerified)

        withKnownIssue {
            verifyNoMoreInteractions(ExampleServiceMock.self)
        }

        // Verify again, 'verifies' next one
        let result2 = verify(ExampleServiceMock.self).staticOptionalMethod().wasCalled()
        let call2 = try #require(result2.call)
        #expect(call2.isVerified)

        // No more
        verifyNoMoreInteractions(ExampleServiceMock.self)
    }

    @Test
    func `static mock should verify no interactions`() async throws {
        // Arrange
        when(ExampleServiceMock.self).staticVoidMethod().thenReturn()

        // Act/Assert
        verifyNoInteractions(ExampleServiceMock.self)

        ExampleServiceMock.staticVoidMethod()

        withKnownIssue {
            verifyNoInteractions(ExampleServiceMock.self)
        }
    }
}
