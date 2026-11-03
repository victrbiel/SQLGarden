import AppKit
import SwiftUI
import StudioCore

private actor CredentialGate {
    private var continuation: CheckedContinuation<String?, Never>?
    func read() async -> String? { await withCheckedContinuation { continuation = $0 } }
    func resolve() { continuation?.resume(returning: "resposta-sintetica"); continuation = nil }
}
@main struct UIValidation {
    @MainActor static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, name: String) async throws {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host; window.setContentSize(NSSize(width: width, height: height))
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 150_000_000)
        host.layoutSubtreeIfNeeded(); host.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw StudioError.message("Snapshot sem bitmap") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let directory = URL(fileURLWithPath: ".test-build/ui-snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let image = bitmap.representation(using: .png, properties: [:]) else { throw StudioError.message("Snapshot sem PNG") }
        try image.write(to: directory.appendingPathComponent(name + ".png"))
        window.orderOut(nil)
    }
    @MainActor static func main() async {
        if CommandLine.arguments.contains("--crash-write") || CommandLine.arguments.contains("--crash-read") {
            guard let path = ProcessInfo.processInfo.environment["SQLGARDEN_CRASH_TEST_DIR"] else { exit(2) }
            let state = Workspace(storageDirectory: URL(fileURLWithPath: path), defaults: UserDefaults(suiteName: "app.sqlgarden.crash-validation")!)
            if CommandLine.arguments.contains("--crash-write") {
                state.newQuery(sql: "SELECT N'rascunho após interrupção 🎓';", title: "Crash QA")
                state.selectionBinding.wrappedValue = NSRange(location: 7, length: 3)
                try? await Task.sleep(nanoseconds: 600_000_000)
                print("CRASH_READY"); fflush(stdout)
                while true { try? await Task.sleep(nanoseconds: 1_000_000_000) }
            }
            guard state.active.title == "Crash QA", state.active.sql == "SELECT N'rascunho após interrupção 🎓';",
                  state.active.selection == NSRange(location: 7, length: 3), !state.connected,
                  state.active.response.tables.isEmpty else { print("FAIL: recuperação após SIGKILL"); exit(1) }
            print("PASS: processo novo recuperou rascunho e seleção após SIGKILL; sem conexão ou execução automática")
            return
        }
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw StudioError.message(message) }
            passed += 1; print("PASS \(passed): \(message)")
        }
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".test-build/ui-state-" + UUID().uuidString)
        let defaults = UserDefaults(suiteName: "app.sqlgarden.validation." + UUID().uuidString)!
        do {
            _ = NSApplication.shared
            let broken = root.appendingPathComponent("broken", isDirectory: true)
            try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
            let original = Data("{unreadable recovery".utf8)
            try original.write(to: broken.appendingPathComponent("workspace-v1.json"))
            try original.write(to: broken.appendingPathComponent("workspace-v1.backup.json"))
            let protected = Workspace(storageDirectory: broken, defaults: defaults)
            protected.setHistoryEnabled(false)
            let preserved = try Data(contentsOf: broken.appendingPathComponent("workspace-v1.json"))
            try check(preserved == original, "falha de recuperação preserva arquivos ilegíveis mesmo ao desativar histórico")
            let workspace = Workspace(storageDirectory: root, defaults: defaults)
            var unicodeEdit = QueryDocument(title: "normalização", sql: "SELECT N'e\u{301}';")
            unicodeEdit.savedText = "SELECT N'é';"
            try check(unicodeEdit.dirty, "edição com Unicode visualmente igual mas bytes diferentes exige salvamento")
            let fileURL = root.appendingPathComponent("arquivo-alterado.sql")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let invalidUTF8 = Data([0xff, 0xfe, 0x41])
            try invalidUTF8.write(to: fileURL)
            workspace.documents[0].url = fileURL; workspace.documents[0].savedText = "SELECT 1;"
            workspace.documents[0].sql = "SELECT 2;"
            let savedInvalidFile = await workspace.saveQuery()
            let diskAfterSave = try Data(contentsOf: fileURL)
            try check(!savedInvalidFile && diskAfterSave == invalidUTF8 && workspace.error != nil,
                      "arquivo alterado para conteúdo ilegível não é sobrescrito silenciosamente")
            workspace.error = nil
            let credentialGate = CredentialGate()
            let delayed = Workspace(storageDirectory: root.appendingPathComponent("keychain"), defaults: defaults,
                passwordReader: { _ in await credentialGate.read() })
            let readTask = Task { await delayed.loadPassword() }
            try await Task.sleep(nanoseconds: 40_000_000)
            try check(delayed.loadingPassword, "espera de credencial permite executar tarefas na interface")
            try await render(ConnectionView().environmentObject(delayed), width: 540, height: 660, name: "keychain-wait")
            delayed.useManualPassword(); delayed.password = "entrada-sintetica"
            await credentialGate.resolve(); await readTask.value
            try check(delayed.password == "entrada-sintetica" && !delayed.loadingPassword,
                      "digitação manual invalida resposta tardia do Chaves")
            delayed.password = ""
            let changedTask = Task { await delayed.loadPassword() }
            try await Task.sleep(nanoseconds: 40_000_000)
            delayed.profile.username = "outro-perfil-qa"
            await credentialGate.resolve(); await changedTask.value
            try check(delayed.password.isEmpty && !delayed.loadingPassword,
                      "troca de usuário invalida leitura anterior e limpa credencial")
            let credentialAccount = "SQLGarden_Validacao_" + UUID().uuidString
            do {
                try await PasswordStore.save("conteudo-sintetico-qa", account: credentialAccount)
                let savedCredential = try await PasswordStore.read(credentialAccount)
                try await PasswordStore.delete(credentialAccount)
                let removedCredential = try await PasswordStore.read(credentialAccount)
                try check(savedCredential == "conteudo-sintetico-qa" && removedCredential == nil,
                          "Chaves real salva, lê e remove somente a entrada de QA exclusiva")
            } catch {
                try? await PasswordStore.delete(credentialAccount)
                throw error
            }
            let denied = Workspace(storageDirectory: root.appendingPathComponent("keychain-denied"), defaults: defaults,
                passwordReader: { _ in throw StudioError.message("negação sintética") })
            await denied.loadPassword()
            try check(!denied.loadingPassword && denied.password.isEmpty && denied.passwordNotice != nil,
                      "negação de leitura libera digitação manual com aviso")
            workspace.newQuery(sql: "SELECT N'ação 🎓';\n", title: "Rascunho")
            let docID = workspace.activeID
            workspace.sqlBinding.wrappedValue += "-- edição recuperável"
            workspace.selectionBinding.wrappedValue = NSRange(location: 7, length: 4)
            try await Task.sleep(nanoseconds: 600_000_000)
            let recovered = Workspace(storageDirectory: root, defaults: defaults)
            try check(recovered.activeID == docID && recovered.active.sql.contains("edição recuperável") && recovered.active.selection == NSRange(location: 7, length: 4), "autosave recupera rascunho, aba ativa, Unicode e seleção sem conexão")
            workspace.rememberPassword = true
            let preference = Workspace(storageDirectory: root.appendingPathComponent("preference"), defaults: defaults)
            try check(preference.rememberPassword, "preferência do Chaves é persistida")
            workspace.rememberPassword = false
            await workspace.handleExecutionFailure("[08S01] transporte indisponível")
            try check(!workspace.connected && workspace.sessionNotice?.contains("Reconecte") == true, "falha de transporte invalida conexão sem retry")
            await workspace.handleExecutionFailure("[HY008] cancelado")
            try check(workspace.sessionNotice?.contains("ROLLBACK") == true, "cancelamento explica risco de transação pendente")
            var compositionModel = ""
            let sqlParent = SQLEditor(text: Binding(get: { compositionModel }, set: { compositionModel = $0 }), selection: .constant(NSRange()), identity: UUID())
            let composition = SQLEditor.Coordinator(sqlParent)
            let input = SQLTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
            composition.editor = input
            input.setMarkedText("'", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
            composition.textDidChange(Notification(name: NSText.didChangeNotification))
            composition.highlight()
            try check(input.hasMarkedText() && input.string == "'" && compositionModel.isEmpty, "destaque e binding preservam composição pendente")
            input.unmarkText()
            composition.textDidChange(Notification(name: NSText.didChangeNotification))
            try check(compositionModel == "'", "composição confirmada chega ao modelo")
            let editor = SQLTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
            let editorWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
            editorWindow.contentView = editor; editorWindow.makeFirstResponder(editor)
            editor.allowsUndo = true; editor.string = "SELECT 1;\nSELECT 2;\n"
            editor.setSelectedRange(NSRange(location: 0, length: 20)); editor.toggleSQLComment(nil)
            try check(editor.string == "--SELECT 1;\n--SELECT 2;\n", "ação AppKit comenta linhas selecionadas")
            editor.toggleSQLComment(nil)
            try check(editor.string == "SELECT 1;\nSELECT 2;\n", "ação AppKit descomenta sem mudar o SQL")
            editor.indentSQL(nil); editor.unindentSQL(nil)
            try check(editor.string == "SELECT 1;\nSELECT 2;\n", "indentação/desindentação AppKit preserva texto")
            editor.undoManager?.removeAllActions()
            editor.indentSQL(nil)
            editor.undoManager?.undo()
            try check(editor.string == "SELECT 1;\nSELECT 2;\n", "edição por comando participa do Undo nativo")
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 300)); scroll.documentView = editor
            let ruler = LineNumberRuler(scroll: scroll, editor: editor); scroll.verticalRulerView = ruler
            ruler.updateLines()
            try check(ruler.ruleThickness >= 52, "régua de números de linha criada no AppKit")
            let report = SupportReport.compose(kind: "Problema", description: "Exemplo de QA", steps: "Abrir", diagnostic: SupportReport.diagnostic(version: "0.3.1", system: "macOS", architecture: "arm64", missing: RuntimeDependencies.missing, events: workspace.diagnosticEvents))
            try await render(FeedbackView().environmentObject(workspace), width: 760, height: 620, name: "feedback")
            try check(!report.contains("edição recuperável") && !report.contains("SELECT N'"), "diagnóstico não absorve SQL ou rascunhos")
            if let password = ProcessInfo.processInfo.environment["SQLGARDEN_INTEGRATION_PASSWORD"],
               let port = Int(ProcessInfo.processInfo.environment["SQLGARDEN_TEST_PORT"] ?? "") {
                workspace.profile.host = "127.0.0.1"; workspace.profile.port = port
                workspace.password = password; workspace.rememberPassword = false
                await workspace.connect()
                try check(workspace.connected && workspace.error == nil, "Workspace conecta a servidor de QA isolado")
                workspace.selectionBinding.wrappedValue = NSRange()
                workspace.sqlBinding.wrappedValue = "CREATE TABLE #SGNUL(n int);"
                await workspace.execute()
                workspace.sqlBinding.wrappedValue = "INSERT #SGNUL VALUES(1);\nGO\n--\0"
                await workspace.execute()
                let rejectedNUL = !workspace.active.response.success
                workspace.error = nil
                workspace.sqlBinding.wrappedValue = "SELECT COUNT(*) FROM #SGNUL;"
                await workspace.execute()
                try check(rejectedNUL && workspace.active.response.tables.first?.rows.first?[0] == "0",
                          "NUL em lote posterior bloqueia todo o documento antes de qualquer INSERT")
                workspace.sqlBinding.wrappedValue = "SELECT N'A'+NCHAR(0)+N'B', DATALENGTH(N'A\r\nB');"
                await workspace.execute()
                try check(workspace.active.response.tables.first?.rows.first == ["A\0B", "8"],
                          "Workspace preserva NUL em resultado e CRLF no SQL real")
                workspace.sqlBinding.wrappedValue = "SELECT N'ação 🎓' AS Texto, CAST(NULL AS INT) AS Nulo; SELECT N'outro' AS Outro;"
                workspace.selectionBinding.wrappedValue = NSRange()
                await workspace.execute()
                try check(workspace.active.response.tables.count == 2 && workspace.history.first?.outcome == .success, "execução real retorna resultados múltiplos e grava histórico de sucesso")
                try await render(ContentView().environmentObject(workspace), width: 1280, height: 820, name: "workspace")
                try await render(HistoryView().environmentObject(workspace), width: 840, height: 590, name: "history")
                try await render(CellInspector(cell: InspectedCell(column: "Texto longo", value: "ação 🎓\n" + String(repeating: "Texto longo e Unicode. ", count: 1200))), width: 720, height: 480, name: "cell")
                let gridHost = NSHostingView(rootView: GridTable(columns: ["A", "B"], rows: [[nil, "NULL"], ["ação", "texto\ncom linhas"]]) { _ in })
                let gridWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
                gridWindow.contentView = gridHost; gridHost.layoutSubtreeIfNeeded()
                try await Task.sleep(nanoseconds: 150_000_000)
                func findTable(_ view: NSView) -> ResultTableView? { (view as? ResultTableView) ?? view.subviews.compactMap { findTable($0) }.first }
                guard let grid = findTable(gridHost) else { throw StudioError.message("Grade não foi criada") }
                grid.choose?(0, 0, false); grid.choose?(1, 1, true)
                print("Grade QA: \(String(reflecting: grid.copyValue?(true, false)))")
                try check(grid.copyValue?(true, false) == "A\tB\nNULL\t\"NULL\"\nação\t\"texto\ncom linhas\"", "grade nativa copia intervalo com cabeçalhos, NULL e quebras de linha")
                grid.selectEverything?()
                try check((grid.copyValue?(false, false))?.contains("ação") == true, "grade nativa seleciona todas as células carregadas")
                gridWindow.orderOut(nil)
                workspace.sqlBinding.wrappedValue = "SELECT 42; THROW 51000, N'erro privado de QA', 1;"
                await workspace.execute()
                try check(!workspace.active.response.success && workspace.active.response.tables.count == 1 && workspace.history.first?.outcome == .failure, "erro real preserva resultado parcial e histórico de falha")
                workspace.sqlBinding.wrappedValue = "BEGIN TRANSACTION;"
                await workspace.execute(); await workspace.inspectSession()
                try check(workspace.transactionCount == 1 && workspace.transactionState == 1 && workspace.sessionID != nil, "verificação explícita confirma transação aberta e sessão")
                workspace.sqlBinding.wrappedValue = "ROLLBACK;"
                await workspace.execute()
                try check(workspace.transactionCount == nil, "nova execução invalida estado antigo da transação")
                await workspace.inspectSession()
                print("Estado após ROLLBACK: TRANCOUNT=\(workspace.transactionCount.map(String.init) ?? "nil"), XACT_STATE=\(workspace.transactionState.map(String.init) ?? "nil")")
                try check(workspace.transactionCount == 0 && workspace.transactionState == 0, "verificação confirma ROLLBACK na mesma sessão")
                workspace.sqlBinding.wrappedValue = "WAITFOR DELAY '00:00:20';"
                let waiting = Task { await workspace.execute() }
                try await Task.sleep(nanoseconds: 600_000_000); workspace.cancel(); await waiting.value
                try check(workspace.history.first?.outcome == .canceled, "cancelamento real é registrado como cancelado")
                workspace.setHistoryEnabled(false)
                workspace.sqlBinding.wrappedValue = "SELECT 123;"; await workspace.execute()
                let noHistory = Workspace(storageDirectory: root, defaults: defaults)
                try check(workspace.history.isEmpty && noHistory.history.isEmpty && !noHistory.historyEnabled, "desativar histórico apaga ambas as gerações e impede novas gravações")
                try check(!workspace.diagnosticEvents.isEmpty && !SupportReport.diagnostic(version: "0.3.1", system: "macOS", architecture: "arm64", missing: [], events: workspace.diagnosticEvents).contains("erro privado de QA"), "eventos de falhas reais excluem mensagens brutas do servidor")
                let explorerTask = Task { await workspace.refreshExplorer() }
                await Task.yield()
                await workspace.disconnect()
                await explorerTask.value
                try check(!workspace.connected && workspace.databases.isEmpty && workspace.objects.isEmpty,
                          "resposta pendente do explorador não repovoa conexão encerrada")
            }
            print("Validação de interface/modelo concluída: \(passed) verificações. Nenhum e-mail enviado.")
        } catch { print("FAIL: \(error.localizedDescription)"); exit(1) }
    }
}
