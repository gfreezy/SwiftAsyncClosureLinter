import XCTest

@testable import AsyncClosureLinterCore

final class AsyncClosureLinterTests: XCTestCase {

    let linter = AsyncClosureLinter()

    // MARK: - Should Trigger Violations

    func testAsyncClosureWithoutMainActor() {
        let source = """
            struct MyView: View {
                var onTap: () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onTap")
    }

    func testOptionalAsyncClosureWithoutMainActor() {
        let source = """
            struct MyView: View {
                var onAction: (() async -> Void)?
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onAction")
    }

    func testImplicitlyUnwrappedOptionalAsyncClosure() {
        let source = """
            struct MyView: View {
                var onSubmit: (() async -> Void)!
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onSubmit")
    }

    func testAsyncThrowsClosureWithoutMainActor() {
        let source = """
            struct MyView: View {
                var onLoad: () async throws -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onLoad")
    }

    func testOptionalAsyncThrowsClosureWithoutMainActor() {
        let source = """
            struct MyView: View {
                var onRefresh: (() async throws -> Void)?
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onRefresh")
    }

    func testMultipleAsyncClosuresWithoutMainActor() {
        let source = """
            struct MyView: View {
                var onLoad: () async -> Void
                var onRefresh: (() async throws -> Void)?
                var onSubmit: () async -> String
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 3)

        let names = violations.map { $0.variableName }
        XCTAssertTrue(names.contains("onLoad"))
        XCTAssertTrue(names.contains("onRefresh"))
        XCTAssertTrue(names.contains("onSubmit"))
    }

    func testAsyncClosureWithParameters() {
        let source = """
            struct MyView: View {
                var onSelect: (Int, String) async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onSelect")
    }

    func testAsyncClosureWithReturnType() {
        let source = """
            struct MyView: View {
                var fetchData: () async -> [String]
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "fetchData")
    }

    // MARK: - Should NOT Trigger Violations

    func testAsyncClosureWithMainActor() {
        let source = """
            struct MyView: View {
                var onTap: @MainActor () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testOptionalAsyncClosureWithMainActor() {
        let source = """
            struct MyView: View {
                var onAction: (@MainActor () async -> Void)?
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testAsyncThrowsClosureWithMainActor() {
        let source = """
            struct MyView: View {
                var onSubmit: @MainActor () async throws -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testNonAsyncClosure() {
        let source = """
            struct MyView: View {
                var onTap: () -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testOptionalNonAsyncClosure() {
        let source = """
            struct MyView: View {
                var onAction: (() -> Void)?
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testNonClosureProperty() {
        let source = """
            struct MyView: View {
                var title: String
                var count: Int
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testNonViewStruct() {
        let source = """
            struct NotAView {
                var onTap: () async -> Void
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testClassWithAsyncClosure() {
        let source = """
            class SomeClass {
                var onTap: () async -> Void = {}
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testNestedStructInView() {
        let source = """
            struct MyView: View {
                struct Inner {
                    var onTap: () async -> Void
                }
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        // Inner is not a View, so should not trigger
        XCTAssertEqual(violations.count, 0)
    }

    func testNestedViewInView() {
        let source = """
            struct OuterView: View {
                struct InnerView: View {
                    var onTap: () async -> Void
                    var body: some View { Text("") }
                }
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        // InnerView is a View, so should trigger
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onTap")
    }

    // MARK: - Edge Cases

    func testSendableClosure() {
        let source = """
            struct MyView: View {
                var onTap: @Sendable () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        // @Sendable is not @MainActor, should still trigger
        XCTAssertEqual(violations.count, 1)
    }

    func testMainActorAndSendableClosure() {
        let source = """
            struct MyView: View {
                var onTap: @MainActor @Sendable () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testLetProperty() {
        let source = """
            struct MyView: View {
                let onTap: () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.variableName, "onTap")
    }

    func testComputedProperty() {
        let source = """
            struct MyView: View {
                var onTap: () async -> Void {
                    return {}
                }
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        // Computed properties should also be checked
        XCTAssertEqual(violations.count, 1)
    }

    func testEscapingClosure() {
        let source = """
            struct MyView: View {
                var onTap: @escaping () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        // @escaping without @MainActor should trigger
        XCTAssertEqual(violations.count, 1)
    }

    // MARK: - Violation Details

    func testViolationLineNumber() {
        let source = """
            import SwiftUI

            struct MyView: View {
                var title: String
                var onTap: () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.line, 5)
    }

    func testViolationDescription() {
        let source = """
            struct MyView: View {
                var onTap: () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source, filePath: "TestFile.swift")
        XCTAssertEqual(violations.count, 1)

        let description = violations.first?.description ?? ""
        XCTAssertTrue(description.contains("TestFile.swift"))
        XCTAssertTrue(description.contains("onTap"))
        XCTAssertTrue(description.contains("@MainActor"))
    }

    // MARK: - Multiple Views

    func testMultipleViews() {
        let source = """
            struct ViewA: View {
                var onTapA: () async -> Void
                var body: some View { Text("") }
            }

            struct ViewB: View {
                var onTapB: @MainActor () async -> Void
                var body: some View { Text("") }
            }

            struct ViewC: View {
                var onTapC: () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 2)

        let names = violations.map { $0.variableName }
        XCTAssertTrue(names.contains("onTapA"))
        XCTAssertTrue(names.contains("onTapC"))
        XCTAssertFalse(names.contains("onTapB"))
    }

    // MARK: - Quick Filter Optimization

    func testSkipsFileWithoutView() {
        let source = """
            struct NotAModel {
                var onTap: () async -> Void
            }
            class DataManager {
                var onLoad: () async -> Void = {}
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testSkipsFileWithoutAsync() {
        let source = """
            struct MyView: View {
                var onTap: () -> Void
                var title: String
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 0)
    }

    func testHandlesViewWithNoSpace() {
        // ":View" without space should also work
        let source = """
            struct MyView:View {
                var onTap: () async -> Void
                var body: some View { Text("") }
            }
            """

        let violations = linter.lint(source: source)
        XCTAssertEqual(violations.count, 1)
    }
}
