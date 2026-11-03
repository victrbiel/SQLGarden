import SwiftUI

@MainActor struct ConnectionView: View {
    @EnvironmentObject var workspace: Workspace
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "network").font(.title).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.connected ? "Conexão ativa" : "Conectar ao SQL Server").font(.title2.bold())
                    Text("Use o servidor e a porta que já funcionam nas suas aulas.").foregroundStyle(.secondary)
                }
            }
            if !RuntimeDependencies.missing.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Prepare as dependências antes de conectar", systemImage: "exclamationmark.triangle")
                    Text(RuntimeDependencies.missing.joined(separator: ", ")).font(.caption)
                    Button("Instalar dependências…") {
                        if let url = Bundle.main.url(forResource: "Instalar Dependencias", withExtension: "command") { NSWorkspace.shared.open(url) }
                    }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            Form {
                Section("Servidor") {
                    TextField("Nome da conexão", text: $workspace.profile.name)
                    TextField("Servidor", text: $workspace.profile.host, prompt: Text("localhost"))
                    TextField("Porta", value: $workspace.profile.port, format: .number.grouping(.never))
                    TextField("Banco inicial", text: $workspace.profile.database)
                }
                Section("Autenticação SQL Server") {
                    TextField("Usuário", text: $workspace.profile.username)
                    SecureField("Senha", text: $workspace.password)
                        .onChange(of: workspace.password) { _, _ in
                            if workspace.loadingPassword { workspace.useManualPassword() }
                        }
                    if workspace.loadingPassword {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Aguardando autorização do Chaves…").font(.caption)
                            Button("Digitar manualmente") { workspace.useManualPassword() }
                        }
                    }
                    if let notice = workspace.passwordNotice { Text(notice).font(.caption).foregroundStyle(.secondary) }
                    Toggle("Salvar senha no Chaves do macOS", isOn: $workspace.rememberPassword)
                    Toggle("Confiar no certificado do servidor", isOn: $workspace.profile.trustCertificate)
                    Text("A conexão usa criptografia. Para seu Docker local com certificado próprio, mantenha a confiança ativada. Em servidores remotos com certificado válido, desative.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Consultas") {
                    Picker("Limite de linhas por resultado", selection: $workspace.profile.rowLimit) {
                        Text("500").tag(500); Text("1.000").tag(1000); Text("5.000").tag(5000); Text("10.000").tag(10000)
                    }
                    Picker("Tempo limite de consulta", selection: $workspace.profile.timeout) {
                        Text("30 segundos").tag(30); Text("60 segundos").tag(60); Text("5 minutos").tag(300)
                    }
                }
            }.formStyle(.grouped).disabled(workspace.connecting || workspace.connected)
            HStack {
                if workspace.connected {
                    Button("Desconectar", role: .destructive) { Task { await workspace.disconnect() } }
                }
                Spacer()
                Button(workspace.connected ? "Fechar" : "Cancelar") { dismiss() }.keyboardShortcut(.cancelAction).disabled(workspace.connecting)
                if !workspace.connected {
                    if workspace.connecting { ProgressView().controlSize(.small) }
                    Button(workspace.connecting ? "Conectando…" : "Conectar") { Task { await workspace.connect() } }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(workspace.connecting || workspace.loadingPassword)
                }
            }
        }.padding(24).frame(width: 540, height: 660)
            .interactiveDismissDisabled(workspace.connecting)
            .task(id: workspace.profile.credentialKey) { await workspace.loadPassword() }
            .onDisappear { workspace.useManualPassword() }
            .alert("Conexão", isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) {
                Button("OK") { workspace.error = nil }
            } message: { Text(workspace.error ?? "") }
    }
}
