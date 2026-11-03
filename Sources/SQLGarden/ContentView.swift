import SwiftUI
import StudioCore

@MainActor struct ContentView: View {
    @EnvironmentObject var workspace: Workspace
    @State private var selectedResult = 0
    @State private var sidebar: NavigationSplitViewVisibility = .all
    private let groups = [("Tabelas", ["U"]), ("Views", ["V"]), ("Procedures", ["P"]), ("Triggers", ["TR"]), ("Funções", ["FN", "IF", "TF"])]

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebar) {
            VStack(spacing: 0) {
                connectionCard
                Divider()
                if workspace.connected {
                    List {
                        Section("Bancos de dados") {
                            ForEach(workspace.databases, id: \.self) { name in
                                Button { Task { await workspace.selectDatabase(name) } } label: {
                                    HStack {
                                        Label(name, systemImage: "externaldrive")
                                        Spacer()
                                        if name == workspace.database { Image(systemName: "checkmark").foregroundStyle(.tint) }
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(workspace.executing)
                            }
                        }
                        ForEach(groups, id: \.0) { group in
                            Section(group.0) {
                                let objects = workspace.objects.filter { group.1.contains($0.kind) && (workspace.search.isEmpty || "\($0.schema).\($0.name)".localizedCaseInsensitiveContains(workspace.search)) }
                                ForEach(objects) { object in
                                    Button { workspace.showObject(object) } label: {
                                        Label("\(object.schema).\(object.name)", systemImage: object.icon)
                                            .lineLimit(1).help("Abrir consulta para \(object.schema).\(object.name)")
                                    }.buttonStyle(.plain)
                                        .contextMenu {
                                            Button("Abrir consulta") { workspace.showObject(object) }
                                            Button("Consultar colunas") { workspace.showColumns(object) }
                                        }
                                }
                                if objects.isEmpty { Text(workspace.loadingObjects ? "Carregando…" : "Nenhum objeto").foregroundStyle(.tertiary).font(.caption) }
                            }
                        }
                    }.listStyle(.sidebar)
                        .searchable(text: $workspace.search, placement: .sidebar, prompt: "Buscar objeto")
                } else {
                    ContentUnavailableView("Seu banco, no Mac", systemImage: "externaldrive.badge.plus", description: Text("Conecte ao SQL Server para explorar seus bancos."))
                    Spacer()
                }
                Divider()
                HStack {
                    Label("SQL Server", systemImage: "cylinder.split.1x2").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { Task { await workspace.refreshExplorer() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help("Atualizar explorador").disabled(!workspace.connected || workspace.loadingObjects)
                }.padding(12)
            }.navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 360)
        } detail: {
            VStack(spacing: 0) {
                if let notice = workspace.storageNotice {
                    HStack {
                        Label(notice, systemImage: "exclamationmark.triangle").font(.caption)
                        Spacer()
                        Button("Fechar aviso") { workspace.storageNotice = nil }.buttonStyle(.borderless)
                    }.padding(9).background(.orange.opacity(0.15))
                }
                queryTabs
                HSplitView {
                    VStack(spacing: 0) {
                        editorBar
                        VSplitView {
                            SQLEditor(text: workspace.sqlBinding, selection: workspace.selectionBinding, identity: workspace.activeID)
                                .frame(minHeight: 170)
                            resultsPane.frame(minHeight: 160, idealHeight: 280)
                        }
                    }
                }
                statusBar
            }.frame(minWidth: 630)
        }
        .navigationTitle("SQLGarden")
        .navigationSubtitle(workspace.connected ? "\(workspace.profile.host) · \(workspace.database)" : "Workspace SQL")
        .toolbar {
            ToolbarItemGroup {
                Button { workspace.newQuery() } label: { Label("Nova consulta", systemImage: "square.and.pencil") }.help("Nova consulta · ⌘N")
                Button { workspace.openQuery() } label: { Label("Abrir", systemImage: "folder") }.help("Abrir SQL · ⌘O")
                Button { workspace.saveQuery() } label: { Label("Salvar", systemImage: "square.and.arrow.down") }.help("Salvar SQL · ⌘S")
            }
            ToolbarItem {
                Button { workspace.historySheet = true } label: { Label("Histórico", systemImage: "clock.arrow.circlepath") }
            }
            ToolbarItem {
                Button { workspace.dockerSheet = true } label: { Label("Docker", systemImage: "shippingbox") }
            }
            ToolbarItem {
                Button { workspace.connectionSheet = true } label: {
                    Label(workspace.connected ? "Conexão" : "Conectar", systemImage: "network")
                }.disabled(workspace.executing || workspace.connecting)
            }
        }
        .sheet(isPresented: $workspace.connectionSheet) { ConnectionView() }
        .sheet(isPresented: $workspace.dockerSheet) { DockerView() }
        .sheet(isPresented: $workspace.historySheet) { HistoryView() }
        .sheet(isPresented: $workspace.feedbackSheet) { FeedbackView() }
        .alert("Não foi possível concluir", isPresented: Binding(get: { workspace.error != nil && !workspace.connectionSheet && !workspace.dockerSheet && !workspace.historySheet && !workspace.feedbackSheet }, set: { if !$0 { workspace.error = nil } })) {
            Button("OK") { workspace.error = nil }
        } message: { Text(workspace.error ?? "") }
        .onChange(of: workspace.activeID) { _, _ in selectedResult = 0 }
        .onChange(of: workspace.active.response.tables.first?.id) { _, _ in selectedResult = 0 }
    }
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SQLGardenLogo().frame(maxWidth: 230).frame(height: 70)
            HStack(spacing: 5) {
                Circle().fill(workspace.connected ? .green : .secondary).frame(width: 6, height: 6)
                Text(workspace.connected ? workspace.profile.name : "Desconectado")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
    }
    private var queryTabs: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(workspace.documents) { doc in
                        HStack(spacing: 8) {
                            Button { workspace.activeID = doc.id } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text").foregroundStyle(.secondary)
                                    Text(doc.title).lineLimit(1)
                                    if doc.dirty { Circle().frame(width: 5, height: 5).foregroundStyle(.secondary) }
                                }
                            }.buttonStyle(.plain)
                            Button { workspace.closeQuery(doc.id) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)) }
                                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(workspace.executing)
                        }.padding(.horizontal, 12).padding(.vertical, 10)
                            .background(workspace.activeID == doc.id ? Color(nsColor: .textBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }
                }.padding(6)
            }
            Button { workspace.newQuery() } label: { Image(systemName: "plus") }.buttonStyle(.borderless).padding(.horizontal, 12)
        }.background(.bar)
    }
    private var editorBar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(workspace.databases, id: \.self) { name in
                    Button(name) { Task { await workspace.selectDatabase(name) } }
                }
            } label: { Label(workspace.database, systemImage: "externaldrive") }
                .menuStyle(.borderlessButton).fixedSize().disabled(!workspace.connected || workspace.executing)
            Text("T-SQL").font(.caption).foregroundStyle(.tertiary)
            Menu {
                Button("Buscar / substituir…") {
                    let item = NSMenuItem(); item.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
                    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
                }
                Button("Ir para linha…") { NSApp.sendAction(#selector(SQLTextView.goToSQLLine(_:)), to: nil, from: nil) }
                Button("Comentar / descomentar") { NSApp.sendAction(#selector(SQLTextView.toggleSQLComment(_:)), to: nil, from: nil) }
                Button("Indentar") { NSApp.sendAction(#selector(SQLTextView.indentSQL(_:)), to: nil, from: nil) }
                Button("Desindentar") { NSApp.sendAction(#selector(SQLTextView.unindentSQL(_:)), to: nil, from: nil) }
            } label: { Image(systemName: "textformat") }.menuStyle(.borderlessButton).fixedSize().help("Ferramentas de edição")
            Spacer()
            if workspace.executing {
                ProgressView().controlSize(.small)
                Button { workspace.cancel() } label: { Label("Parar", systemImage: "stop.fill") }.tint(.red)
            } else {
                Button { Task { await workspace.execute() } } label: { Label("Executar", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent).tint(.accentColor).disabled(!workspace.connected)
                    .help("Executar seleção ou consulta inteira · ⌘↩")
            }
        }.padding(.horizontal, 16).padding(.vertical, 9).background(.bar)
    }
    private var resultsPane: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Painel", selection: $workspace.resultTab) {
                    Text("Resultados").tag("results"); Text("Mensagens").tag("messages")
                }.pickerStyle(.segmented).frame(width: 235)
                Spacer()
                if !workspace.active.response.success { Label("Falha na execução", systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red) }
                if workspace.resultTab == "results", let table = currentTable {
                    Button { workspace.export(table) } label: { Label("CSV", systemImage: "square.and.arrow.up") }.buttonStyle(.borderless)
                }
            }.padding(10).background(.bar)
            Divider()
            if workspace.resultTab == "messages" {
                ScrollView {
                    Text(messageText).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let table = currentTable {
                if workspace.active.response.tables.count > 1 {
                    Picker("Resultado", selection: $selectedResult) {
                        ForEach(Array(workspace.active.response.tables.enumerated()), id: \.element.id) { index, _ in Text("Resultado \(index + 1)").tag(index) }
                    }.pickerStyle(.menu).padding(.horizontal, 12).padding(.vertical, 5)
                }
                ResultsGrid(result: table).id(table.id)
                HStack {
                    Text("\(table.rows.count) linhas · \(table.columns.count) colunas")
                    if table.truncated { Label("Exibição limitada", systemImage: "info.circle").foregroundStyle(.orange) }
                    Spacer(); Text("CSV exporta todas as linhas carregadas")
                }.font(.caption).foregroundStyle(.secondary).padding(8)
            } else {
                ContentUnavailableView("Pronto para consultar", systemImage: "tablecells", description: Text("Os resultados aparecem aqui após executar uma consulta."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    private var currentTable: ResultSet? {
        let tables = workspace.active.response.tables
        return tables.indices.contains(selectedResult) ? tables[selectedResult] : tables.first
    }
    private var messageText: String {
        let response = workspace.active.response
        var lines: [String] = []
        if workspace.active.elapsed > 0 { lines.append(response.success ? "Execução concluída." : "Execução interrompida com erro.") }
        for set in response.sets where set.affectedRows >= 0 && set.columns.isEmpty { lines.append("\(set.affectedRows) linha(s) afetada(s).") }
        if !response.messages.isEmpty { lines.append(response.messages) }
        return lines.isEmpty ? "As mensagens do SQL Server aparecem aqui." : lines.joined(separator: "\n")
    }
    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(workspace.connected ? .green : .secondary).frame(width: 6, height: 6)
            Text(workspace.connected ? "\(workspace.profile.host):\(String(workspace.profile.port)) · \(workspace.database)" : "Conecte ao SQL Server para começar")
                .lineLimit(1).textSelection(.enabled)
            Spacer()
            Text("Sessão compartilhada entre abas").help("USE, transações e tabelas temporárias pertencem à mesma sessão. O explorador usa outra conexão.")
            if workspace.connected {
                if let count = workspace.transactionCount {
                    Label(count > 0 ? "Transação aberta (\(count))" : "Sem transação aberta", systemImage: count > 0 ? "exclamationmark.circle" : "checkmark.circle")
                        .foregroundStyle(count > 0 ? .orange : .secondary)
                        .help("Confirmado em \(workspace.sessionCheckedAt?.formatted() ?? "") · sessão \(workspace.sessionID ?? "?") · XACT_STATE \(workspace.transactionState ?? 0)")
                }
                Button(workspace.transactionCount == nil ? "Verificar transação" : "Verificar novamente") { Task { await workspace.inspectSession() } }
                    .buttonStyle(.borderless).disabled(workspace.executing)
                    .help("Lê XACT_STATE() antes de consultar @@SPID, @@TRANCOUNT e DB_NAME() na sessão. Não faz COMMIT/ROLLBACK. Como qualquer SELECT, altera @@ROWCOUNT e @@ERROR.")
            }
            Divider().frame(height: 12)
            Text(String(format: "%.2f s", workspace.active.elapsed))
            Text("UTF-8").padding(.leading, 8)
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 8).background(.bar)
    }
}
