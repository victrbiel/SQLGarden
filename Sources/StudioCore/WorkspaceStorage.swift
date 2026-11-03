import Foundation

public struct Draft: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var sql: String
    public var filePath: String?
    public var savedText: String?
    public var selectionLocation: Int
    public var selectionLength: Int
    public init(id: UUID, title: String, sql: String, filePath: String?, savedText: String?, selection: NSRange) {
        self.id = id; self.title = title; self.sql = sql; self.filePath = filePath; self.savedText = savedText
        selectionLocation = selection.location; selectionLength = selection.length
    }
    public var selection: NSRange {
        let length = (sql as NSString).length
        let start = min(max(0, selectionLocation), length)
        return NSRange(location: start, length: min(max(0, selectionLength), length - start))
    }
}
public enum ExecutionOutcome: String, Codable, CaseIterable {
    case success, failure, canceled
    public var title: String {
        switch self { case .success: return "Sucesso"; case .failure: return "Erro"; case .canceled: return "Cancelada" }
    }
}
public struct HistoryEntry: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let sql: String
    public let server: String
    public let database: String
    public let elapsed: TimeInterval
    public let outcome: ExecutionOutcome
    public init(sql: String, server: String, database: String, elapsed: TimeInterval, outcome: ExecutionOutcome, date: Date = Date()) {
        id = UUID(); self.date = date; self.sql = sql; self.server = server; self.database = database
        self.elapsed = elapsed; self.outcome = outcome
    }
    public func matches(_ search: String) -> Bool {
        search.isEmpty || [sql, server, database, outcome.title, date.formatted(date: .numeric, time: .shortened)]
            .contains { $0.localizedCaseInsensitiveContains(search) }
    }
    public static func bounded(_ entries: [HistoryEntry]) -> [HistoryEntry] {
        var bytes = 0
        return Array(entries.prefix(500).prefix { entry in
            bytes += entry.sql.utf8.count + entry.server.utf8.count + entry.database.utf8.count + 256
            return bytes <= 8 * 1024 * 1024
        })
    }
}
public struct WorkspaceSnapshot: Codable {
    public var version = 1
    public var drafts: [Draft] = []
    public var activeID: UUID?
    public var historyEnabled = true
    public var history: [HistoryEntry] = []
    public init() {}
}
/// Atomic, owner-only files. A backup is retained for truncated/corrupt primary recovery.
public final class WorkspaceStorage {
    public let directory: URL
    private var primary: URL { directory.appendingPathComponent("workspace-v1.json") }
    private var backup: URL { directory.appendingPathComponent("workspace-v1.backup.json") }
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> (WorkspaceSnapshot?, Bool) {
        guard FileManager.default.fileExists(atPath: primary.path) || FileManager.default.fileExists(atPath: backup.path) else { return (nil, false) }
        if let snapshot = try? decode(primary) { return (snapshot, false) }
        return (try decode(backup), true)
    }
    private func decode(_ url: URL) throws -> WorkspaceSnapshot {
        let result = try JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(contentsOf: url))
        guard result.version == 1, Set(result.drafts.map(\.id)).count == result.drafts.count else {
            throw StudioError.message("Formato de recuperação inválido.")
        }
        return result
    }
    public func save(_ snapshot: WorkspaceSnapshot) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(snapshot)
        // Never replace a usable backup with a broken primary.
        if (try? decode(primary)) != nil {
            try Data(contentsOf: primary).write(to: backup, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try data.write(to: primary, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: primary.path)
    }
    /// Clear history in both generations: an older backup must not resurrect it.
    public func eraseHistory(_ snapshot: WorkspaceSnapshot) throws {
        var clean = snapshot; clean.history = []
        try save(clean)
        try JSONEncoder().encode(clean).write(to: backup, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
    }
}

public enum DiagnosticCode: String, Codable {
    case appStarted, connectionSucceeded, connectionFailed, disconnected
    case querySucceeded, queryFailed, cancelRequested, queryCanceled
    case metadataFailed, sessionStateUnavailable, recoveryLoaded, recoveryFailed, storageFailed
}
public enum DiagnosticSQLState: String, Codable {
    case syntax = "42000", integrity = "23000", connection = "08001", transport = "08S01"
    case authentication = "28000", timeout = "HYT00", loginTimeout = "HYT01", canceled = "HY008"
    case general = "HY000", cursor = "24000", connectionClosed = "08003", warning = "01000"
    public static func extract(from message: String) -> [DiagnosticSQLState] {
        let regex = try! NSRegularExpression(pattern: #"(?m)^\[([A-Z0-9]{5})\]"#)
        let ns = message as NSString
        var states: [DiagnosticSQLState] = []
        for match in regex.matches(in: message, range: NSRange(location: 0, length: ns.length)) {
            if let value = DiagnosticSQLState(rawValue: ns.substring(with: match.range(at: 1))), !states.contains(value) { states.append(value) }
        }
        return states
    }
}
public struct DiagnosticEvent: Codable {
    public let date: Date
    public let code: DiagnosticCode
    public let states: [DiagnosticSQLState]
    public init(_ code: DiagnosticCode, date: Date = Date(), states: [DiagnosticSQLState] = []) { self.code = code; self.date = date; self.states = states }
}
public enum SupportReport {
    public static let recipient = "sqlgarden@publicvictor.com"
    public static func diagnostic(version: String, system: String, architecture: String, missing: [String], events: [DiagnosticEvent]) -> String {
        let records = events.suffix(100).map { "\(ISO8601DateFormatter().string(from: $0.date)) \($0.code.rawValue)" + ($0.states.isEmpty ? "" : " SQLSTATE=" + $0.states.map(\.rawValue).joined(separator: ",")) }.joined(separator: "\n")
        return """
        Diagnóstico técnico opcional
        SQLGarden: \(version)
        macOS: \(system)
        Arquitetura do processo: \(architecture)
        Dependências ausentes: \(missing.isEmpty ? "nenhuma" : missing.joined(separator: ", "))
        Eventos desta abertura (até 100):
        \(records)

        Não inclui consultas, resultados, credenciais, servidores, bancos,
        caminhos pessoais ou mensagens brutas do driver. Eventos não são um crash dump.
        """
    }
    public static func compose(kind: String, description: String, steps: String, diagnostic: String?) -> String {
        """
        SQLGarden — \(kind)
        Destinatário: \(recipient)

        Descrição:
        \(description)

        Passos para reproduzir / comportamento esperado:
        \(steps)
        """ + (diagnostic.map { "\n\n" + $0 } ?? "")
    }
}
