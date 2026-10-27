import Smock
import IssueReporting

enum AnError: Error {
    case error
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
protocol Foo {
    static var foo: Int { get }
    func executeTask(_ task: @Sendable @escaping () throws -> Void) rethrows
//    static func updateUI() -> Int
}

@Mockable
protocol Bar {
    static var minus1: Int { get }
    static var minus2: Int { get async }
    static func minus3()

    var zero: Int? { get }
    var one: Int { get async throws }
    var two: Int { get set }

    subscript(index: Int) -> String { get set }
    subscript(key: String, defaultValue value: Int) -> Int { get set }

    func three()
    func four(a: Int) async throws -> Int
    func five(_ a: Int, _ b: String)
}

let mock = FooMock()

let box = SendableBox(false)

when(mock).executeTask(.any()).then { args in
    let closure: @Sendable () throws -> Void = try! args[0]
    do {
        try closure()
    } catch {
        print("CAUGHT: \(error)")
    }
}

mock.executeTask {
    print("!!! EXECUTING")
    throw AnError.error
}

verify(mock).executeTask(.any()).wasCalled()

//when(mock).updateUI().then(return: 2)
//
//_ = mock.updateUI()
//
//verify(mock).updateUI().wasCalled()
