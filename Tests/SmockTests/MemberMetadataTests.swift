//
//  MemberMetadataTests.swift
//  Smock
//
//  Created by Dan Kane on 10/29/26.
//

import Testing

@testable import Smock

struct MemberMetadataTests {

    @Test func `concurrent inserts all succeed and have unique IDs`() async {
        let metadata = MemberMetadata()
        let concurrentTasks = 10_000

        // Spin up thousands of concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentTasks {
                group.addTask {
                    metadata.addCall(Call(params: []))
                    _ = metadata.addStubGroup(matchers: [])
                }
            }
        }

        // Verify no data was dropped due to logical race conditions
        let finalCalls = metadata.allCalls()
        let finalStubs = metadata.allStubs()

        #expect(finalCalls.count == concurrentTasks)
        #expect(finalStubs.count == concurrentTasks)

        // Verify each StubGroup has a unique ID
        let uniqueIds = Set(finalStubs.map { $0.id })
        #expect(uniqueIds.count == concurrentTasks)
    }

    // MARK: - Stubs

    @Test
    func `getNextProducer(_) retrieves matching stub groups in LIFO order`() async throws {
        // Arrange
        let metadata = MemberMetadata()

        let anyStringGroupId = metadata.addStubGroup(matchers: [ArgumentMatcher<String>.any()])
        metadata.addStub(groupId: anyStringGroupId, producer: Producer({ _ in 1 }))

        let anyIntGroupId = metadata.addStubGroup(matchers: [ArgumentMatcher<Int>.any()])
        metadata.addStub(groupId: anyIntGroupId, producer: Producer({ _ in 2 }))

        let specificIntGroupId = metadata.addStubGroup(matchers: [ArgumentMatcher<Int>.equalTo(4)])
        metadata.addStub(groupId: specificIntGroupId, producer: Producer({ _ in 3 }))

        // Act/Assert
        #expect(metadata.allStubs().count == 3)

        // Exact match should return specific group
        let exactMatch = try #require(metadata.getNextProducer(matching: [4])) as Producer
        let exactResult = try exactMatch([4]) as! Int
        #expect(exactResult == 3)

        // Relaxed match should return relaxed group
        let relaxedMatch = try #require(metadata.getNextProducer(matching: [10])) as Producer
        let relaxedResult = try relaxedMatch([10]) as! Int
        #expect(relaxedResult == 2)

        // Other match should return its group
        let otherMatch = try #require(metadata.getNextProducer(matching: ["input"])) as Producer
        let otherResult = try otherMatch(["input"]) as! Int
        #expect(otherResult == 1)
    }

    @Test
    func `getNextProducer(_) retrieves stub group producers in FIFO order`() async throws {
        // Arrange
        let metadata = MemberMetadata()
        let groupId = metadata.addStubGroup(matchers: [])
        metadata.addStub(groupId: groupId, producer: Producer({ _ in 1 }))
        metadata.addStub(groupId: groupId, producer: Producer({ _ in 2 }))
        metadata.addStub(groupId: groupId, producer: Producer({ _ in 3 }))

        // Act/Assert
        #expect(metadata.group(id: groupId)?.producers.count == 3)
        #expect(metadata.group(id: groupId)?.executionCount == 0)

        let producer1 = try #require(metadata.getNextProducer(matching: [])) as Producer
        let result1 = try producer1([]) as! Int
        #expect(result1 == 1)
        #expect(metadata.group(id: groupId)?.executionCount == 1)

        let producer2 = try #require(metadata.getNextProducer(matching: [])) as Producer
        let result2 = try producer2([]) as! Int
        #expect(result2 == 2)
        #expect(metadata.group(id: groupId)?.executionCount == 2)

        let producer3 = try #require(metadata.getNextProducer(matching: [])) as Producer
        let result3 = try producer3([]) as! Int
        #expect(result3 == 3)
        #expect(metadata.group(id: groupId)?.executionCount == 3)

        // Should continue receiving the last one
        let producer4 = try #require(metadata.getNextProducer(matching: [])) as Producer
        let result4 = try producer4([]) as! Int
        #expect(result4 == 3)
        #expect(metadata.group(id: groupId)?.executionCount == 4)
    }

    // MARK: - Calls

    @Test
    func `verifyCalls(_) retrieves matching calls and tracks verification`() async throws {
        // Arrange
        let metadata = MemberMetadata()

        // Note: Parameter count and type will always match
        let call1 = Call(params: [1])
        let call2 = Call(params: [2])
        let call3 = Call(params: [3])

        metadata.addCall(call1)
        metadata.addCall(call2)
        metadata.addCall(call3)

        // Act
        let allCalls = metadata.verifyCalls(matching: [ArgumentMatcher<Int>.any()])

        // Assert
        #expect(allCalls.count == 3)
        #expect(allCalls[0].isVerified)
        #expect(!allCalls[1].isVerified)
        #expect(!allCalls[2].isVerified)

        let exactCalls = metadata.verifyCalls(matching: [ArgumentMatcher.equalTo(3)])

        #expect(exactCalls.count == 1)
        #expect(exactCalls[0].isVerified)

        // Confirm stored call verification
        #expect(metadata.allCalls()[0].isVerified)
        #expect(!metadata.allCalls()[1].isVerified)
        #expect(metadata.allCalls()[2].isVerified)

        // Match all again to verify the remaining call
        let allCalls2 = metadata.verifyCalls(matching: [ArgumentMatcher<Int>.any()])

        #expect(allCalls2.count == 3)
        #expect(allCalls2[0].isVerified)
        #expect(allCalls2[1].isVerified)
        #expect(allCalls2[2].isVerified)
    }

    @Test
    func `unverifiedCalls() retrieves all unverified calls`() async throws {
        // Arrange
        let metadata = MemberMetadata()

        // Note: Parameter count and type will always match
        let call1 = Call(params: [1])
        let call2 = Call(params: [2])
        let call3 = Call(params: [3])

        metadata.addCall(call1)
        metadata.addCall(call2)
        metadata.addCall(call3)

        #expect(metadata.unverifiedCalls().count == 3)

        _ = metadata.verifyCalls(matching: [ArgumentMatcher.equalTo(1)])
        #expect(metadata.unverifiedCalls().count == 2)

        _ = metadata.verifyCalls(matching: [ArgumentMatcher.equalTo(2)])
        #expect(metadata.unverifiedCalls().count == 1)

        _ = metadata.verifyCalls(matching: [ArgumentMatcher.equalTo(3)])
        #expect(metadata.unverifiedCalls().count == 0)
    }
}

private extension MemberMetadata {
    func group(id: Int) -> StubGroup? {
        allStubs().first { $0.id == id }
    }
}
