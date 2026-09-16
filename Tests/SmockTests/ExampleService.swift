//
//  ExampleService.swift
//  Smock
//
//  Created by Dan Kane on 9/14/26.
//

import Smock
import Foundation

@Mockable
protocol ExampleService: AnyObject {
    var readWriteProperty: String { get set }
    var readOnlyProperty: String { get }
    var asyncProperty: Int { get async }
    var throwingProperty: String { get throws }
    var asyncThrowingProperty: String { get async throws }

    func voidMethod() // This comment should get stripped
    func returningMethod() -> Int
    func optionalMethod() -> Int?
    func throwingMethod() throws
    func asyncThrowingMethod() async throws

    func overloadedReturn()
    func overloadedReturn() -> String
    func overloadedReturn() -> Int

    func overloadedParam(param: String)
    func overloadedParam(param: Int)

    func twoArgMethod( // Multi-line declarations are supported, even with comments
        _ arg1: String,
        _ arg2: Int
    )

    func variadic(_ args: Int...)
}
