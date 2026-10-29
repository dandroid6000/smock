//
//  CallTests.swift
//  Smock
//
//  Created by Dan Kane on 10/28/26.
//

import Testing

@testable import Smock

struct CallTests {
    @Test
    func `description represents property getter`() async throws {
        verify(signature: "foo", expecting: ".foo")
        verify(signature: "bar", expecting: ".bar")
    }

    @Test
    func `description represents property setter`() async throws {
        verify(signature: "foo", with: [3], expecting: ".foo = 3")
        verify(signature: "bar", with: ["three"], expecting: ".bar = three")
    }

    @Test
    func `description represents methods with parameters passed`() async throws {
        verify(signature: "foo()", with: [], expecting: ".foo()")
        verify(signature: "bar(a: Int, b: String)", with: [3, "two"], expecting: ".bar(a: 3, b: two)")
        verify(signature: "bar(_: Int, c: String)", with: [3, "two"], expecting: ".bar(3, c: two)")
    }

    @Test
    func `description represents methods without parameters passed`() async throws {
        verify(signature: "foo()", expecting: ".foo()")
        verify(signature: "bar(a: Int, b: String)", expecting: ".bar(a:b:)")
        verify(signature: "baz(_: Int, c: String)", expecting: ".baz(_:c:)")
    }

    @Test
    func `description represents subscript reads`() async throws {
        verify(
            signature: "subscript(index: Int) -> String",
            with: [1],
            expecting: "subscript[index: 1]"
        )
        verify(
            signature: "subscript(key: String,  value: Int) -> Int",
            with: ["one", 2],
            expecting: "subscript[key: one, value: 2]"
        )
    }

    @Test
    func `description represents subscript writes`() async throws {
        verify(
            signature: "subscript(index: Int) -> String",
            with: [1, "new"],
            expecting: "subscript[index: 1] = new"
        )
        verify(
            signature: "subscript(key: String,  value: Int) -> Int",
            with: ["one", 2, "new"],
            expecting: "subscript[key: one, value: 2] = new"
        )
    }

    private func verify(
        signature: String,
        with params: [Any]? = nil,
        expecting description: String,
        filePath: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = Call.description(for: signature, params: params)

        let sourceLocation = SourceLocation(
            fileID: "SmockTests/CallTests.swift",
            filePath: String(describing: filePath),
            line: Int(line),
            column: 1
        )
        #expect(actual == description, sourceLocation: sourceLocation)
    }
}
