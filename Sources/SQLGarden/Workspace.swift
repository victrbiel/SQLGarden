import AppKit
import SwiftUI
import StudioCore

struct QueryDocument: Identifiable {
    var id = UUID()
    var title: String
    var sql: String
    var selection = NSRange(location: 0, length: 0)
    var url: URL?
    var savedText: String?
    var response = SQLResponse()
    var elapsed: TimeInterval = 0
    var dirty: Bool { savedText.map { sql != $0 } ?? !sql.isEmpty }
}
struct DatabaseObject: Identifiable {
    let schema: String
    let name: String
    let kind: String
    var id: String { "\(kind).\(schema).\(name)" }
    var qualified: String { SQLText.identifier(schema) + "." + SQLText.identifier(name) }
    var icon: String {
        switch kind { case "U": return "tablecells"; case "V": return "eye"; case "P": return "function"; case "TR": return "bolt"; default: return "curlybraces" }
    }
}

@MainActor
final class Workspace: ObservableObject {
    @Published var profile: ConnectionProfile
    @Published var password = ""
    @Published var rememberPassword = true
    @Published var connected = false
    @Published var connecting = false
    @Published var executing = false
    @Published var loadingObjects = false
    @Published var connectionSheet = false
    @Published var dockerSheet = false
    @Published var error: String?
    @Published var databases: [String] = []
    @Published var database = "master"
    @Published var objects: [DatabaseObject] = []
    @Published var search = ""
    @Published var documents = [QueryDocument(title: "Consulta 1", sql: "-- Escreva seu T-SQL e pressione ⌘↩ para executar.\nSELECT @@VERSION AS Versao;\nGO\nSELECT DB_NAME() AS BancoAtual;\n")] { didSet { scheduleSave() } }
    @Published var activeID = UUID() { didSet { scheduleSave() } }
    @Published var resultTab = "results"
    @Published var history: [HistoryEntry] = []
    @Published var historyEnabled = true
    @Published var historySheet = false
    @Published var feedbackSheet = false
    @Published var storageNotice: String?
    @Published var sessionID: String?
    @Published var transactionCount: Int?
    @Published var transactionState: Int?
    @Published var sessionCheckedAt: Date?
    @Published var diagnosticEvents: [DiagnosticEvent] = []
    private var saveTask: DispatchWorkItem?
    private var readyToSave = false
    private var cancelRequested = false
    private let storage: WorkspaceStorage
    private let defaults: UserDefaults
    private let client = SQLClient()
    private let metadata = SQLClient()
    private var metadataAvailable = false
    private var objectRequest = UUID()

