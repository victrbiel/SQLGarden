import SwiftUI
import StudioCore

@MainActor struct DatabaseExplorer: View {
    @EnvironmentObject var workspace: Workspace
    @State private var collapsed: Set<String> = []
    private let groups = [("Tabelas", ["U"]), ("Views", ["V"]), ("Procedures", ["P"]), ("Triggers", ["TR"]), ("Funções", ["FN", "IF", "TF"])]
    private var visible: [DatabaseObject] {
        workspace.objects.filter { workspace.search.isEmpty || "\($0.schema).\($0.name)".localizedCaseInsensitiveContains(workspace.search) }
    }
    var body: some View {
        VStack(spacing: 0) {
            Picker("Banco ativo", selection: Binding(get: { workspace.database }, set: { name in
                Task { await workspace.selectDatabase(name) }
            })) {
                ForEach(workspace.databases, id: \.self) { Text($0).tag($0) }
            }.padding(12).disabled(workspace.executing || workspace.connecting)
            Text("\(visible.count) objetos · clique para preparar uma consulta")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
            List {
                ForEach(groups, id: \.0) { group in
                    let members = visible.filter { group.1.contains($0.kind) }
                    if !members.isEmpty {
                        Section("\(group.0) (\(members.count))") {
                            ForEach(Array(Set(members.map(\.schema))).sorted(), id: \.self) { schema in
                                let key = group.0 + "." + schema
                                DisclosureGroup(isExpanded: Binding(get: { !collapsed.contains(key) }, set: { expanded in
                                    if expanded { collapsed.remove(key) } else { collapsed.insert(key) }
                                })) {
                                    ForEach(members.filter { $0.schema == schema }) { object in
                                        HStack {
                                            Button { workspace.showObject(object) } label: {
                                                Label(object.name, systemImage: object.icon)
                                                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                            }.buttonStyle(.plain).help("Preparar consulta para \(schema).\(object.name)")
                                            Menu {
                                                Button(object.kind == "U" || object.kind == "V" ? "Consultar dados…" : "Ver definição…") { workspace.showObject(object) }
                                                if object.kind == "U" || object.kind == "V" {
                                                    Button("Consultar colunas…") { workspace.showColumns(object) }
                                                }
                                                Button("Copiar nome qualificado") {
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(SQLText.identifier(workspace.database) + "." + object.qualified, forType: .string)
                                                }
                                            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Ações para \(object.name)")
                                        }.padding(.vertical, 3)
                                    }
                                } label: { Label(schema, systemImage: "folder") }
                            }
                        }
                    }
                }
                if visible.isEmpty {
                    Text(workspace.loadingObjects ? "Carregando objetos…" : workspace.search.isEmpty ? "Nenhum objeto neste banco." : "Nenhum objeto corresponde à busca.")
                        .foregroundStyle(.secondary)
                }
            }.listStyle(.sidebar).searchable(text: $workspace.search, placement: .sidebar, prompt: "Tabela, view ou esquema")
        }
    }
}
