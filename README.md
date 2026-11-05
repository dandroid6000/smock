# Smock
A pure Swift mocking framework.

Smock uses a single macro attached to your protocol to generate a complete, flexible mock that conforms to it. Stubbing 
and verifying are performed via simple, natural expressions. All generated code is debug-only, using compiler 
directives, as it is intended solely for testing purposes.

## Contents

* [Installation](#installation)
* [Usage](#usage)
    * [Generating Mocks](#generating-mocks)
    * [Stubbing](#stubbing)
        * [Returning Values](#returning-values)
        * [Throwing Errors](#throwing-errors)
        * [Invoking Answers](#invoking-answers)
            * [Accessing Input Parameters](#accessing-input-parameters)
        * [Relaxed Mocks](#relaxed-mocks)
        * [Static Mocks](#static-mocks)
        * [Stub Chaining](#stub-chaining)
        * [Parameter Matching](#parameter-matching)
    * [Verifying](#verifying)
        * [Verification Modes](#verification-modes)
        * [Method Verification](#method-verification)
        * [Property/Subscript Verification](#propertysubscript-verification)
        * [Parameter Matching (Verifiers)](#parameter-matching-verifiers)
        * [Verifying Mock Interactions](#verifying-mock-interactions)
        * [Verifying Call Order](#verifying-call-order)
* [Acknowledgments](#acknowledgments)

# Installation

The package can be added to your project via Swift Package Manager.

Note: Swift 5.9 is supported, but Swift 6+ is recommended.

```swift
.package(url: "https://github.com/dandroid6000/smock.git", from: "0.1.0")
```

# Usage

## Generating Mocks

To generate a mock for your protocol, simply attach the `@Mockable` macro to it.

```swift
@Mockable
protocol MyService {
    var aValue: String { get }
    func makeACall()
}
```

The generated mock will be the protocol name with "Mock" appended, and will conform to the protocol.  
Mocks are:
* `nonisolated` to simplify testing in **non-async** environments
* `@unchecked Sendable` to simplify testing in **async** environments
    * Internal state is managed by `Mutex`, to ensure thread safety
* `final` to satisfy `Sendable` conformance

```swift
// Generated code
final nonisolated class MyServiceMock: Smock<any MyService>, MyService, @unchecked Sendable {
    // Matching member declarations invoking mock functionality
}
```

## Stubbing

For each mock, a strongly-typed `when` method is also generated which constructs a stub builder for the mock. The 
builder contains duplicate protocol implementations which accept [matchers](#parameter-matching) and return a builder 
for that member.

### Returning Values

Each builder has a `then(return:)` method which can be invoked to stub a return value. `Void` methods have a special
`thenReturn()` convenience.

```swift
when(mock).aValue.then(return: "This is a value")
when(mock).makeACall().thenReturn()

print(mock.aValue) // Output: This is a value
mock.makeACall() // succeeds
```

### Throwing Errors

A `then(throw:)` method becomes available for throwing methods or getters.

```swift
when(mock).trySomething().then(throw: MyError.failure)

do {
    try mock.trySomething(with: 0)
} catch {
    print("Caught \(error)") // Output: Caught failure
}
```

### Invoking Answers

The `then(answer:)` method allows stubbing a closure to be invoked at call time. This closure can be `throws`, `async`, 
or both, depending on the member being stubbed, and must return the type expected by the member.

```swift
when(mock).aValue.then {
    // Logic can go here...
    return myCondition ? "answer" : "anotherAnswer"
}
when(mock).trySomething().then {
    // And here...
    throw MyError.failure
}
when(mock).fetchSomething().then {
    /// And here...
    try await getFromStorage()
}
```

#### Accessing Input Parameters

Each `then(answer:)` block has an additional variant which provides a parameter of type `Args`. This parameter contains 
all of input parameters to the original member, and can be accessed via subscript or convenience method.

```swift
when(mock).doSomething(with: .any()).then { args in
    let bySubscript: String = args[0]
    let byConvenience = args.getString(at: 0)
    return bySubscript + byConvenience
}
```

### Relaxed Mocks

A mock can be initialized or set as `relaxed`, in which case `Void` and `Optional` members can be invoked 
without explicit stubs.

```swift
let mock = MyServiceMock(relaxed: true)

mock.makeACall() // succeeds
let value: Int? = mock.maybeGetANumber() // nil

mock.relaxed = false
mock.makeACall() // crash - not stubbed
_ = mock.maybeGetANumber() // crash - not stubbed
```

### Static Mocks

Smock manages a separate mock instance for static members. These members can be stubbed using the mock class type.

```swift
when(MyServiceMock.self).globalState.then(return: 0)

print(MyServiceMock.globalState) // Output: 0
``` 

### Stub Chaining

Stubbing can be chained to create different responses for successive calls. The last stub wil be delivered indefinitely.

```swift
when(mock).aValue
    .then(return: "This is the first value")
    .then { "This is the next value" }
    .then(return: "This is the last value") // repeated

print(mock.aValue) // Output: This is the first value
print(mock.aValue) // Output: This is the next value
print(mock.aValue) // Output: This is the last value
print(mock.aValue) // Output: This is the last value
```

### Parameter Matching

Methods with parameters can be stubbed to match specific call-time values.

* `.any(_)` matches any value
    * Accepts a type to match, typically inferred by the compiler but can be supplied to disambiguate overloaded methods
* `.equalTo(_)` matches a specific value
    * `Equatable` types will be evaluated as such
    * Otherwise, reference types will be evaluated for identity (`===`)
    * Otherwise, the match will fail
* Literal values are interpreted as `.equalTo(_)`

```swift
let mock = MyServiceMock()

// Matches any input parameter
when(mock).doSomething(with: .any())
    .then(return: "A fallback string")

// Matches "one" exactly
when(mock).doSomething(with: .equalTo("one"))
    .then(return: "Input was 'one'")

// Literal syntax also works
when(mock).doSomething(with: "two") // same as .equalTo("two")
    .then(return: "Input was 'two'")

// Note: Using .any() again would shadow earlier matchers and ONLY this stub would match:
// when(mock).doSomething(to: .any()).then(return: "The one and only value")

print(mock.doSomething(with: "one") // Output: Input was 'one'
print(mock.doSomething(with: "two") // Output: Input was 'two'
print(mock.doSomething(with: "three") // Output: A fallback string
```

## Verifying

Similar to stubbing, each mock has an associated strongly-typed `verify` method which constructs a verifier for the 
mock. The verifier contains duplicate protocol implementations which accept [matchers](#parameter-matching) and return a 
verifier for that member.

### Verification Modes

Each verifier method accepts a `Verification` parameter, which defaults to `.atLeast(1)`.

The verifier will report an issue to the test framework if the member's call history does not satisfy the associated 
condition:
* `.exactly(n)` - The member was invoked EXACTLY n times
* `.atLeast(n)` - The member was invoked n times or more
* `.atMost(n)` - The member was invoked n times or fewer (including zero)
* `.never` - The member was never invoked

### Method Verification

Method verifiers expose a `wasCalled(_:)` method which asserts that the method was called in accordance with the 
verification mode. To disambiguate overloaded methods with different return types, use the `wasCalled(returning:_:)` 
variant.

```swift
verify(mock).makeACall().wasCalled(.exactly(2))
```

### Property/Subscript Verification

Property and subscript verifiers expose a `wasRead(_:)` method which asserts that the property was read in accordance 
with the verification mode. To disambiguate overloaded subscripts with different return types, use the `wasRead(as:_:)` 
variant.

Writable property/subscript verifiers also expose a `wasSet(_:)` method which asserts that the property was set in accordance 
with the verifier.

```swift
verify(mock).aValue.wasRead(.never)

verify(mock)[index: 0].wasSet(.atLeast(2))

verify(MyServiceMock.self).globalState.wasSet()
```

### Parameter Matching (Verifiers)

Similar to stubbing, matchers can be supplied to method verifiers to assert that specific parameters were provided.

Writable property/subscript matchers are passed in the verifier method itself, since properties don't have parameters in 
the same way.

```swift
verify(mock).doSomething(with: .any()).wasCalled(.exactly(4))
verify(mock).doSomething(with: "good").wasCalled()
verify(mock).doSomething(with: "bad").wasCalled(.never)

verify(mock)[index: .any()].wasSet(to: 0)
verify(MyServiceMock.self).globalState.wasSet(to: 5)
```

### Verifying Mock Interactions

Two top-level functions can be used to assert the state of the mock:

* `verifyNoInteractions(_:)` accepts a mock or mock type (for static members) and asserts that no calls were made
* `verifyNoMoreInteractions(_:)` accepts a mock or mock type (for static members) and asserts that all calls were made 
have been verified

### Verifying Call Order

The `inOrder` method is a `@resultBuilder` which asserts that the *order* of the verifications within are for calls that 
were invoked the same order.

```swift
inOrder {
    // Assert that aValue was read
    verify(mock).aValue.wasRead()
    // Assert that doSomething(with: "next") was called AND that it occurred after aValue  
    verify(mock).doSomething(with: "next").wasCalled()
}
```

# Acknowledgments
Smock is built on top of the follwoing open-source tooling:
* `swift-mutex` for Swift 6 Mutex backporting
- `swift-issue-reporting` for seamless integration with both Swift Testing and XCTest
