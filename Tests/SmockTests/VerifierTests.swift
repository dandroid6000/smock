//
//  VerifierTests.swift
//  Smock
//
//  Created by Dan Kane on 10/30/26.
//

import Testing

@testable import Smock

// Tests must be run serially since they deal with global state
@Suite(.serialized)
class VerifierTests {
    let mock = ExampleServiceMock()

    deinit {
        // Clean the slate after each test
        SmockStatic.reset()
    }

    @Test
    func `MethodVerifier.wasCalled(_:) verifies calls matching params`() async throws {
        let noParamsVerifier = MethodVerifier<ExampleService, Int>(mock: mock, signature: "test")
        let anyInt = [ArgumentMatcher<Int>.any()]
        let anyIntVerifier = MethodVerifier<ExampleService, Int>(mock: mock, signature: "test", params: anyInt)
        let anyString = [ArgumentMatcher<String>.any()]
        let anyStringVerifier = MethodVerifier<ExampleService, Int>(mock: mock, signature: "test", params: anyString)

        noParamsVerifier.wasCalled(.never)
        anyIntVerifier.wasCalled(.never)
        anyStringVerifier.wasCalled(.never)

        // No params
        mock.trackCall("test")
        noParamsVerifier.wasCalled(.exactly(1))
        anyIntVerifier.wasCalled(.never)
        anyStringVerifier.wasCalled(.never)

        // Int param
        mock.trackCall("test", params: 1)
        noParamsVerifier.wasCalled(.exactly(1))
        anyIntVerifier.wasCalled(.exactly(1))
        anyStringVerifier.wasCalled(.never)

        // String param
        mock.trackCall("test", params: "value")
        noParamsVerifier.wasCalled(.exactly(1))
        anyIntVerifier.wasCalled(.exactly(1))
        anyStringVerifier.wasCalled(.exactly(1))
    }

    @Test
    func `PropertyVerifier.wasRead(_:) verifies reads`() async throws {
        let verifier = PropertyVerifier<ExampleService, Int>(mock: mock, signature: "test")

        verifier.wasRead(.never)

        // Write does not count as read (wouldn't actually happen for read-only property)
        mock.trackCall("test", params: 1)
        verifier.wasRead(.never)

        // Read and verify
        mock.trackCall("test")
        verifier.wasRead(.exactly(1))
    }

    @Test
    func `PropertyVerifier.wasSet(_:) verifies writes`() async throws {
        let verifier = WritablePropertyVerifier<ExampleService, Int>(mock: mock, signature: "test")

        verifier.wasRead(.never)
        verifier.wasSet(.never)

        // Read does not count as write
        mock.trackCall("test")
        verifier.wasRead(.exactly(1))
        verifier.wasSet(.never)

        // Set and verify
        mock.trackCall("test", params: 1)
        verifier.wasRead(.exactly(1))
        verifier.wasSet(.exactly(1))
    }

    @Test
    func `verifyNoInteractions asserts no calls were made`() async throws {
        verifyNoInteractions(mock)
        verifyNoInteractions(ExampleServiceMock.self)

        mock.trackCall("test")
        withKnownIssue {
            verifyNoInteractions(mock)
        }

        SmockStatic[ExampleService.self].trackCall("static")
        withKnownIssue {
            verifyNoInteractions(ExampleServiceMock.self)
        }
    }

    @Test
    func `verifyNoMoreInteractions asserts no unverified calls were made`() async throws {
        verifyNoMoreInteractions(mock)
        verifyNoMoreInteractions(ExampleServiceMock.self)

        // Calls are not verified
        mock.trackCall("test")
        withKnownIssue {
            verifyNoMoreInteractions(mock)
        }

        SmockStatic[ExampleService.self].trackCall("test")
        withKnownIssue {
            verifyNoMoreInteractions(ExampleServiceMock.self)
        }

        // Verify and assert
        _ = mock.verifyCalls(for: "test", matching: [])
        verifyNoMoreInteractions(mock)

        _ = SmockStatic[ExampleService.self].verifyCalls(for: "test", matching: [])
        verifyNoMoreInteractions(ExampleServiceMock.self)
    }

    // inOrder
    @Test
    func `inOrder verifies call order`() async throws {
        let verifier1 = PropertyVerifier<ExampleService, Int>(mock: mock, signature: "test1")
        let verifier2 = PropertyVerifier<ExampleService, Int>(mock: mock, signature: "test2")
        let verifier3 = PropertyVerifier<ExampleService, Int>(mock: mock, signature: "test3")

        mock.trackCall("test1")
        mock.trackCall("test2")
        mock.trackCall("test3")

        // Correct order
        inOrder {
            verifier1.wasRead()
            verifier2.wasRead()
            verifier3.wasRead()
        }

        // Incorrect order
        withKnownIssue {
            inOrder {
                verifier1.wasRead()
                verifier3.wasRead()
                verifier2.wasRead()
            }
        }

        withKnownIssue {
            inOrder {
                verifier2.wasRead()
                verifier1.wasRead()
                verifier3.wasRead()
            }
        }

        withKnownIssue {
            inOrder {
                verifier2.wasRead()
                verifier3.wasRead()
                verifier1.wasRead()
            }
        }

        withKnownIssue {
            inOrder {
                verifier3.wasRead()
                verifier1.wasRead()
                verifier2.wasRead()
            }
        }

        withKnownIssue {
            inOrder {
                verifier3.wasRead()
                verifier2.wasRead()
                verifier1.wasRead()
            }
        }
    }
}
