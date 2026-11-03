import AppKit
import SwiftUI
import StudioCore

struct QueryDocument: Identifiable {
    let id = UUID()
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
    @Published var documents = [QueryDocument(title: "Consulta 1", sql: "-- Escreva seu T-SQL e pressione ⌘↩ para executar.\nSELECT @@VERSION AS Versao;\nGO\nSELECT DB_NAME() AS BancoAtual;\n")]
    @Published var activeID = UUID()
    @Published var resultTab = "results"
    private let client = SQLClient()
    private let metadata = SQLClient()
    private var metadataAvailable = false
    private var objectRequest = UUID()

    init() {
        profile = (UserDefaults.standard.data(forKey: "connection").flatMap { try? JSONDecoder().decode(ConnectionProfile.self, from: $0) }) ?? ConnectionProfile()
        activeID = documents[0].id
        database = profile.database
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
        if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: "connection") }
    }
    func connect() async {
        guard !connecting, !executing else { return }
        connecting = true
        defer { connecting = false }
        await disconnect()
        do {
            try await client.connect(profile, password: password)
            connected = true; database = profile.database
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
            } catch { self.error = "Conectado ao editor. O explorador não pôde conectar: \(error.localizedDescription)" }
            password = ""
        } catch { self.error = error.localizedDescription }
    }
    func disconnect() async {
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
        } catch { if objectRequest == request { self.error = error.localizedDescription } }
    }
    func selectDatabase(_ name: String) async {
        guard connected, !executing, name != database else { return }
        executing = true
        defer { executing = false }
        do {
            let response = try await client.execute("USE \(SQLText.identifier(name));")
            guard response.success else { throw StudioError.message(response.messages) }
            database = name
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
        defer { executing = false }
        do {
            let response = try await client.execute(sql, timeout: profile.timeout, maxRows: profile.rowLimit)
            if let i = documents.firstIndex(where: { $0.id == id }) {
                documents[i].response = response
                documents[i].elapsed = Date().timeIntervalSince(start)
            }
            resultTab = response.tables.isEmpty || !response.success ? "messages" : "results"
            if let current = await client.currentDatabase(), current != database {
                database = current
                if !databases.contains(current) { databases.append(current) }
                await loadObjects()
            }
        } catch { self.error = error.localizedDescription }
    }
    func cancel() { Task.detached { [client] in client.cancel() } }
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
            try documents[index].sql.write(to: url, atomically: true, encoding: .utf8)
            documents[index].url = url; documents[index].title = url.lastPathComponent; documents[index].savedText = documents[index].sql
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
    func canQuit() -> Bool {
        if executing {
            let alert = NSAlert(); alert.messageText = "Há uma consulta em execução."
            alert.informativeText = "Pare a consulta antes de encerrar o aplicativo."
            alert.runModal(); return false
        }
        guard documents.contains(where: \.dirty) else { return true }
        let alert = NSAlert(); alert.messageText = "Há consultas com alterações não salvas."
        alert.informativeText = "Volte ao editor para salvá-las, ou encerre descartando as alterações."
        alert.addButton(withTitle: "Voltar"); alert.addButton(withTitle: "Encerrar e descartar")
        return alert.runModal() == .alertSecondButtonReturn
    }
}

import UniformTypeIdentifiers
extension UTType { static let sqlText = UTType(filenameExtension: "sql") ?? .plainText }
