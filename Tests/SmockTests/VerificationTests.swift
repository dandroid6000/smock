//
//  VerificationTests.swift
//  Smock
//
//  Created by Dan Kane on 9/14/26.
//

import Testing

@testable import Smock

struct VerificationTests {
    @Test
    func `exactly must match exact call count`() {
        let exactly = Verification.exactly(1)
        #expect(!exactly.verify(count: 0))
        #expect(exactly.verify(count: 1))
        #expect(!exactly.verify(count: 2))
    }

    @Test
    func `atLeast must be equal or greater than call count`() {
        let atLeast = Verification.atLeast(1)
        #expect(!atLeast.verify(count: 0))
        #expect(atLeast.verify(count: 1))
        #expect(atLeast.verify(count: 2))
    }

    @Test
    func `atMost must be equal or less than call count`() {
        let atLeast = Verification.atMost(1)
        #expect(atLeast.verify(count: 0))
        #expect(atLeast.verify(count: 1))
        #expect(!atLeast.verify(count: 2))
    }

    @Test
    func `never must have zero call count`() {
        let atLeast = Verification.never
        #expect(atLeast.verify(count: 0))
        #expect(!atLeast.verify(count: 1))
        #expect(!atLeast.verify(count: 2))
    }
}
