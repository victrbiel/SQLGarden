import SwiftUI
import AppKit
import StudioCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var workspace: Workspace?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else { return .terminateNow }
        return workspace.canQuit() ? .terminateNow : .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
@MainActor struct SQLGardenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var workspace = Workspace()
    @State private var provisionedLocalServer = false
    var body: some Scene {
        Window("SQLGarden", id: "workspace") {
            ContentView().environmentObject(workspace)
                .frame(minWidth: 920, minHeight: 620)
                .onAppear {
                    delegate.workspace = workspace
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    // Explicit one-time provisioning by the local installer.
                    // The app itself creates its Keychain item, so its normal
                    // access rules apply. Never overwrite an existing profile.
                    if !provisionedLocalServer,
                       CommandLine.arguments.contains("--provision-local-server"),
                       UserDefaults.standard.data(forKey: "connection") == nil,
                       let secret = ProcessInfo.processInfo.environment["SQLGARDEN_LOCAL_PASSWORD"], !secret.isEmpty {
                        provisionedLocalServer = true
                        unsetenv("SQLGARDEN_LOCAL_PASSWORD")
                        workspace.profile = ConnectionProfile()
                        workspace.profile.name = "SQL Server Express local"
                        workspace.profile.host = "127.0.0.1"
                        workspace.profile.container = "sqlgarden-express"
                        workspace.password = secret
                        Task { await workspace.connect() }
                    }
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
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
