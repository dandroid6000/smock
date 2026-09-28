import Smock

enum AnError: Error {
    case error
}

struct Baz: Equatable {
    let a: Int
}

@Mockable
protocol Foo {
//    var readOnlyProperty: Int { get }
//    var throwingProperty: Int { get throws }
//    var readWriteProperty: Int { get set }

    func noArgs() throws
//    func oneArg(_ a: Int)
    func twoArgs(_ a: Int, _ b: Int) -> Int
    func twoArgs(_ a: Int, _ b: Int)
//    func twoArgs(_ a: Int, c: Int) -> Int
    func twoArgs(_ a: Int, _ b: String)
//    func customArg(baz: Baz)
//    func arrayArg(_ a: [Int])
//    func arrayArg(_ a: Int...) // FIXME: Stubber has the same signature for this and the array variant...
//    func dictArg(_ a: [String: Int])
//    var twoArgs_aInt_cInt: Int { get }
}

@Mockable
protocol Bar {
    var zero: Int? { get }
    var one: Int { get async throws }
    var two: Int { get set }
    func three()
    func four(a: Int) async throws -> Int
    func five(_ a: Int, _ b: String)
}

let mock = BarMock(relaxed: false)

when(mock).zero.thenReturn(nil)
when(mock).one.thenReturn(1)
when(mock).two.then {
    print("INVOKED `.two`, args isEmpty: \($0.isEmpty)")
    return 2
}
//when(mock).three().thenReturn()
when(mock).four(a: 3).then {
    print("INVOKED `.four` with \($0.getInt(at: 0))")
    throw AnError.error
}
when(mock).five(.any(), .any()).then { args in
    print("INVOKED `.five` with \(args)")
}
//when(mock).four(.equalTo(2)).thenReturn(4)
//when(mock).four(.equalTo(3)).thenReturn(5)

_ = mock.zero
_ = try await mock.one
_ = mock.two
mock.two = 1
//_ = mock.one
//mock.three()
//_ = mock.three()
//_ = try await mock.four(2)
_ = try await mock.one
do {
    _ = try await mock.four(a: 3)
} catch {
    print("Caught error for .four(3): \(error)")
}
mock.five(5, "a")

verifyNoInteractions(mock)

verify(mock).four(a: .any()).wasCalled(.never)

inOrder {
    verify(mock).one.wasRead()
//    verify(mock).two.wasRead()
    verify(mock).two.wasSet(to: 1)
    verify(mock).three().wasCalled(.never)
    verify(mock).one.wasRead()
//    verify(mock).four(3).wasCalled(.exactly(1))
//    verify(mock).one.wasRead() // out of order
}

verifyNoMoreInteractions(mock)
