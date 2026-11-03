import Foundation

public struct ConnectionProfile: Codable, Equatable, Sendable {
    public var name = "SQL Server local"
    public var host = "localhost"
    public var port = 1433
    public var username = "sa"
    public var database = "master"
    public var trustCertificate = true
    public var container = ""
    public var rowLimit = 1000
    public var timeout = 60
    public init() {}

    public func connectionString(password: String) throws -> String {
        guard ![host, username, database, password].contains(where: { $0.utf8.contains(0) }) else {
            throw StudioError.message("Os campos de conexão não podem conter NUL (U+0000).")
        }
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.contains(";"), !host.contains(","), !host.contains("\n"), !host.contains("\r"),
              (1...65535).contains(port), !username.isEmpty, !database.isEmpty else {
            throw StudioError.message("Confira servidor, porta, usuário e banco inicial.")
        }
        func value(_ text: String) -> String { "{" + text.replacingOccurrences(of: "}", with: "}}") + "}" }
        return "Driver={ODBC Driver 18 for SQL Server};Server=" + value("tcp:\(host),\(port)") +
            ";UID=" + value(username) + ";PWD=" + value(password) + ";Database=" + value(database) +
            ";Encrypt=yes;TrustServerCertificate=\(trustCertificate ? "yes" : "no");APP=SQLGarden;ConnectRetryCount=0;"
    }
    public var credentialKey: String { "\(host):\(port)/\(username)" }
}

public enum StudioError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public struct ResultSet: Decodable, Sendable, Identifiable {
    public var id: UUID = UUID()
    public var columns: [String]
    public var rows: [[String?]]
    public var affectedRows: Int64
    public var truncated: Bool
    enum CodingKeys: String, CodingKey { case columns, rows, affectedRows, truncated }
}

public struct SQLResponse: Decodable, Sendable {
    public var success: Bool
    public var messages: String
    public var sets: [ResultSet]
    public init(success: Bool = true, messages: String = "", sets: [ResultSet] = []) {
        self.success = success; self.messages = messages; self.sets = sets
    }
    public var tables: [ResultSet] { sets.filter { !$0.columns.isEmpty } }
}

public enum SQLText {
    public static func identifier(_ value: String) -> String {
        "[" + value.replacingOccurrences(of: "]", with: "]]") + "]"
    }
    public static func literal(_ value: String) -> String {
        "N'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }
    public static func csv(_ table: ResultSet) -> String {
        func escaped(_ cell: String) -> String { "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return ([table.columns.map(escaped).joined(separator: ",")] + table.rows.map {
            $0.map { $0.map(escaped) ?? "" }.joined(separator: ",")
        }).joined(separator: "\r\n") + "\r\n"
    }
}
