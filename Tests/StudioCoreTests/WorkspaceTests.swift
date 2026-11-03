import XCTest
@testable import StudioCore

final class WorkspaceTests: XCTestCase {
    func temporaryStorage() throws -> WorkspaceStorage {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SQLGarden-unit-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return WorkspaceStorage(directory: directory)
    }
    func testRecoveryRoundTripPreservesUnicodeSelectionAndUnsavedText() throws {
        let storage = try temporaryStorage()
        var snapshot = WorkspaceSnapshot()
        let id = UUID()
        snapshot.drafts = [Draft(id: id, title: "não salvo", sql: "SELECT N'ação 🎓';\n", filePath: nil, savedText: nil, selection: NSRange(location: 10, length: 7))]
        snapshot.activeID = id
        try storage.save(snapshot)
        let (loaded, backup) = try storage.load()
        XCTAssertFalse(backup); XCTAssertEqual(loaded?.drafts, snapshot.drafts)
        XCTAssertEqual(loaded?.activeID, id)
        let attributes = try FileManager.default.attributesOfItem(atPath: storage.directory.appendingPathComponent("workspace-v1.json").path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testCorruptPrimaryFallsBackToValidGeneration() throws {
        let storage = try temporaryStorage(); var snapshot = WorkspaceSnapshot()
        snapshot.drafts = [Draft(id: UUID(), title: "a", sql: "SELECT 1", filePath: nil, savedText: nil, selection: NSRange())]
        try storage.save(snapshot); snapshot.drafts[0].sql = "SELECT 2"; try storage.save(snapshot)
        try Data("{partial".utf8).write(to: storage.directory.appendingPathComponent("workspace-v1.json"))
        let (loaded, fallback) = try storage.load()
        XCTAssertTrue(fallback); XCTAssertEqual(loaded?.drafts.first?.sql, "SELECT 1")
        try storage.save(snapshot)
        XCTAssertEqual(try storage.load().0?.drafts.first?.sql, "SELECT 2")
    }
    func testClearingHistoryCannotBeUndoneByBackupRecovery() throws {
        let storage = try temporaryStorage(); var snapshot = WorkspaceSnapshot()
        snapshot.history = [HistoryEntry(sql: "SELECT 'private'", server: "private-host", database: "class", elapsed: 0.5, outcome: .failure)]
        try storage.save(snapshot); try storage.save(snapshot)
        snapshot.historyEnabled = false; try storage.eraseHistory(snapshot)
        try Data("broken".utf8).write(to: storage.directory.appendingPathComponent("workspace-v1.json"))
        let result = try storage.load().0!
        XCTAssertFalse(result.historyEnabled); XCTAssertTrue(result.history.isEmpty)
    }
    func testHistorySearchAndRetention() {
        let entry = HistoryEntry(sql: "SELECT N'ação'", server: "localhost", database: "Biblioteca", elapsed: 1, outcome: .canceled)
        XCTAssertTrue(entry.matches("AÇÃO")); XCTAssertTrue(entry.matches("biblioteca")); XCTAssertTrue(entry.matches("cancelada"))
        XCTAssertFalse(entry.matches("missing"))
        XCTAssertEqual(HistoryEntry.bounded(Array(repeating: entry, count: 600)).count, 500)
        let large = HistoryEntry(sql: String(repeating: "a", count: 1024 * 1024), server: "s", database: "d", elapsed: 0, outcome: .success)
        XCTAssertEqual(HistoryEntry.bounded(Array(repeating: large, count: 20)).count, 7)
    }
    func testCommentAndIndentPreserveCRLFUnicodeAndExclusiveEnd() {
        let source = "  SELECT N'ação 🎓';\r\nSELECT 2;\r\n"
        let first = (source as NSString).range(of: "SELECT 2").location
        let comment = EditorTools.transform(source, selection: NSRange(location: 0, length: first), operation: .comment)
        XCTAssertEqual(comment.replacement, "  --SELECT N'ação 🎓';\r\n")
        let uncomment = EditorTools.transform(comment.replacement, selection: NSRange(location: 0, length: (comment.replacement as NSString).length), operation: .comment)
        XCTAssertEqual(uncomment.replacement, "  SELECT N'ação 🎓';\r\n")
        let indent = EditorTools.transform(source, selection: NSRange(location: first, length: 0), operation: .indent)
        XCTAssertEqual(indent.replacement, "    SELECT 2;\r\n")
        let unindent = EditorTools.transform(indent.replacement, selection: NSRange(), operation: .unindent)
        XCTAssertEqual(unindent.replacement, "SELECT 2;\r\n")
    }
    func testGoToLineUsesUTF16AndRejectsMissingLines() {
        XCTAssertEqual(EditorTools.location(ofLine: 2, in: "🎓\r\nx"), 4)
        XCTAssertNil(EditorTools.location(ofLine: 3, in: "a\nb"))
        XCTAssertEqual(EditorTools.location(ofLine: 3, in: "a\nb\n"), 4)
        XCTAssertNil(EditorTools.location(ofLine: 0, in: ""))
    }
    func testGridCopiesRectangleAndDistinguishesNullLiteralAndMultiline() {
        let text = GridTools.tsv(columns: ["A", "B", "C"], rows: [[nil, "NULL", "a\tb\n\"c\""], ["", "ação", "🎓"]],
            columnIndexes: IndexSet(integersIn: 0..<3), rowIndexes: IndexSet(integersIn: 0..<2), headers: true)
        XCTAssertEqual(text, "A\tB\tC\nNULL\t\"NULL\"\t\"a\tb\n\"\"c\"\"\"\n\tação\t🎓")
        XCTAssertEqual(GridTools.tsv(columns: ["A", "B"], rows: [["x", "y"]], columnIndexes: IndexSet(integer: 1), rowIndexes: IndexSet(integer: 0), headers: false), "y")
    }
    func testGridQuotesStandaloneNewlineCarriageReturnAndCRLF() {
        for value in ["a\nb", "a\rb", "a\r\nb"] {
            XCTAssertEqual(GridTools.tsv(columns: ["A"], rows: [[value]], columnIndexes: IndexSet(integer: 0), rowIndexes: IndexSet(integer: 0), headers: false), "\"" + value + "\"")
        }
    }
    func testDiagnosticSQLStatesAreAllowlistedAndMessagesNeverCopied() {
        let states = DiagnosticSQLState.extract(from: "[42000] private query and server\n[HY008] private database\n[ABCDE] must not survive\nnot a code [28000]")
        XCTAssertEqual(states, [.syntax, .canceled])
        let output = SupportReport.diagnostic(version: "0.3.0", system: "macOS", architecture: "arm64", missing: [], events: [DiagnosticEvent(.queryFailed, states: states)])
        XCTAssertTrue(output.contains("SQLSTATE=42000,HY008")); XCTAssertFalse(output.contains("private")); XCTAssertFalse(output.contains("ABCDE"))
    }
    func testDiagnosticReportOnlyIncludesAllowedTypedEvents() {
        let diagnostic = SupportReport.diagnostic(version: "0.3.0", system: "macOS", architecture: "arm64", missing: [], events: [DiagnosticEvent(.queryFailed)])
        XCTAssertTrue(diagnostic.contains("queryFailed"))
        XCTAssertFalse(diagnostic.contains("PWD=")); XCTAssertFalse(diagnostic.contains("SELECT"))
        let excluded = SupportReport.compose(kind: "Problema", description: "Falha ao abrir", steps: "Abrir", diagnostic: nil)
        XCTAssertFalse(excluded.contains("queryFailed"))
        XCTAssertTrue(excluded.contains("sqlgarden@publicvictor.com"))
    }
}
