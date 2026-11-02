//
//  ExampleService.swift
//  Smock
//
//  Created by Dan Kane on 9/14/26.
//

import Smock
import Synchronization

@Mockable
protocol ExampleService: AnyObject {
    // Covers static-specific functionality (wrappers)
    static var staticProperty: Int { get set }
    static func staticVoidMethod()
    static func staticOptionalMethod() -> Int?
    static func staticReturningMethod() -> Int
    static func staticAsyncMethod() async

    var readWriteProperty: String { get set }
    var readOnlyProperty: String { get }
    var asyncProperty: Int { get async }
    var throwingProperty: String { get throws }
    var asyncThrowingProperty: String { get async throws }

    subscript(readOnly: Int) -> String { get }
    subscript(readWrite: String) -> Int { get set }

    func voidMethod()
    func returningMethod() -> Int
    func optionalMethod() -> Int?
    func throwingMethod() throws
    func asyncThrowingMethod() async throws
    func rethrowingMethod(task: @Sendable @escaping () throws -> Void) rethrows

    func inoutMethod(_ mutable: inout Int)
    func genericMethod<T: Sendable>(param: T)
    func constrainedMethod<T: Sendable>(param: T) where T: Equatable

    func overloadedReturn()
    func overloadedReturn() -> String
    func overloadedReturn() -> Int

    func overloadedParam(param: String)
    func overloadedParam(param: Int)

    func paramAndReturn(param: Int) -> String

    func twoArgMethod(
        _ arg1: String,
        _ arg2: Int
    )

    func variadic(_ args: Int...)
}

@Mockable
protocol GenericService {
    associatedtype Param: Equatable
    associatedtype Return

    var associatedProperty: Return { get }
    func associatedMethod(param: Param) -> Return
}

@Mockable
protocol AnotherService {
    var anotherProperty: Int { get }
}

enum TestError: Error {
    case expected
    case another
}

/// Wrapper which allows 'sending' mutable state across isolation context
final class SendableBox<Value: Sendable>: Sendable {
    private let _value: Mutex<Value>
    var value: Value {
        get { _value.withLock { $0 } }
        set { _value.withLock { $0 = newValue } }
    }
    init(_ initialValue: Value) { self._value = Mutex(initialValue) }

    func update(to value: Value) async {
        self.value = value
    }
}
