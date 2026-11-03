import SwiftUI

@MainActor struct DockerView: View {
    @EnvironmentObject var workspace: Workspace
    @Environment(\.dismiss) var dismiss
    @State private var containers: [ContainerInfo] = []
    @State private var busy = false
    @State private var notice: String?
    @State private var selectedName: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Servidor no Docker", systemImage: "shippingbox").font(.title2.bold())
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            Text("Selecione seu container existente. O SQLGarden não cria nem remove bancos ou volumes.")
                .foregroundStyle(.secondary)
            List(selection: $selectedName) {
                ForEach(containers) { container in
                    HStack(spacing: 12) {
                        Circle().fill(container.running ? Color.green : Color.secondary).frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(container.Names).font(.headline)
                            Text(container.Image).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(container.Status).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5).tag(container.Names)
                }
            }.overlay {
                if containers.isEmpty && !busy { ContentUnavailableView("Nenhum container listado", systemImage: "shippingbox", description: Text("Abra o Docker Desktop e clique em Atualizar.")) }
            }
            if let notice {
                ScrollView { Text(notice).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 75)
            }
            Text("Parar o container encerra as conexões com ele. As portas e credenciais continuam sendo configuradas na conexão do app.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abrir Docker Desktop") { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Docker.app")) }
                Button("Atualizar") { Task { await refresh() } }.disabled(busy)
                Spacer()
                if let selected = containers.first(where: { $0.Names == selectedName }) {
                    Button(selected.running ? "Parar" : "Iniciar") { Task { await control(selected) } }
                        .disabled(busy || workspace.executing || workspace.connecting)
                }
                Button("Concluído") { workspace.persistProfile(); dismiss() }.keyboardShortcut(.defaultAction).disabled(busy)
            }
        }.padding(24).frame(width: 700, height: 440)
            .task { selectedName = workspace.profile.container.isEmpty ? nil : workspace.profile.container; await refresh() }
            .onChange(of: selectedName) { _, value in workspace.profile.container = value ?? "" }
            .interactiveDismissDisabled(busy)
    }
    private func refresh() async {
        busy = true; defer { busy = false }
        do { containers = try await DockerService.list(); notice = nil }
        catch { notice = error.localizedDescription }
    }
    private func control(_ container: ContainerInfo) async {
        busy = true; defer { busy = false }
        do {
            if container.running {
                // Conservatively disconnect both sessions before stopping a
                // selected server, even when its published port is unknown.
                await workspace.disconnect()
            }
            try await DockerService.control(container.running ? "stop" : "start", name: container.Names)
            containers = try await DockerService.list()
            notice = container.running ? "Container parado." : "Container iniciado. Aguarde o SQL Server ficar pronto e conecte pelo app."
            workspace.persistProfile()
        } catch { notice = error.localizedDescription }
    }
}
