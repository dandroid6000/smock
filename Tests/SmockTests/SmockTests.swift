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

    @Test
    func `trackCall(_:params:) tracks calls with params`() async throws {
        let call1 = "one(a: Int)"
        let call2 = "two(a: Int, b: String)"

        mock.trackCall(call1, params: 1)
        #expect(getCalls(for: call1)[0].params as? [Int] == [1])
        #expect(getCalls(for: call2).count == 0)

        mock.trackCall(call1, params: 2)
        #expect(getCalls(for: call1)[1].params as? [Int] == [2])
        #expect(getCalls(for: call2).count == 0)

        mock.trackCall("two(a: Int, b: String)", params: 3, "value")
        #expect(getCalls(for: call1).count == 2)
        let call2Params = getCalls(for: call2)[0].params
        #expect(call2Params[0] as? Int == 3)
        #expect(call2Params[1] as? String == "value")
    }

    @Test
    func `getValue(for:params:) retrives a stub matching the params`() throws {
        // Arrange
        let signature = "test"
        let groupId = mock.createStubGroup(for: signature, matchers: [ArgumentMatcher<Int>.any()])
        mock.stubProducer({ _ in "value" }, for: signature, stubGroupId: groupId)

        // Act
        let value: String = try mock.getValue(for: "test", params: 1)
        #expect(value == "value")
    }

    @Test
    func `getValue(for:params:) retrives an async stub matching the params`() async throws {
        // Arrange
        let signature = "test"
        let groupId = mock.createStubGroup(for: signature, matchers: [ArgumentMatcher<Int>.any()])
        mock.stubAsyncProducer({ _ in "value" }, for: signature, stubGroupId: groupId)

        // Act
        let value: String = try await mock.getValue(for: "test", params: 1)
        #expect(value == "value")
    }

    @Test
    func `getValue(for:params:) should crash for Void calls with no stub when strict`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let strictMock = ExampleServiceMock() // Cannot capture external object
            // Act
            try await strictMock.getValue(for: "test") as Void
        }
    }

    @Test
    func `getValue(for:params:) should crash for Optional calls with no stub when strict`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let strictMock = ExampleServiceMock() // Cannot capture external object
            // Act
            _ = try await strictMock.getValue(for: "test") as String?
        }
    }

    @Test
    func `getValue(for:params:) should crash for non-Optional calls with no stub when strict`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let strictMock = ExampleServiceMock() // Cannot capture external object
            // Act
            _ = try await strictMock.getValue(for: "test") as String
        }
    }

    @Test
    func `getValue(for:params:) should run Void calls with no stub when relaxed`() async throws {
        // Arrange - no stubs
        let relaxedMock = ExampleServiceMock(relaxed: true)
        // Act - method does not fail
        try await relaxedMock.getValue(for: "test") as Void
    }

    @Test
    func `getValue(for:params:) should return nil for Optional calls with no stub when relaxed`() async throws {
        // Arrange - no stubs
        let relaxedMock = ExampleServiceMock(relaxed: true)
        // Act
        let result = try await relaxedMock.getValue(for: "test") as String?
        // Assert
        #expect(result == nil)
    }

    @Test
    func `getValue(for:params:) should crash for non-Optional calls with no stub when relaxed`() async throws {
        await #expect(processExitsWith: .failure) {
            // Arrange
            let relaxedMock = ExampleServiceMock(relaxed: true) // Cannot capture external object
            // Act
            _ = try await relaxedMock.getValue(for: "test") as String
        }
    }

    @Test
    func `createStubGroup(for:matchers:) should create a new stub group with no producers`() async throws {
        let signature = "test"
        #expect(getStubs(for: signature).isEmpty)

        let groupId = mock.createStubGroup(for: signature, matchers: [ArgumentMatcher<Int>.any()])

        let groups = getStubs(for: signature)
        #expect(groups.count == 1)
        #expect(groups[0].id == groupId)
        #expect(groups[0].producers.isEmpty)
        #expect(groups[0].matchers.count == 1)
        guard case ArgumentMatcher<Int>.any = groups[0].matchers[0] else {
            Issue.record("Expected .any(Int)")
            return
        }
    }

    @Test
    func `stubProducer(_:for:stubGroupId:) should add a producer to an existing group`() async throws {
        let signature = "test"

        // Request does nothing if group does not exist
        mock.stubProducer({ _ in return 1 }, for: signature, stubGroupId: 0)
        #expect(getStubs(for: signature).count == 0)

        // Create a group and then add
        let groupId = mock.createStubGroup(for: signature, matchers: [])
        mock.stubProducer({ _ in return 1 }, for: signature, stubGroupId: groupId)

        // Verify producer was added
        let groups = getStubs(for: signature)
        #expect(groups[0].producers.count == 1)

        // Verify type is Producer and producer is not async
        let producer = try #require(groups[0].producers[0] as? Producer)
        let value = try producer.callAsFunction([]) as! Int
        #expect(value == 1)
    }

    @Test
    func `stubAsyncProducer(_:for:stubGroupId:) should add an async producer to an existing group`() async throws {
        let signature = "test"

        // Request does nothing if group does not exist
        mock.stubAsyncProducer({ _ in return 1 }, for: signature, stubGroupId: 0)
        #expect(getStubs(for: signature).count == 0)

        // Create a group and then add
        let groupId = mock.createStubGroup(for: signature, matchers: [])
        mock.stubAsyncProducer({ _ in return 1 }, for: signature, stubGroupId: groupId)

        // Verify producer was added
        let groups = getStubs(for: signature)
        #expect(groups[0].producers.count == 1)

        // Verify type is AsyncProducer and producer is async
        let producer = try #require(groups[0].producers[0] as? AsyncProducer)
        let value = try await producer.callAsFunction([]) as! Int
        #expect(value == 1)
    }

    @Test
    func `verifyCalls(for:matching:) should retrieve all matching calls and verify the first unverified one`() async throws {
        let signature = "one(a: Int, b: String)"
        mock.trackCall(signature, params: 1, "one")
        mock.trackCall(signature, params: 2, "one")
        mock.trackCall(signature, params: 3, "two")
        mock.trackCall(signature, params: 3, "three")

        let allCalls = mock.verifyCalls(for: signature, matching: [ArgumentMatcher<Int>.any(), ArgumentMatcher<String>.any()])
        #expect(allCalls.count == 4)
        verifyCalls(for: signature) {
            #expect($0[0].isVerified) // newly verified
            #expect(!$0[1].isVerified)
            #expect(!$0[2].isVerified)
            #expect(!$0[3].isVerified)
        }

        let intEquals3 = mock.verifyCalls(for: signature, matching: [ArgumentMatcher<Int>.equalTo(3), ArgumentMatcher<String>.any()])
        #expect(intEquals3.count == 2)
        verifyCalls(for: signature) {
            #expect($0[0].isVerified) // verified in step 1
            #expect(!$0[1].isVerified)
            #expect($0[2].isVerified) // newly verified
            #expect(!$0[3].isVerified)
        }

        let stringEqualsThree = mock.verifyCalls(for: signature, matching: [ArgumentMatcher<Int>.any(), ArgumentMatcher<String>.equalTo("three")])
        #expect(stringEqualsThree.count == 1)
        verifyCalls(for: signature) {
            #expect($0[0].isVerified) // verified in step 1
            #expect(!$0[1].isVerified)
            #expect($0[2].isVerified) // verified in step 2
            #expect($0[3].isVerified) // newly verified
        }

        let allCallsAgain = mock.verifyCalls(for: signature, matching: [ArgumentMatcher<Int>.any(), ArgumentMatcher<String>.any()])
        #expect(allCallsAgain.count == 4)
        verifyCalls(for: signature) {
            #expect($0[0].isVerified) // verified in step 1
            #expect($0[1].isVerified) // newly verified
            #expect($0[2].isVerified) // verified in step 2
            #expect($0[3].isVerified) // verified in step 3
        }
    }

    @Test
    func `getAllCalls() gets all calls as VerificationResults`() async throws {
        #expect(mock.getAllCalls().isEmpty)

        mock.trackCall("call1", params: 1)
        mock.trackCall("call1", params: 2)
        mock.trackCall("call2", params: 2)
        mock.trackCall("call3", params: 3)

        let results = mock.getAllCalls()
        #expect(results.count == 4)

        let call1 = results.filter { $0.signature == "call1" }
        #expect(call1.count == 2)
        #expect(call1[0].call?.params[0] as! Int == 1)
        #expect(call1[1].call?.params[0] as! Int == 2)

        let call2 = results.filter { $0.signature == "call2" }
        #expect(call2.count == 1)
        #expect(call2[0].call?.params[0] as! Int == 2)

        let call3 = results.filter { $0.signature == "call3" }
        #expect(call3.count == 1)
        #expect(call3[0].call?.params[0] as! Int == 3)
    }

    @Test
    func `getUnverifiedCalls() gets unverified calls as VerificationResults`() async throws {
        #expect(mock.getAllCalls().isEmpty)

        mock.trackCall("call1", params: 1)
        mock.trackCall("call1", params: 2)
        mock.trackCall("call2", params: 2)
        mock.trackCall("call3", params: 3)

        // All unverified
        #expect(mock.getUnverifiedCalls().count == 4)

        // Verify and check again
        let call1 = mock.verifyCalls(for: "call1", matching: [ArgumentMatcher<Int>.any()])
        #expect(call1.count == 2)
        #expect(mock.getUnverifiedCalls().count == 3)

        // Verify and check again
        let call2 = mock.verifyCalls(for: "call2", matching: [ArgumentMatcher<Int>.any()])
        #expect(call2.count == 1)
        #expect(mock.getUnverifiedCalls().count == 2)

        // Verify and check again
        let call1Again = mock.verifyCalls(for: "call1", matching: [ArgumentMatcher<Int>.any()])
        #expect(call1Again.count == 2)
        #expect(mock.getUnverifiedCalls().count == 1)

        // Verify and check again
        let call3 = mock.verifyCalls(for: "call3", matching: [ArgumentMatcher<Int>.any()])
        #expect(call3.count == 1)
        #expect(mock.getUnverifiedCalls().count == 0)
    }

    @Test func `reset(_:) should clear all metadata`() async throws {
        // Stub some, call others
        _ = mock.createStubGroup(for: "call1", matchers: [])
        _ = mock.createStubGroup(for: "call2", matchers: [])

        mock.trackCall("call2", params: 2)
        mock.trackCall("call3", params: 3)

        // Confirm count before reset
        let count = mock.metadata.withLock { $0.count }
        #expect(count == 3)

        // Reset
        reset(mock)

        let afterReset = mock.metadata.withLock { $0.count }
        #expect(afterReset == 0)
    }

    private func verifyCalls(for signature: String, using block: ([Call]) -> Void) {
        block(getCalls(for: signature))
    }

    private func getCalls(for signature: String) -> [Call] {
        mock.metadata.withLock {
            $0[signature]?.allCalls() ?? []
        }
    }

    private func getStubs(for signature: String) -> [StubGroup] {
        mock.metadata.withLock {
            $0[signature]?.allStubs() ?? []
        }
    }
}
