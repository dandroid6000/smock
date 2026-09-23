//
//  SmockXcTests.swift
//  Smock
//
//  Created by Dan Kane on 9/22/26.
//

import XCTest

/// Test class to verify that XCTests function as expected when used with the framework.
class SmockXcTests: XCTestCase {
    var mock: ExampleServiceMock!

    override func setUp() {
        mock = ExampleServiceMock()
    }

    func testXcTestCoverage() {
        _ = XCTExpectFailure {
            verify(mock).readOnlyProperty.wasRead()
        }

        when(mock).readOnlyProperty.thenReturn("value")

        let value = mock.readOnlyProperty

        verify(mock).readOnlyProperty.wasRead()
        XCTAssertEqual(value, "value")
    }
}
