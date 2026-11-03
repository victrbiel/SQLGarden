import AppKit
import SwiftUI
import StudioCore

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
            workspace.newQuery(sql: "SELECT N'ação 🎓';\n", title: "Rascunho")
            let docID = workspace.activeID
            workspace.sqlBinding.wrappedValue += "-- edição recuperável"
            workspace.selectionBinding.wrappedValue = NSRange(location: 7, length: 4)
            try await Task.sleep(nanoseconds: 600_000_000)
            let recovered = Workspace(storageDirectory: root, defaults: defaults)
            try check(recovered.activeID == docID && recovered.active.sql.contains("edição recuperável") && recovered.active.selection == NSRange(location: 7, length: 4), "autosave recupera rascunho, aba ativa, Unicode e seleção sem conexão")
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
            let report = SupportReport.compose(kind: "Problema", description: "Exemplo de QA", steps: "Abrir", diagnostic: SupportReport.diagnostic(version: "0.3.0", system: "macOS", architecture: "arm64", missing: RuntimeDependencies.missing, events: workspace.diagnosticEvents))
            try await render(FeedbackView().environmentObject(workspace), width: 760, height: 620, name: "feedback")
            try check(!report.contains("edição recuperável") && !report.contains("SELECT N'"), "diagnóstico não absorve SQL ou rascunhos")
            if let password = ProcessInfo.processInfo.environment["SQLGARDEN_INTEGRATION_PASSWORD"],
               let port = Int(ProcessInfo.processInfo.environment["SQLGARDEN_TEST_PORT"] ?? "") {
                workspace.profile.host = "127.0.0.1"; workspace.profile.port = port
                workspace.password = password; workspace.rememberPassword = false
                await workspace.connect()
                try check(workspace.connected && workspace.error == nil, "Workspace conecta a servidor de QA isolado")
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
                try check(!workspace.diagnosticEvents.isEmpty && !SupportReport.diagnostic(version: "0.3.0", system: "macOS", architecture: "arm64", missing: [], events: workspace.diagnosticEvents).contains("erro privado de QA"), "eventos de falhas reais excluem mensagens brutas do servidor")
                await workspace.disconnect()
            }
            print("Validação de interface/modelo concluída: \(passed) verificações. Nenhum e-mail enviado.")
        } catch { print("FAIL: \(error.localizedDescription)"); exit(1) }
    }
}
