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
        guard workspace.documents.contains(where: \.dirty) else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Há consultas com alterações não salvas."
        alert.informativeText = "Volte ao editor para salvá-las, ou encerre descartando as alterações."
        alert.addButton(withTitle: "Voltar")
        alert.addButton(withTitle: "Encerrar e descartar")
        // Reply only after returning from applicationShouldTerminate. A sheet
        // keeps the main run loop responsive while termination is pending.
        DispatchQueue.main.async {
            if let window = sender.mainWindow {
                alert.beginSheetModal(for: window) { result in
                    sender.reply(toApplicationShouldTerminate: result == .alertSecondButtonReturn)
                }
            } else {
                sender.reply(toApplicationShouldTerminate: alert.runModal() == .alertSecondButtonReturn)
            }
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
            CommandMenu("Consulta") {
                Button("Executar seleção ou consulta") { Task { await workspace.execute() } }
                    .keyboardShortcut(.return, modifiers: .command).disabled(!workspace.connected || workspace.executing)
                Button("Parar execução") { workspace.cancel() }.keyboardShortcut(".", modifiers: .command).disabled(!workspace.executing)
                Divider()
                Button("Atualizar explorador") { Task { await workspace.refreshExplorer() } }.disabled(!workspace.connected)
                Button("Conectar…") { workspace.loadPassword(); workspace.connectionSheet = true }.disabled(workspace.connected || workspace.connecting || workspace.executing)
            }
        }
    }
}
