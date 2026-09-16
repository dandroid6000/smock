import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct SmockPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MockableMacro.self
    ]
}

//public struct MockMacro: ExpressionMacro {
//    public static func expansion(
//        of node: some FreestandingMacroExpansionSyntax,
//        in context: some MacroExpansionContext
//    ) -> ExprSyntax {
//        guard let argument = node.arguments.first?.expression else {
//            fatalError("compiler bug: the macro does not have any arguments")
//        }
//
//        guard let protocolName = argument.description.split(separator: ".").first else {
//            fatalError("compiler bug: unexpected argument")
//        }
//
//        let expansionString = """
//        {
//            #if canImport(SmockTestSupport)
//            SmockTestSupport.initialize()
//            #endif
//            return \(protocolName)Mock()
//        }()
//        """
//
//        return ExprSyntax(stringLiteral: expansionString)
//    }
//}

enum SmockError: Swift.Error {
    case notAProtocol
//    case notAProperty
}

//public struct MockMacro: AccessorMacro {
//    public static func expansion(
//        of node: AttributeSyntax,
//        providingAccessorsOf declaration: some DeclSyntaxProtocol,
//        in context: some MacroExpansionContext
//    ) throws -> [AccessorDeclSyntax] {
//        // Ensure the macro is attached to a variable property
//        guard let variable = declaration.as(VariableDeclSyntax.self),
//              let identifier = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)
//        else {
//            throw SmockError.notAProperty
//        }
//
//
//    }
//}

