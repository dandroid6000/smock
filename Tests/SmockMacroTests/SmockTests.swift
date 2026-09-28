import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

import SmockMacros

let testMacros: [String: Macro.Type] = [
    "Mockable": MockableMacro.self,
]

struct SmockTests {
    @Test
    func testMacro() throws {
        assertMacroExpansion(
            """
            @Mockable
            protocol Service: AnyObject {
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

                func twoArgMethod( // Multi-line declarations are supported, even with comments
                    _ arg1: String,
                    _ arg2: Int
                )

                func variadicMethod(_ args: Int...)
            }
            """,
            expandedSource: """
            protocol Service: AnyObject {
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

                func twoArgMethod( // Multi-line declarations are supported, even with comments
                    _ arg1: String,
                    _ arg2: Int
                )

                func variadicMethod(_ args: Int...)
            }
            
            #if DEBUG
            final nonisolated class ServiceMock: Smock<Service>, Service, @unchecked Sendable {
                required public init(relaxed: Bool = false) {
                    super.init(relaxed: relaxed)
                }

                nonisolated var readWriteProperty: String {
                get {
                    trackGetter("readWriteProperty")
                    return try! getValue(for: "readWriteProperty")
                }
                set {
                    trackSetter("readWriteProperty", value: newValue)
                }
                }

                nonisolated var readOnlyProperty: String {
                    get {
                        trackGetter("readOnlyProperty")
                        return try! getValue(for: "readOnlyProperty")
                    }
                }

                nonisolated var asyncProperty: Int {
                    get async {
                        trackGetter("asyncProperty")
                        return try! await getValue(for: "asyncProperty")
                    }
                }

                nonisolated var throwingProperty: String {
                    get throws {
                        trackGetter("throwingProperty")
                        return try getValue(for: "throwingProperty")
                    }
                }

                nonisolated var asyncThrowingProperty: String {
                    get async throws {
                        trackGetter("asyncThrowingProperty")
                        return try await getValue(for: "asyncThrowingProperty")
                    }
                }

                nonisolated func voidMethod() {
                    trackMethod("voidMethod()")
                    return try! getValue(for: "voidMethod()")
                }

                nonisolated func returningMethod() -> Int {
                    trackMethod("returningMethod() -> Int")
                    return try! getValue(for: "returningMethod() -> Int")
                }

                nonisolated func optionalMethod() -> Int? {
                    trackMethod("optionalMethod() -> Int?")
                    return try! getValue(for: "optionalMethod() -> Int?")
                }

                nonisolated func throwingMethod() throws {
                    trackMethod("throwingMethod() throws")
                    return try getValue(for: "throwingMethod() throws")
                }

                nonisolated func asyncThrowingMethod() async throws {
                    trackMethod("asyncThrowingMethod() async throws")
                    return try await getValue(for: "asyncThrowingMethod() async throws")
                }

                nonisolated func twoArgMethod( _ arg1: String, _ arg2: Int) {
                    trackMethod("twoArgMethod( _ arg1: String, _ arg2: Int)", params: arg1, arg2)
                    return try! getValue(for: "twoArgMethod( _ arg1: String, _ arg2: Int)", params: arg1, arg2)
                }

                nonisolated func variadicMethod(_ args: Int...) {
                    trackMethod("variadicMethod(_ args: Int...)", params: args)
                    return try! getValue(for: "variadicMethod(_ args: Int...)", params: args)
                }
            }
            #endif

            #if DEBUG
            nonisolated struct ServiceStubBuilder {
                let mock: Smock<Service>

                init(mock: Smock<Service>) {
                    self.mock = mock
                }

                var readWriteProperty: ReturnBuilder<Service, String> {
                ReturnBuilder<Service, String>(mock: mock, signature: "readWriteProperty")
                }

                var readOnlyProperty: ReturnBuilder<Service, String> {
                    ReturnBuilder<Service, String>(mock: mock, signature: "readOnlyProperty")
                }

                var asyncProperty: AsyncReturnBuilder<Service, Int> {
                    AsyncReturnBuilder<Service, Int>(mock: mock, signature: "asyncProperty")
                }

                var throwingProperty: ThrowingReturnBuilder<Service, String> {
                    ThrowingReturnBuilder<Service, String>(mock: mock, signature: "throwingProperty")
                }

                var asyncThrowingProperty: AsyncThrowingReturnBuilder<Service, String> {
                    AsyncThrowingReturnBuilder<Service, String>(mock: mock, signature: "asyncThrowingProperty")
                }

                func voidMethod() -> ReturnBuilder<Service, Void> {
                    ReturnBuilder<Service, Void>(mock: mock, signature: "voidMethod()")
                }

                func returningMethod() -> ReturnBuilder<Service, Int> {
                    ReturnBuilder<Service, Int>(mock: mock, signature: "returningMethod() -> Int")
                }

                func optionalMethod() -> ReturnBuilder<Service, Int?> {
                    ReturnBuilder<Service, Int?>(mock: mock, signature: "optionalMethod() -> Int?")
                }

                func throwingMethod() -> ThrowingReturnBuilder<Service, Void> {
                    ThrowingReturnBuilder<Service, Void>(mock: mock, signature: "throwingMethod() throws")
                }

                func asyncThrowingMethod() -> AsyncThrowingReturnBuilder<Service, Void> {
                    AsyncThrowingReturnBuilder<Service, Void>(mock: mock, signature: "asyncThrowingMethod() async throws")
                }

                func twoArgMethod(_ arg1: ArgumentMatcher<String>, _ arg2: ArgumentMatcher<Int>) -> ReturnBuilder<Service, Void> {
                    ReturnBuilder<Service, Void>(mock: mock, signature: "twoArgMethod( _ arg1: String, _ arg2: Int)", params: arg1, arg2)
                }

                func variadicMethod(_ args: ArgumentMatcher<[Int]>) -> ReturnBuilder<Service, Void> {
                    ReturnBuilder<Service, Void>(mock: mock, signature: "variadicMethod(_ args: Int...)", params: args)
                }
            }
            #endif

            #if DEBUG
            nonisolated struct ServiceVerifier {
                let mock: Smock<Service>

                init(mock: Smock<Service>) {
                    self.mock = mock
                }

                var readWriteProperty: WritablePropertyVerifier<Service, String> {
                WritablePropertyVerifier<Service, String>(mock: mock, signature: "readWriteProperty")
                }

                var readOnlyProperty: PropertyVerifier<Service, String> {
                    PropertyVerifier<Service, String>(mock: mock, signature: "readOnlyProperty")
                }

                var asyncProperty: PropertyVerifier<Service, Int> {
                    PropertyVerifier<Service, Int>(mock: mock, signature: "asyncProperty")
                }

                var throwingProperty: PropertyVerifier<Service, String> {
                    PropertyVerifier<Service, String>(mock: mock, signature: "throwingProperty")
                }

                var asyncThrowingProperty: PropertyVerifier<Service, String> {
                    PropertyVerifier<Service, String>(mock: mock, signature: "asyncThrowingProperty")
                }

                func voidMethod() -> MethodVerifier<Service, Void> {
                    MethodVerifier<Service, Void>(mock: mock, signature: "voidMethod()")
                }

                func returningMethod() -> MethodVerifier<Service, Int> {
                    MethodVerifier<Service, Int>(mock: mock, signature: "returningMethod() -> Int")
                }

                func optionalMethod() -> MethodVerifier<Service, Int?> {
                    MethodVerifier<Service, Int?>(mock: mock, signature: "optionalMethod() -> Int?")
                }

                func throwingMethod() -> MethodVerifier<Service, Void> {
                    MethodVerifier<Service, Void>(mock: mock, signature: "throwingMethod() throws")
                }

                func asyncThrowingMethod() -> MethodVerifier<Service, Void> {
                    MethodVerifier<Service, Void>(mock: mock, signature: "asyncThrowingMethod() async throws")
                }

                func twoArgMethod(_ arg1: ArgumentMatcher<String>, _ arg2: ArgumentMatcher<Int>) -> MethodVerifier<Service, Void> {
                    MethodVerifier<Service, Void>(mock: mock, signature: "twoArgMethod( _ arg1: String, _ arg2: Int)", params: arg1, arg2)
                }

                func variadicMethod(_ args: ArgumentMatcher<[Int]>) -> MethodVerifier<Service, Void> {
                    MethodVerifier<Service, Void>(mock: mock, signature: "variadicMethod(_ args: Int...)", params: args)
                }
            }
            #endif

            #if DEBUG
            func when(_ mock: Smock<Service>) -> ServiceStubBuilder {
                ServiceStubBuilder(mock: mock)
            }
            #endif

            #if DEBUG
            func verify(_ mock: Smock<Service>) -> ServiceVerifier {
                ServiceVerifier(mock: mock)
            }
            #endif
            """,
            macros: testMacros
        )
    }
}