    init(storageDirectory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let root = storageDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "app.sqlgarden.mac", isDirectory: true)
        storage = WorkspaceStorage(directory: root)
        profile = defaults.data(forKey: "connection").flatMap { try? JSONDecoder().decode(ConnectionProfile.self, from: $0) } ?? ConnectionProfile()
        documents[0].savedText = documents[0].sql
        activeID = documents[0].id
        database = profile.database
        record(.appStarted)
        do {
            let (snapshot, usedBackup) = try storage.load()
            if let snapshot {
                historyEnabled = snapshot.historyEnabled
                history = historyEnabled ? HistoryEntry.bounded(snapshot.history) : []
                if !snapshot.drafts.isEmpty {
                    documents = snapshot.drafts.map { draft in
                        var doc = QueryDocument(title: draft.title, sql: draft.sql)
                        doc.id = draft.id; doc.selection = draft.selection; doc.savedText = draft.savedText
                        doc.url = draft.filePath.map { URL(fileURLWithPath: $0) }
                        return doc
                    }
                    activeID = documents.contains(where: { $0.id == snapshot.activeID }) ? snapshot.activeID! : documents[0].id
                    record(.recoveryLoaded)
                }
                if usedBackup { storageNotice = "Recuperação pela cópia de segurança. Confira os últimos rascunhos." }
            }
        } catch {
            storageNotice = "Não foi possível recuperar os rascunhos. Os arquivos anteriores foram preservados."
            record(.recoveryFailed)
            // Do not overwrite unreadable recovery files without an explicit user action.
            return
        }
        readyToSave = true
    }
    private func snapshot() -> WorkspaceSnapshot {
        var result = WorkspaceSnapshot()
        result.drafts = documents.map { Draft(id: $0.id, title: $0.title, sql: $0.sql, filePath: $0.url?.path,
                                              savedText: $0.savedText, selection: $0.selection) }
        result.activeID = activeID; result.historyEnabled = historyEnabled
        result.history = historyEnabled ? history : []
        return result
    }
    private func scheduleSave() {
        guard readyToSave else { return }
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.saveWorkspace() }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
    @discardableResult func saveWorkspace() -> Bool {
        saveTask?.cancel()
        guard readyToSave else { return false }
        do { try storage.save(snapshot()); return true }
        catch {
            storageNotice = "Falha ao salvar a recuperação local. Salve suas consultas em arquivos SQL."
            record(.storageFailed); return false
        }
    }
    func record(_ code: DiagnosticCode, message: String = "") {
        diagnosticEvents.append(DiagnosticEvent(code, states: DiagnosticSQLState.extract(from: message)))
        diagnosticEvents = Array(diagnosticEvents.suffix(100))
    }
    func setHistoryEnabled(_ enabled: Bool) {
        historyEnabled = enabled
        if !enabled { clearHistory() } else { saveWorkspace() }
    }
    func clearHistory() {
        guard readyToSave else {
            storageNotice = "Recuperação local ilegível: os arquivos anteriores foram preservados. Salve suas consultas em arquivos SQL; não foi possível limpar o histórico em disco."
            record(.storageFailed); return
        }
        history = []; saveTask?.cancel()
        do { try storage.eraseHistory(snapshot()) }
        catch { storageNotice = "Não foi possível limpar o histórico local por completo."; record(.storageFailed) }
    }
    private func appendHistory(sql: String, server: String, database: String, start: Date, outcome: ExecutionOutcome) {
        guard historyEnabled else { return }
        // Bound persistence without silently cutting SQL that might later be reopened.
        guard sql.utf8.count <= 2 * 1024 * 1024 else {
            storageNotice = "Consulta acima de 2 MiB: execução não incluída no histórico."; return
        }
        history.insert(HistoryEntry(sql: sql, server: server, database: database, elapsed: Date().timeIntervalSince(start), outcome: outcome), at: 0)
        history = HistoryEntry.bounded(history); saveWorkspace()
    }
    private func invalidateSessionState() {
        sessionID = nil; transactionCount = nil; transactionState = nil; sessionCheckedAt = nil
    }
    func inspectSession() async {
        guard connected, !executing else { return }
        executing = true; defer { executing = false }
        do {
            let response = try await client.execute("DECLARE @sg_state int = XACT_STATE(); SELECT @@SPID, @@TRANCOUNT, @sg_state, DB_NAME();", timeout: 5, maxRows: 1)
            guard response.success, let row = response.tables.first?.rows.first, row.count == 4,
                  let count = row[1].flatMap(Int.init), let state = row[2].flatMap(Int.init) else {
                throw StudioError.message("Estado da sessão indisponível.")
            }
            sessionID = row[0]; transactionCount = count; transactionState = state; sessionCheckedAt = Date()
            if let name = row[3] { database = name }
        } catch { invalidateSessionState(); record(.sessionStateUnavailable); self.error = "Não foi possível confirmar o estado da sessão." }
    }
    var activeIndex: Int { documents.firstIndex(where: { $0.id == activeID }) ?? 0 }
    var active: QueryDocument { documents[activeIndex] }
    var sqlBinding: Binding<String> {
        let id = activeID
        return Binding(get: { self.documents.first(where: { $0.id == id })?.sql ?? "" }, set: { value in
            if let i = self.documents.firstIndex(where: { $0.id == id }) { self.documents[i].sql = value }
        })
    }
    var selectionBinding: Binding<NSRange> {
        let id = activeID
        return Binding(get: { self.documents.first(where: { $0.id == id })?.selection ?? NSRange() }, set: { value in
            if let i = self.documents.firstIndex(where: { $0.id == id }) { self.documents[i].selection = value }
        })
    }
    func loadPassword() { password = PasswordStore.read(profile.credentialKey) ?? "" }
    func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: "connection") }
    }
    func connect() async {
        guard !connecting, !executing else { return }
        connecting = true
        defer { connecting = false }
        await disconnect()
        do {
            try await client.connect(profile, password: password)
            connected = true; database = profile.database; record(.connectionSucceeded)
            persistProfile()
            if rememberPassword {
                do { try PasswordStore.save(password, account: profile.credentialKey) }
                catch { self.error = error.localizedDescription }
            } else { PasswordStore.delete(profile.credentialKey) }
            connectionSheet = false
            do {
                try await metadata.connect(profile, password: password)
                metadataAvailable = true
                await refreshExplorer()
            } catch { record(.metadataFailed); self.error = "Conectado ao editor. O explorador não pôde conectar: \(error.localizedDescription)" }
            password = ""
        } catch { record(.connectionFailed, message: error.localizedDescription); self.error = error.localizedDescription }
    }
    func disconnect() async {
        if connected { record(.disconnected) }
        invalidateSessionState()
        objectRequest = UUID()
        connected = false; metadataAvailable = false
        databases = []; objects = []; loadingObjects = false
        await client.disconnect(); await metadata.disconnect()
    }
    func refreshExplorer() async {
        guard metadataAvailable else { return }
        do {
            let result = try await metadata.execute("SELECT name FROM sys.databases WHERE state = 0 AND HAS_DBACCESS(name) = 1 ORDER BY name;", maxRows: 10000)
            guard result.success else { throw StudioError.message(result.messages) }
            databases = result.tables.first?.rows.compactMap { $0.first.flatMap { $0 } } ?? []
            if !databases.contains(database) { databases.append(database) }
            await loadObjects()
        } catch { self.error = error.localizedDescription }
    }
    func loadObjects() async {
        guard metadataAvailable else { return }
        let request = UUID(); objectRequest = request
        let requestedDatabase = database
        loadingObjects = true; objects = []
        defer { if objectRequest == request { loadingObjects = false } }
        let prefix = SQLText.identifier(requestedDatabase)
        do {
            let response = try await metadata.execute("""
                SELECT s.name AS schema_name, o.name, o.type
                FROM \(prefix).sys.objects AS o
                JOIN \(prefix).sys.schemas AS s ON s.schema_id = o.schema_id
                WHERE o.is_ms_shipped = 0 AND o.type IN ('U','V','P','TR','FN','IF','TF')
                ORDER BY o.type, s.name, o.name;
                """, maxRows: 10000)
            guard response.success else { throw StudioError.message(response.messages) }
            guard objectRequest == request, database == requestedDatabase else { return }
            objects = response.tables.first?.rows.compactMap { row in
                guard row.count >= 3, let schema = row[0], let name = row[1], let type = row[2] else { return nil }
                return DatabaseObject(schema: schema, name: name, kind: type.trimmingCharacters(in: .whitespaces))
            } ?? []
        } catch { record(.metadataFailed); if objectRequest == request { self.error = error.localizedDescription } }
    }
    func selectDatabase(_ name: String) async {
        guard connected, !executing, name != database else { return }
        executing = true
        defer { executing = false }
        do {
            let response = try await client.execute("USE \(SQLText.identifier(name));")
            guard response.success else { throw StudioError.message(response.messages) }
            database = name
            invalidateSessionState()
            await loadObjects()
        } catch { self.error = error.localizedDescription }
    }
    func execute() async {
        guard connected, !executing else { return }
        let id = activeID
        let doc = active
        let ns = doc.sql as NSString
        let range = doc.selection
        let sql = range.length > 0 && NSMaxRange(range) <= ns.length ? ns.substring(with: range) : doc.sql
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        executing = true
        let start = Date()
        let executedServer = profile.host + ":" + String(profile.port)
        let executedDatabase = database
        cancelRequested = false
        invalidateSessionState()
        defer { executing = false }
        do {
            let response = try await client.execute(sql, timeout: profile.timeout, maxRows: profile.rowLimit)
            if let i = documents.firstIndex(where: { $0.id == id }) {
                documents[i].response = response
                documents[i].elapsed = Date().timeIntervalSince(start)
            }
            let outcome: ExecutionOutcome = response.success ? .success : (cancelRequested ? .canceled : .failure)
            record(outcome == .success ? .querySucceeded : outcome == .canceled ? .queryCanceled : .queryFailed, message: response.messages)
            appendHistory(sql: sql, server: executedServer, database: executedDatabase, start: start, outcome: outcome)
            resultTab = response.tables.isEmpty || !response.success ? "messages" : "results"
            if let current = await client.currentDatabase(), current != database {
                database = current
                if !databases.contains(current) { databases.append(current) }
                await loadObjects()
            }
        } catch {
            record(cancelRequested ? .queryCanceled : .queryFailed, message: error.localizedDescription)
            appendHistory(sql: sql, server: executedServer, database: executedDatabase, start: start, outcome: cancelRequested ? .canceled : .failure)
            if let i = documents.firstIndex(where: { $0.id == id }) {
                documents[i].response = SQLResponse(success: false, messages: error.localizedDescription)
                documents[i].elapsed = Date().timeIntervalSince(start)
            }
            resultTab = "messages"; self.error = error.localizedDescription
        }
    }
    func cancel() {
        guard executing else { return }
        cancelRequested = true; record(.cancelRequested)
        Task.detached { [client] in client.cancel() }
    }
    func newQuery(sql: String = "", title: String? = nil) {
        let doc = QueryDocument(title: title ?? "Consulta \(documents.count + 1)", sql: sql)
        documents.append(doc); activeID = doc.id
    }
    func closeQuery(_ id: UUID) {
        guard !executing, let i = documents.firstIndex(where: { $0.id == id }) else { return }
        if documents[i].dirty {
            let alert = NSAlert()
            alert.messageText = "Salvar alterações em \(documents[i].title)?"
            alert.informativeText = "A consulta ainda não foi salva."
            alert.addButton(withTitle: "Salvar"); alert.addButton(withTitle: "Cancelar"); alert.addButton(withTitle: "Descartar")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn { return }
            if response == .alertFirstButtonReturn { activeID = id; guard saveQuery() else { return } }
        }
        documents.removeAll { $0.id == id }
        if documents.isEmpty { newQuery() }
        else if activeID == id { activeID = documents[min(i, documents.count - 1)].id }
        saveWorkspace()
    }
    func openQuery() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.sqlText, .plainText]; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                var doc = QueryDocument(title: url.lastPathComponent, sql: text)
                doc.url = url; doc.savedText = text; documents.append(doc); activeID = doc.id
            } catch { self.error = "Não foi possível abrir \(url.lastPathComponent) em UTF-8: \(error.localizedDescription)" }
        }
    }
    @discardableResult func saveQuery() -> Bool {
        let index = activeIndex
        var url = documents[index].url
        if url == nil {
            let panel = NSSavePanel(); panel.allowedContentTypes = [.sqlText]; panel.nameFieldStringValue = active.title + ".sql"
            guard panel.runModal() == .OK else { return false }; url = panel.url
        }
        guard let url else { return false }
        do {
            if FileManager.default.fileExists(atPath: url.path), let saved = documents[index].savedText,
               let disk = try? String(contentsOf: url, encoding: .utf8), disk != saved {
                let alert = NSAlert(); alert.messageText = "O arquivo mudou fora do SQLGarden."
                alert.informativeText = "Substituir o arquivo pela versão desta aba? O rascunho local está preservado."
                alert.addButton(withTitle: "Cancelar"); alert.addButton(withTitle: "Substituir")
                guard alert.runModal() == .alertSecondButtonReturn else { return false }
            }
            try documents[index].sql.write(to: url, atomically: true, encoding: .utf8)
            documents[index].url = url; documents[index].title = url.lastPathComponent; documents[index].savedText = documents[index].sql
            saveWorkspace()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func showObject(_ object: DatabaseObject) {
        if object.kind == "U" || object.kind == "V" {
            newQuery(sql: "SELECT TOP (1000) *\nFROM \(SQLText.identifier(database)).\(object.qualified);\n", title: object.name)
        } else {
            newQuery(sql: "USE \(SQLText.identifier(database));\nGO\nSELECT OBJECT_DEFINITION(OBJECT_ID(\(SQLText.literal(object.qualified)))) AS Definicao;\n", title: object.name)
        }
    }
    func showColumns(_ object: DatabaseObject) {
        let prefix = SQLText.identifier(database)
        newQuery(sql: """
            SELECT c.name AS Coluna, t.name AS Tipo, c.max_length AS Bytes,
                   c.precision AS Precisao, c.scale AS Escala, c.is_nullable AS PermiteNull,
                   c.is_identity AS Identidade
            FROM \(prefix).sys.columns AS c
            JOIN \(prefix).sys.types AS t ON t.user_type_id = c.user_type_id
            JOIN \(prefix).sys.objects AS o ON o.object_id = c.object_id
            JOIN \(prefix).sys.schemas AS s ON s.schema_id = o.schema_id
            WHERE s.name = \(SQLText.literal(object.schema)) AND o.name = \(SQLText.literal(object.name))
            ORDER BY c.column_id;
            """, title: "Colunas · \(object.name)")
    }
    func export(_ table: ResultSet) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.commaSeparatedText]; panel.nameFieldStringValue = "resultado.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try SQLText.csv(table).write(to: url, atomically: true, encoding: .utf8) }
        catch { self.error = error.localizedDescription }
    }

}

import UniformTypeIdentifiers
extension UTType { static let sqlText = UTType(filenameExtension: "sql") ?? .plainText }
