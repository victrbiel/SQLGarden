import XCTest
@testable import StudioCore

final class StudioCoreTests: XCTestCase {
    func testGOSeparatesProcedureBatchesAndRepetitions() throws {
        let batches = try BatchParser.split("SELECT 1;\r\nGO\r\nCREATE PROCEDURE p AS SELECT 2;\r\nGO 2 -- repetir\r\nEXEC p;")
        XCTAssertEqual(batches.count, 3)
        XCTAssertEqual(batches.map(\.repetitions), [1, 2, 1])
        XCTAssertEqual(batches.map(\.startLine), [1, 3, 5])
        XCTAssertTrue(batches[1].sql.hasPrefix("CREATE PROCEDURE"))
    }
    func testGOInsideStringsIdentifiersAndNestedComments() throws {
        let sql = """
        SELECT N'início
        GO
        fim', [nome
        GO
        x], "outra
        GO
        coluna";
        /* comentário /* interno */
        GO
        */
        GO
        SELECT 'a''b'; -- GO
        """
        let batches = try BatchParser.split(sql)
        XCTAssertEqual(batches.count, 2)
        XCTAssertTrue(batches[0].sql.contains("/* interno */"))
    }
    func testInvalidGOAndSQLCMDRejectedBeforeExecution() {
        for sql in ["SELECT 1\nGO 0", "GO 101", "GO abc", "GO 2 lixo", ":r arquivo.sql", "!! whoami"] {
            XCTAssertThrowsError(try BatchParser.split(sql), sql)
        }
    }
    func testEmptyBatchesAreIgnored() throws {
        XCTAssertEqual(try BatchParser.split("GO\n\nGO\n").count, 0)
    }
    func testUnclosedStringIsLeftForServerDiagnosis() throws {
        XCTAssertEqual(try BatchParser.split("SELECT 'texto\nGO\n").count, 1)
    }
    func testConnectionEscapesPasswordAndDoesNotDisableEncryption() throws {
        var profile = ConnectionProfile()
        profile.username = "aluno}nome"
        let connection = try profile.connectionString(password: "x};Database=outro;{")
        XCTAssertTrue(connection.contains("UID={aluno}}nome}"))
        XCTAssertTrue(connection.contains("PWD={x}};Database=outro;{}"))
        XCTAssertTrue(connection.contains("Encrypt=yes"))
        XCTAssertTrue(connection.contains("ConnectRetryCount=0"))
    }
    func testInvalidEndpointRejected() {
        var profile = ConnectionProfile(); profile.host = "localhost;UID=outro"
        XCTAssertThrowsError(try profile.connectionString(password: "x"))
        profile.host = "localhost"; profile.port = 70000
        XCTAssertThrowsError(try profile.connectionString(password: "x"))
    }
    func testIdentifierAndLiteralEscaping() {
        XCTAssertEqual(SQLText.identifier("a]b"), "[a]]b]")
        XCTAssertEqual(SQLText.literal("d'água"), "N'd''água'")
    }
    func testCSVPreservesCommaQuotesNewlineAndNull() throws {
        let payload = #"{"success":true,"messages":"","sets":[{"columns":["Nome","Valor"],"rows":[["a,\"b\"\nc",null]],"affectedRows":-1,"truncated":false}]}"#
        let table = try JSONDecoder().decode(SQLResponse.self, from: Data(payload.utf8)).tables[0]
        XCTAssertEqual(SQLText.csv(table), "\"Nome\",\"Valor\"\r\n\"a,\"\"b\"\"\nc\",\r\n")
    }
}
