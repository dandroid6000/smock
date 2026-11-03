import Smock

enum AnError: Error {
    case anError
}

/// Wrapper which allows 'sending' mutable state across isolation context
final class SendableBox<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

class NonSendable {
    var x = 0 // mutable state is non-sendable
}

@Mockable
protocol MyService: AnyObject {
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

let mock = MyServiceMock()

let box = SendableBox(false)

when(mock).rethrowingMethod(task: .any()).then { args in
    // Cannot throw in rethrowing stub (only the closure can)
    let closure: @Sendable () throws -> Void = args[0]
    do {
        try closure()
    } catch {
        // Validate errors here
        print("CAUGHT: \(error)")
    }
}

mock.rethrowingMethod {
    print("!!! EXECUTING")
    throw AnError.anError
}

verify(mock).rethrowingMethod(task: .any()).wasCalled()

