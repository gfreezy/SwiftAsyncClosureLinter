import Foundation
import SwiftParser
import SwiftSyntax

/// Represents a lint violation
public struct Violation: Equatable, CustomStringConvertible {
    public let filePath: String
    public let line: Int
    public let column: Int
    public let variableName: String
    public let message: String

    public init(
        filePath: String, line: Int, column: Int, variableName: String, contextName: String = "SwiftUI View"
    ) {
        self.filePath = filePath
        self.line = line
        self.column = column
        self.variableName = variableName
        self.message =
            "Async closure property '\(variableName)' in \(contextName) should have @MainActor attribute"
    }

    public var description: String {
        "\(filePath):\(line):\(column): warning: \(message)"
    }
}

/// Lints Swift source code for async closure properties without @MainActor in SwiftUI Views
public final class AsyncClosureLinter {

    public init() {}

    /// Regex to match struct conforming to View: `struct XXX: View` or `struct XXX: SomeProtocol, View`
    private static let viewStructRegex = try! NSRegularExpression(
        pattern: #"struct\s+\w+\s*:\s*[^{]*\bView\b"#,
        options: []
    )

    /// Regex to match @Observable class
    private static let observableClassRegex = try! NSRegularExpression(
        pattern: #"@Observable\s+(final\s+)?class\s+\w+"#,
        options: []
    )

    /// Quick check if source might contain relevant code (View struct / @Observable class + async)
    /// Returns false if we can skip parsing entirely
    private func mightContainViolation(_ source: String) -> Bool {
        // Must have async keyword
        guard source.contains("async") else {
            return false
        }
        let range = NSRange(source.startIndex..., in: source)
        // Check for a struct conforming to View
        if Self.viewStructRegex.firstMatch(in: source, options: [], range: range) != nil {
            return true
        }
        // Check for @Observable class
        if Self.observableClassRegex.firstMatch(in: source, options: [], range: range) != nil {
            return true
        }
        return false
    }

    /// Lint a Swift source string
    public func lint(source: String, filePath: String = "<source>") -> [Violation] {
        guard mightContainViolation(source) else {
            return []
        }
        let sourceFile = Parser.parse(source: source)
        let visitor = AsyncClosureVisitor(filePath: filePath, source: source)
        visitor.walk(sourceFile)
        return visitor.violations
    }

    /// Lint a Swift file at the given path
    public func lintFile(at path: String) throws -> [Violation] {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        return lint(source: source, filePath: path)
    }

    /// Lint all Swift files in a directory recursively
    public func lintDirectory(at path: String) throws -> [Violation] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: path)
        var allViolations: [Violation] = []

        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") {
                let fullPath = (path as NSString).appendingPathComponent(file)
                let violations = try lintFile(at: fullPath)
                allViolations.append(contentsOf: violations)
            }
        }

        return allViolations
    }
}

final class AsyncClosureVisitor: SyntaxVisitor {
    let filePath: String
    let source: String
    private(set) var violations: [Violation] = []

    /// Stack to track nested types - each entry indicates if that type should be linted
    private var typeStack: [(name: String, shouldLint: Bool, contextName: String)] = []

    /// Returns true if the current (innermost) type should be linted
    private var shouldLintCurrentType: Bool {
        typeStack.last?.shouldLint ?? false
    }

    /// Returns the context name for the current type (for violation messages)
    private var currentContextName: String {
        typeStack.last?.contextName ?? "SwiftUI View"
    }

    init(filePath: String, source: String) {
        self.filePath = filePath
        self.source = source
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let isView = conformsToView(node)
        typeStack.append((name: node.name.text, shouldLint: isView, contextName: "SwiftUI View"))
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        if let last = typeStack.last, last.name == node.name.text {
            typeStack.removeLast()
        }
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let isObservable = hasObservableAttribute(node)
        typeStack.append(
            (name: node.name.text, shouldLint: isObservable, contextName: "@Observable class"))
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        if let last = typeStack.last, last.name == node.name.text {
            typeStack.removeLast()
        }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard shouldLintCurrentType else { return .visitChildren }

        for binding in node.bindings {
            if let typeAnnotation = binding.typeAnnotation {
                checkAsyncClosureType(
                    type: typeAnnotation.type,
                    variableName: binding.pattern.description.trimmingCharacters(in: .whitespaces),
                    location: node.positionAfterSkippingLeadingTrivia
                )
            }
        }

        return .visitChildren
    }

