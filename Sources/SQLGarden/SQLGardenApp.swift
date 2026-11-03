import SwiftUI
import AppKit
import StudioCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var workspace: Workspace?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else { return .terminateNow }
        if workspace.executing {
            let alert = NSAlert()
            alert.messageText = "Há uma consulta em execução."
            alert.informativeText = "Pare a consulta antes de encerrar o SQLGarden."
            if let window = sender.mainWindow { alert.beginSheetModal(for: window) }
            return .terminateCancel
        }
        if workspace.saveWorkspace() { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A recuperação local não pôde ser salva."
        alert.informativeText = "Volte e salve suas consultas em arquivos SQL antes de encerrar."
        alert.addButton(withTitle: "Voltar")
        alert.addButton(withTitle: "Encerrar sem recuperação")
        DispatchQueue.main.async {
            if let window = sender.mainWindow {
                alert.beginSheetModal(for: window) { result in
                    sender.reply(toApplicationShouldTerminate: result == .alertSecondButtonReturn)
                }
            } else { sender.reply(toApplicationShouldTerminate: alert.runModal() == .alertSecondButtonReturn) }
        }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
@MainActor struct SQLGardenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var workspace = Workspace()
    @State private var showingAbout = false
    @AppStorage("appearance") private var appearance = "system"
    private var colorScheme: ColorScheme? {
        appearance == "dark" ? .dark : appearance == "light" ? .light : nil
    }
    var body: some Scene {
        Window("SQLGarden", id: "workspace") {
            ContentView().environmentObject(workspace)
                .background(BrandAppearanceObserver().frame(width: 0, height: 0))
                .preferredColorScheme(colorScheme)
                .sheet(isPresented: $showingAbout) { AboutView().preferredColorScheme(colorScheme) }
                .frame(minWidth: 920, minHeight: 620)
                .onAppear {
                    delegate.workspace = workspace
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)

                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Sobre o SQLGarden") { showingAbout = true }
            }
            CommandGroup(after: .toolbar) {
                Picker("Aparência", selection: $appearance) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Escuro").tag("dark")
                }
            }
            CommandGroup(replacing: .help) {
                Button("Enviar feedback ou relatar problema…") { workspace.feedbackSheet = true }
                Divider()
                Button("Guia de instalação e uso") {
                    if let url = Bundle.main.url(forResource: "INSTALACAO", withExtension: "md") { NSWorkspace.shared.open(url) }
                }
                Button("Instalar dependências do SQL Server…") {
                    if let url = Bundle.main.url(forResource: "Instalar Dependencias", withExtension: "command") { NSWorkspace.shared.open(url) }
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Nova consulta") { workspace.newQuery() }.keyboardShortcut("n")
                Button("Abrir SQL…") { workspace.openQuery() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Salvar consulta") { workspace.saveQuery() }.keyboardShortcut("s")
                Button("Fechar consulta") { workspace.closeQuery(workspace.activeID) }.keyboardShortcut("w", modifiers: [.command, .shift]).disabled(workspace.executing)
            }
            CommandGroup(after: .textEditing) {
                Button("Buscar no editor…") {
                    let item = NSMenuItem(); item.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
                    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
                }.keyboardShortcut("f")
                Button("Buscar e substituir…") {
                    let item = NSMenuItem(); item.tag = Int(NSTextFinder.Action.showReplaceInterface.rawValue)
                    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
                }.keyboardShortcut("f", modifiers: [.command, .option])
                Button("Ir para linha…") { NSApp.sendAction(#selector(SQLTextView.goToSQLLine(_:)), to: nil, from: nil) }.keyboardShortcut("l")
                Button("Comentar / descomentar") { NSApp.sendAction(#selector(SQLTextView.toggleSQLComment(_:)), to: nil, from: nil) }.keyboardShortcut("/")
                Button("Indentar SQL") { NSApp.sendAction(#selector(SQLTextView.indentSQL(_:)), to: nil, from: nil) }.keyboardShortcut("]")
                Button("Desindentar SQL") { NSApp.sendAction(#selector(SQLTextView.unindentSQL(_:)), to: nil, from: nil) }.keyboardShortcut("[")
            }
            CommandMenu("Consulta") {
                Button("Executar seleção ou consulta") { Task { await workspace.execute() } }
                    .keyboardShortcut(.return, modifiers: .command).disabled(!workspace.connected || workspace.executing)
                Button("Parar execução") { workspace.cancel() }.keyboardShortcut(".", modifiers: .command).disabled(!workspace.executing)
                Divider()
                Button("Histórico de consultas…") { workspace.historySheet = true }.keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Verificar estado da sessão") { Task { await workspace.inspectSession() } }.disabled(!workspace.connected || workspace.executing)
                Button("Atualizar explorador") { Task { await workspace.refreshExplorer() } }.disabled(!workspace.connected)
                Button("Conectar…") { workspace.connectionSheet = true }.disabled(workspace.connected || workspace.connecting || workspace.executing)
            }
        }
    }
}
