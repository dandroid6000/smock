//
//  SmockExampleTests.swift
//  SmockExampleTests
//
//  Created by Dan Kane on 7/5/26.
//

internal import Smock
import Testing
@testable import SmockExample

struct SmockExampleTests {

    private var mockService = MyServiceMock()

    @Test
    func example() async throws {
        when(mockService).name.thenReturn("Foo")
        when(mockService).doSomething().thenReturn()

        let name = mockService.name
        mockService.doSomething()

        #expect(name == "Foo")

        inOrder {
            verify(mockService).name.wasRead(.exactly(1))
            verify(mockService).doSomething().wasCalled()
        }

        verifyNoMoreInteractions(mockService)
    }

}
