//
//  ArgumentMatcherTests.swift
//  Smock
//
//  Created by Dan Kane on 9/19/26.
//

import Testing

@testable import Smock

struct ArgumentMatcherTests {
    @Test
    func `any(_) matcher should match any value of the same type`() async throws {
        // Arrange
        let intMatcher: ArgumentMatcher<Int> = .any()
        let stringMatcher = ArgumentMatcher.any(String.self)
        let customMatcher = ArgumentMatcher.any(CustomClass.self)

        // Act/Assert
        #expect(intMatcher.matches(1))
        #expect(intMatcher.matches(2))
        #expect(intMatcher.matches(20))

        #expect(stringMatcher.matches("one"))
        #expect(stringMatcher.matches("two"))
        #expect(stringMatcher.matches("three"))

        #expect(customMatcher.matches(CustomClass(a: "a")))
        #expect(customMatcher.matches(CustomClass(a: "b")))
        #expect(customMatcher.matches(CustomClass(a: "c")))

        // Different types fail
        #expect(!intMatcher.matches("one"))
        #expect(!intMatcher.matches(2.0))
        #expect(!intMatcher.matches(true))
        #expect(!intMatcher.matches(CustomClass(a: "a")))

        #expect(!stringMatcher.matches(1))
        #expect(!stringMatcher.matches(2.0))
        #expect(!stringMatcher.matches(true))
        #expect(!stringMatcher.matches(CustomClass(a: "a")))

        #expect(!customMatcher.matches(1))
        #expect(!customMatcher.matches("one"))
        #expect(!customMatcher.matches(2.0))
        #expect(!customMatcher.matches(true))
    }

    @Test
    func `equalTo(_) matcher should match Equatable values`() async throws {
        let equalToInt = ArgumentMatcher.equalTo(1)
        #expect(equalToInt.matches(1))
        #expect(!equalToInt.matches(2))
        #expect(!equalToInt.matches("1"))

        let equalToString = ArgumentMatcher.equalTo("one")
        #expect(equalToString.matches("one"))
        #expect(!equalToString.matches("two"))
        #expect(!equalToString.matches(1))
    }

    @Test
    func `equalTo(_) matcher should fall back to reference identity for non-Equatable types`() async throws {
        let instance1 = CustomClass(a: "one")
        let instance1b = instance1 // reference copy
        let instance2 = CustomClass(a: "one") // equal but not identical

        let equalToInstance1 = ArgumentMatcher.equalTo(instance1)
        #expect(equalToInstance1.matches(instance1b))

        // Does not match a different instance with the same values
        #expect(!equalToInstance1.matches(instance2))
    }
}

private final class CustomClass: Sendable {
    let a: String
    init(a: String) {
        self.a = a
    }
}