    /// Check if a class has @Observable attribute
    private func hasObservableAttribute(_ node: ClassDeclSyntax) -> Bool {
        node.attributes.contains { attr in
            if case let .attribute(attribute) = attr {
                return attribute.attributeName.description.trimmingCharacters(in: .whitespaces)
                    == "Observable"
            }
            return false
        }
    }

    /// Check if a struct conforms to View protocol
    private func conformsToView(_ node: StructDeclSyntax) -> Bool {
        guard let inheritanceClause = node.inheritanceClause else {
            return false
        }

        for inheritedType in inheritanceClause.inheritedTypes {
            let typeName = inheritedType.type.description.trimmingCharacters(in: .whitespaces)
            if typeName == "View" {
                return true
            }
        }

        return false
    }

    /// Check if a type is an async closure without @MainActor
    private func checkAsyncClosureType(type: TypeSyntax, variableName: String, location: AbsolutePosition)
    {
        // Handle Optional types: Type? or Optional<Type>
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            checkAsyncClosureType(
                type: optionalType.wrappedType,
                variableName: variableName,
                location: location
            )
            return
        }

        // Handle implicitly unwrapped optional: Type!
        if let implicitOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            checkAsyncClosureType(
                type: implicitOptional.wrappedType,
                variableName: variableName,
                location: location
            )
            return
        }

        // Handle tuple types with single element (parenthesized)
        if let tupleType = type.as(TupleTypeSyntax.self),
            tupleType.elements.count == 1,
            let firstElement = tupleType.elements.first
        {
            checkAsyncClosureType(
                type: firstElement.type,
                variableName: variableName,
                location: location
            )
            return
        }

        // Handle function types
        if let functionType = type.as(FunctionTypeSyntax.self) {
            if isAsyncClosure(functionType) && !hasMainActorAttribute(functionType) {
                reportViolation(variableName: variableName, location: location)
            }
            return
        }

        // Handle attributed types (e.g., @MainActor () async -> Void)
        if let attributedType = type.as(AttributedTypeSyntax.self) {
            // Check if the underlying type is a function type
            if let functionType = attributedType.baseType.as(FunctionTypeSyntax.self) {
                if isAsyncClosure(functionType) {
                    // Check if @MainActor is among the attributes
                    let hasMainActor = attributedType.attributes.contains { attr in
                        if case let .attribute(attribute) = attr {
                            return attribute.attributeName.description.trimmingCharacters(
                                in: .whitespaces) == "MainActor"
                        }
                        return false
                    }
                    if !hasMainActor {
                        reportViolation(variableName: variableName, location: location)
                    }
                }
            }
            return
        }
    }

    /// Check if a function type is async
    private func isAsyncClosure(_ functionType: FunctionTypeSyntax) -> Bool {
        return functionType.effectSpecifiers?.asyncSpecifier != nil
    }

    /// Check if a function type has @MainActor attribute (for attributed function types)
    private func hasMainActorAttribute(_ functionType: FunctionTypeSyntax) -> Bool {
        // Function types themselves don't have attributes in SwiftSyntax
        // The attribute would be on the AttributedTypeSyntax wrapping it
        return false
    }

    private func reportViolation(variableName: String, location: AbsolutePosition) {
        let lineColumn = lineAndColumn(for: location)
        let violation = Violation(
            filePath: filePath,
            line: lineColumn.line,
            column: lineColumn.column,
            variableName: variableName,
            contextName: currentContextName
        )
        violations.append(violation)
    }

    private func lineAndColumn(for position: AbsolutePosition) -> (line: Int, column: Int) {
        var line = 1
        var column = 1
        let offset = position.utf8Offset

        for (index, char) in source.utf8.enumerated() {
            if index >= offset {
                break
            }
            if char == UInt8(ascii: "\n") {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return (line, column)
    }
}