public struct MockableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Ensure we are attached to a protocol
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw SmockError.notAProtocol
        }

        let protocolName = protocolDecl.name.text

        // Enumerate the methods and properties
        var mocks: [String] = []
        var stubbers: [String] = []
        var verifiers: [String] = []
        for member in protocolDecl.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self) {
                let impl = mockMethod(function)
                mocks.append(impl)

                let stub: String = stubMethod(function, protocolName: protocolName)
                stubbers.append(stub)

                let verifier: String = verifyMethod(function, protocolName: protocolName)
                verifiers.append(verifier)
            } else if let property = member.decl.as(VariableDeclSyntax.self) {
                let impl = mockProperty(property)
                mocks.append(impl)

                let stub: String = stubProperty(property, protocolName: protocolName)
                stubbers.append(stub)

                let verifier: String = verifyProperty(property, protocolName: protocolName)
                verifiers.append(verifier)
            }
        }

        let mockClassName = "\(protocolName)Mock"
        let mockClassImpl = """
        #if DEBUG
        final nonisolated class \(mockClassName): Smock<\(protocolName)>, \(protocolName), @unchecked Sendable {
            required public init(relaxed: Bool = false) {
                super.init(relaxed: relaxed)
            }
                
            \(mocks.joined(separator: "\n\n"))
        }
        #endif
        """

        let stubberClassName = "\(protocolName)StubBuilder"
        let stubberImpl = """
        #if DEBUG
        nonisolated struct \(stubberClassName) {
            let mock: Smock<\(protocolName)>
            
            init(mock: Smock<\(protocolName)>) {
                self.mock = mock
            }
                
            \(stubbers.joined(separator: "\n\n"))
        }
        #endif
        """

        let verifierClassName = "\(protocolName)Verifier"
        let verifierImpl = """
        #if DEBUG
        nonisolated struct \(verifierClassName) {
            let mock: Smock<\(protocolName)>
            
            init(mock: Smock<\(protocolName)>) {
                self.mock = mock
            }
        
            \(verifiers.joined(separator: "\n\n"))
        }
        #endif
        """

        let whenFunction = """
        #if DEBUG
        func when(_ mock: Smock<\(protocolName)>) -> \(stubberClassName) {
            \(stubberClassName)(mock: mock)
        }
        #endif
        """

        let verifyFunction = """
        #if DEBUG
        func verify(_ mock: Smock<\(protocolName)>) -> \(verifierClassName) {
            \(verifierClassName)(mock: mock)
        }
        #endif
        """

        return [
            DeclSyntax(stringLiteral: mockClassImpl),
            DeclSyntax(stringLiteral: stubberImpl),
            DeclSyntax(stringLiteral: verifierImpl),
            DeclSyntax(stringLiteral: whenFunction),
            DeclSyntax(stringLiteral: verifyFunction)
        ]
    }

    // MARK: Mock members

    private static func mockMethod(_ function: FunctionDeclSyntax) -> String {
        // Extract function details
        let isThrowing = function.signature.effectSpecifiers?.throwsClause != nil
        let tryKeyword = isThrowing ? "try" : "try!"

        let isAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let awaitKeyword = isAsync ? " await" : ""

        let parameters = function.signature.parameterClause.parameters
        let paramNames = parameters.map { parameter in
            parameter.secondName?.text ?? parameter.firstName.text
        }
        let paramValues = if paramNames.isEmpty {
            ""
        } else {
            ", params: \(paramNames.joined(separator: ", "))"
        }

        let signature = function.memberSignature // no line breaks
        return """
        nonisolated func \(signature) {
            trackMethod("\(signature)"\(paramValues))
            return \(tryKeyword)\(awaitKeyword) getValue(for: "\(signature)"\(paramValues))
        }
        """
    }

    private static func mockProperty(_ property: VariableDeclSyntax) -> String {
        // Extract bindings (e.g., var id: String)
        guard
            let binding = property.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let type = binding.typeAnnotation?.type.description.trimmingWhitespaceByRegex()
        else {
            return ""
        }

        var isThrowing = false
        var isAsync = false
        var getClause = "get"
        var setClause: String?
        if case let .accessors(accessors) = binding.accessorBlock?.accessors {
            // Pull full accessors, e.g.: "get async throws "
            if let getter = accessors.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) }) {
                isThrowing = getter.effectSpecifiers?.throwsClause != nil
                isAsync = getter.effectSpecifiers?.asyncSpecifier != nil
                getClause = getter.description.trimmingWhitespaceByRegex()
            }
            if let setter = accessors.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.set) }) {
                setClause = setter.description.trimmingWhitespaceByRegex()
            }
        }

        let tryKeyword = isThrowing ? "try" : "try!"
        let awaitKeyword = isAsync ? " await" : ""

        let getter = """
            \(getClause) {
                trackGetter("\(identifier)")
                return \(tryKeyword)\(awaitKeyword) getValue(for: "\(identifier)")
            }
        """

        let setter = if let setClause {
            """
            
                \(setClause) {
                    trackSetter("\(identifier)", value: newValue)
                }
            """
        } else {
            ""
        }

        return """
        nonisolated var \(identifier): \(type) {
        \(getter)\(setter)
        }
        """
    }

    // MARK: Stubber members

    private static func stubMethod(_ function: FunctionDeclSyntax, protocolName: String) -> String {
        let name = function.name.text
        let parameters = function.signature.parameterClause.parameters
        let returnType = function.signature.returnClause?.type.description.trimmingWhitespaceByRegex() ?? "Void"

        let paramMatchers: String = parameters
            .map {
                let secondName = if let name = $0.secondName { " \(name.text)" } else { "" }
                var type = $0.type.description.trimmingWhitespaceByRegex()
                // Stub varargs as arrays
                if $0.ellipsis != nil {
                    type = "[\(type)]"
                }
                return "\($0.firstName.text)\(secondName): ArgumentMatcher<\(type)>"
            }
            .joined(separator: ", ")

        // Pass parameters if present
        let paramNames = parameters.map { parameter in
            parameter.secondName?.text ?? parameter.firstName.text
        }
        let paramCapture = if paramNames.isEmpty { "" } else {
            ", params: \(paramNames.joined(separator: ", "))"
        }

        // Determine builder type (e.g. async/throwing)
        var builderType = "ReturnBuilder<\(protocolName), \(returnType)>"
        if function.signature.effectSpecifiers?.throwsClause != nil {
            builderType = "Throwing" + builderType
        }
        if function.signature.effectSpecifiers?.asyncSpecifier != nil {
            builderType = "Async" + builderType
        }

        return """
        func \(name)(\(paramMatchers)) -> \(builderType) {
            \(builderType)(mock: mock, signature: "\(function.memberSignature)"\(paramCapture))
        }
        """
    }

    private static func stubProperty(_ property: VariableDeclSyntax, protocolName: String) -> String {
        guard
            let binding = property.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let type = binding.typeAnnotation?.type.description.trimmingWhitespaceByRegex()
        else {
            return ""
        }

        // Determine builder type (e.g. async/throwing)
        var builderType = "ReturnBuilder<\(protocolName), \(type)>"
        if case let .accessors(accessors) = binding.accessorBlock?.accessors,
            let getter = accessors.first(where: {$0.accessorSpecifier.tokenKind == .keyword(.get)}) {

            if getter.effectSpecifiers?.throwsClause != nil {
                builderType = "Throwing" + builderType
            }
            if getter.effectSpecifiers?.asyncSpecifier != nil {
                builderType = "Async" + builderType
            }
        }

        return """
        var \(identifier): \(builderType) {
            \(builderType)(mock: mock, signature: "\(identifier)")
        }
        """
    }

    // MARK: Verifier members

    private static func verifyMethod(_ function: FunctionDeclSyntax, protocolName: String) -> String {
        let name = function.name.text
        let parameters = function.signature.parameterClause.parameters
        let returnType = function.signature.returnClause?.type.description.trimmingWhitespaceByRegex() ?? "Void"

        let paramMatchers: String = parameters
            .map {
                let secondName = if let name = $0.secondName { " \(name.text)" } else { "" }
                var type = $0.type.description.trimmingWhitespaceByRegex()
                // Stub varargs as arrays
                if $0.ellipsis != nil {
                    type = "[\(type)]"
                }
                return "\($0.firstName.text)\(secondName): ArgumentMatcher<\(type)>"
            }
            .joined(separator: ", ")

        // Pass parameters if present
        let paramNames = parameters.map { parameter in
            parameter.secondName?.text ?? parameter.firstName.text
        }
        let paramCapture = if paramNames.isEmpty { "" } else {
            ", params: \(paramNames.joined(separator: ", "))"
        }

        return """
        func \(name)(\(paramMatchers)) -> MethodVerifier<\(protocolName), \(returnType)> {
            MethodVerifier<\(protocolName), \(returnType)>(mock: mock, signature: "\(function.memberSignature)"\(paramCapture))
        }
        """
    }

    private static func verifyProperty(_ property: VariableDeclSyntax, protocolName: String) -> String {
        guard
            let binding = property.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            let type = binding.typeAnnotation?.type.description.trimmingWhitespaceByRegex()
        else {
            return ""
        }

        let isWritable = if case let .accessors(accessors) = binding.accessorBlock?.accessors {
            accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
        } else {
            false
        }

        // Determine builder type (i.e. throwing)
        let verifierType = if isWritable {
            "WritablePropertyVerifier<\(protocolName), \(type)>"
        } else {
            "PropertyVerifier<\(protocolName), \(type)>"
        }

        return """
        var \(identifier): \(verifierType) {
            \(verifierType)(mock: mock, signature: "\(identifier)")
        }
        """
    }
}

// MARK: - Conveniences

private extension FunctionDeclSyntax {
    var memberSignature: String {
        self.with(\.funcKeyword, "").signatureDescription(removeLineBreaks: true)
    }
}
