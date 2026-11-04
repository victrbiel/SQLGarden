import SwiftUI
import StudioCore

@MainActor struct ContentView: View {
    @EnvironmentObject var workspace: Workspace
    @AppStorage("workspace.showResults") private var showResults = true
    private var selectedResult: Int {
        get { workspace.active.selectedResultIndex }
        nonmutating set { workspace.documents[workspace.activeIndex].resultSelection = newValue }
    }
    @State private var sidebar: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebar) {
            VStack(spacing: 0) {
                connectionCard
                Divider()
                if workspace.connected {
                    DatabaseExplorer()
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
                if let notice = workspace.sessionNotice {
                    HStack {
                        Label(notice, systemImage: "exclamationmark.triangle").font(.caption)
                        Spacer()
                        if workspace.connected { Button("Verificar sessão") { Task { await workspace.inspectSession() } }.disabled(workspace.executing) }
                    }.padding(9).background(.orange.opacity(0.15))
                }
                queryTabs
                editorBar
                VSplitView {
                    SQLEditor(text: workspace.sqlBinding, selection: workspace.selectionBinding, identity: workspace.activeID)
                        .frame(minHeight: 170)
                    if showResults { resultsPane.frame(minHeight: 160, idealHeight: 290) }
                }
                statusBar
            }.frame(minWidth: 630).disabled(workspace.fileDialogOpen)
        }
        .navigationTitle(workspace.active.title)
        .navigationSubtitle(workspace.connected ? "\(workspace.profile.host) · \(workspace.database)" : "Workspace SQL")
        .toolbar {
            ToolbarItemGroup {
                Button { workspace.newQuery() } label: { Label("Nova consulta", systemImage: "square.and.pencil") }.help("Nova consulta · ⌘N")
                Button { Task { await workspace.openQuery() } } label: { Label("Abrir", systemImage: "folder") }.help("Abrir SQL · ⌘O")
                Button { Task { await workspace.saveQuery() } } label: { Label("Salvar", systemImage: "square.and.arrow.down") }.help("Salvar SQL · ⌘S")
            }
            ToolbarItem {
                Button { workspace.historySheet = true } label: { Label("Histórico", systemImage: "clock.arrow.circlepath") }
            }
            ToolbarItem {
                Button { showResults.toggle() } label: { Label("Resultados", systemImage: "rectangle.bottomthird.inset.filled") }
                    .help("Mostrar ou ocultar resultados · ⇧⌘R")
                    .accessibilityValue(showResults ? "Visível" : "Oculto")
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
        .onChange(of: workspace.executing) { _, running in if running { showResults = true } }
    }
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SQLGardenLogo().frame(width: 170, height: 48)
            HStack(spacing: 9) {
                Image(systemName: workspace.connected ? "externaldrive.connected.to.line.below" : "externaldrive")
                    .font(.title3).foregroundStyle(workspace.connected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workspace.connected ? workspace.profile.name : "Nenhuma conexão")
                        .font(.headline).lineLimit(1)
                    Text(workspace.connected ? "\(workspace.profile.host):\(workspace.profile.port)" : "Conecte seu SQL Server")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            if !workspace.connected {
                Button("Conectar ao servidor…") { workspace.connectionSheet = true }
                    .buttonStyle(.borderedProminent).disabled(workspace.connecting)
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
                                    Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundStyle(workspace.activeID == doc.id ? Color.accentColor : .secondary)
                                    Text(doc.title).lineLimit(1)
                                    if doc.dirty { Circle().frame(width: 5, height: 5).foregroundStyle(.secondary) }
                                }
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(workspace.activeID == doc.id ? [.isSelected] : [])
                                .help(doc.url?.path ?? doc.title)
                            Button { Task { await workspace.closeQuery(doc.id) } } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)) }
                                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(workspace.executing)
                                .accessibilityLabel("Fechar \(doc.title)")
                        }.padding(.horizontal, 12).padding(.vertical, 10)
                            .background(workspace.activeID == doc.id ? Color(nsColor: .textBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(alignment: .bottom) {
                                if workspace.activeID == doc.id { Capsule().fill(Color.accentColor).frame(height: 2).padding(.horizontal, 12) }
                            }
                    }
                }.padding(6)
            }
            Button { workspace.newQuery() } label: { Image(systemName: "plus") }.buttonStyle(.borderless).padding(.horizontal, 12).help("Nova consulta · ⌘N").accessibilityLabel("Nova consulta")
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
            Text("T-SQL").font(.caption.monospaced()).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(workspace.active.selection.length > 0 ? "Executar seleção" : "Executar documento")
                .font(.caption).foregroundStyle(.secondary)
                .help("Apenas o texto selecionado é executado quando há uma seleção válida.")
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
                }.pickerStyle(.segmented).frame(width: 240)
                Spacer()
                if !workspace.active.response.success { Label("Falha na execução", systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red) }
                if workspace.resultTab == "results", let table = currentTable {
                    Button { Task { await workspace.export(table) } } label: { Label("Exportar CSV", systemImage: "square.and.arrow.up") }.buttonStyle(.borderless)
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
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(workspace.active.response.tables.enumerated()), id: \.element.id) { index, result in
                                Button { selectedResult = index } label: {
                                    Text("Resultado \(index + 1) · \(result.rows.count) linhas")
                                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(selectedResult == index ? Color.accentColor.opacity(0.16) : Color.clear, in: Capsule())
                                }.buttonStyle(.plain)
                                    .accessibilityAddTraits(selectedResult == index ? [.isSelected] : [])
                            }
                        }.padding(.horizontal, 12).padding(.vertical, 5)
                    }
                }
                ResultsGrid(result: table).id(table.id)
                HStack {
                    Text("\(table.rows.count) linhas · \(table.columns.count) colunas")
                    if table.truncated { Label("Exibição limitada", systemImage: "info.circle").foregroundStyle(.orange) }
                    Spacer(); Text("CSV exporta todas as linhas carregadas")
                }.font(.caption).foregroundStyle(.secondary).padding(8)
            } else {
                ContentUnavailableView {
                    Label(workspace.executing ? "Executando consulta…" : "Seu próximo resultado começa aqui", systemImage: workspace.executing ? "hourglass" : "tablecells")
                } description: {
                    Text(workspace.connected ? "Escreva T-SQL no editor e use ⌘Return. Se houver seleção, apenas ela será executada." : "Conecte ao servidor. Seus rascunhos continuam disponíveis no editor.")
                } actions: {
                    if !workspace.connected {
                        Button("Conectar…") { workspace.connectionSheet = true }.buttonStyle(.borderedProminent)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Image(systemName: "link").accessibilityLabel("Sessão compartilhada entre abas").help("USE, transações e tabelas temporárias pertencem à mesma sessão. O explorador usa outra conexão.")
            if workspace.connected {
                if let count = workspace.transactionCount {
                    Label(count > 0 ? "Transação aberta (\(count))" : "Sem transação na última verificação", systemImage: count > 0 ? "exclamationmark.circle" : "checkmark.circle")
                        .foregroundStyle(count > 0 ? .orange : .secondary)
                        .help("Confirmado em \(workspace.sessionCheckedAt?.formatted() ?? "") · sessão \(workspace.sessionID ?? "?") · XACT_STATE \(workspace.transactionState ?? 0)")
                }
                Button(workspace.transactionCount == nil ? "Verificar sessão" : "Atualizar estado") { Task { await workspace.inspectSession() } }
                    .buttonStyle(.borderless).disabled(workspace.executing)
                    .help("Lê XACT_STATE() antes de consultar @@SPID, @@TRANCOUNT e DB_NAME() na sessão. Não faz COMMIT/ROLLBACK. Como qualquer SELECT, altera @@ROWCOUNT e @@ERROR.")
            }
            Divider().frame(height: 12)
            Text(String(format: "%.2f s", workspace.active.elapsed))
            Text("UTF-8").padding(.leading, 8)
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 8).background(.bar)
    }
}
