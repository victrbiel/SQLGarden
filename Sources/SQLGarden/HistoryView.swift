import SwiftUI
import StudioCore

@MainActor struct HistoryView: View {
    @EnvironmentObject var workspace: Workspace
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    @State private var selected: UUID?
    @State private var confirmClear = false
    private var entries: [HistoryEntry] { workspace.history.filter { $0.matches(search) } }
    private var entry: HistoryEntry? { entries.first { $0.id == selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Histórico de consultas").font(.title2.bold())
                Spacer(); Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Toggle("Guardar histórico neste Mac", isOn: Binding(get: { workspace.historyEnabled }, set: { workspace.setHistoryEnabled($0) }))
            Text("Armazena SQL, servidor, banco, data e duração localmente. Não guarda resultados. Desativar apaga o histórico. Até 500 execuções / 8 MiB; consultas acima de 2 MiB ficam de fora.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Buscar SQL, servidor, banco, data ou estado", text: $search)
                .textFieldStyle(.roundedBorder)
            HSplitView {
                List(selection: $selected) {
                    ForEach(entries) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: item.outcome == .success ? "checkmark.circle" : item.outcome == .canceled ? "stop.circle" : "exclamationmark.circle")
                                    .foregroundStyle(item.outcome == .success ? .green : .orange)
                                Text(item.outcome.title)
                                Spacer(); Text(String(format: "%.2f s", item.elapsed))
                            }.font(.caption)
                            Text(item.sql.replacingOccurrences(of: "\n", with: " ")).lineLimit(2).font(.system(.body, design: .monospaced))
                            Text("\(item.database) · \(item.server)").font(.caption).foregroundStyle(.secondary)
                            Text(item.date.formatted(date: .numeric, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                        }.padding(.vertical, 4).tag(item.id)
                    }
                }.listStyle(.inset).frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    if let entry {
                        Text("\(entry.database) · \(entry.date.formatted())").font(.caption).textSelection(.enabled)
                        ScrollView {
                            Text(entry.sql).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading).padding(8)
                        }
                        Button("Abrir em nova aba") { workspace.newQuery(sql: entry.sql, title: "Histórico · \(entry.database)"); dismiss() }
                        Text("Abre somente o texto. Não troca a conexão nem executa a consulta.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("Selecione uma execução", systemImage: "clock.arrow.circlepath", description: Text(entries.isEmpty ? "Nenhuma execução encontrada." : "Revise o SQL antes de reabrir."))
                    }
                }.padding(8).frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text("\(workspace.history.count) execuções · Rascunhos das abas são recuperados separadamente.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Apagar histórico…", role: .destructive) { confirmClear = true }.disabled(workspace.history.isEmpty)
            }
        }.padding(20).frame(width: 840, height: 590)
            .alert("Apagar todo o histórico?", isPresented: $confirmClear) {
                Button("Cancelar", role: .cancel) {}
                Button("Apagar", role: .destructive) { workspace.clearHistory(); selected = nil }
            } message: { Text("As consultas salvas em arquivos e os rascunhos abertos serão preservados.") }
    }
}
