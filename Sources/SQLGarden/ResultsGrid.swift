import AppKit
import SwiftUI
import StudioCore

struct InspectedCell: Identifiable {
    let id = UUID()
    let column: String
    let value: String?
}
struct CellSelection {
    var anchorRow = 0; var anchorColumn = 0
    var row = 0; var column = 0
    var all = false; var valid = false
    func rows(count: Int) -> IndexSet {
        guard valid, count > 0 else { return [] }
        return all ? IndexSet(integersIn: 0..<count) : IndexSet(integersIn: max(0, min(row, anchorRow))...min(count - 1, max(row, anchorRow)))
    }
    func columns(count: Int) -> IndexSet {
        guard valid, count > 0 else { return [] }
        return all ? IndexSet(integersIn: 0..<count) : IndexSet(integersIn: max(0, min(column, anchorColumn))...min(count - 1, max(column, anchorColumn)))
    }
}
final class ResultTableView: NSTableView {
    var choose: ((Int, Int, Bool) -> Void)?
    var copyValue: ((Bool, Bool) -> String)?
    var inspect: (() -> Void)?
    var selectEverything: (() -> Void)?
    var move: ((UInt16, Bool) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point); let column = column(at: point)
        guard row >= 0, column >= 0 else { return }
        window?.makeFirstResponder(self)
        choose?(row, column, event.modifierFlags.contains(.shift))
        if event.clickCount == 2 { inspect?() }
    }
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point); let column = column(at: point)
        if row >= 0, column >= 0 { choose?(row, column, event.modifierFlags.contains(.shift)) }
        super.rightMouseDown(with: event)
    }
    override func selectAll(_ sender: Any?) { selectEverything?() }
    @objc func copy(_ sender: Any?) { copyToPasteboard(headers: false, rows: false) }
    @objc func copyWithHeaders(_ sender: Any?) { copyToPasteboard(headers: true, rows: false) }
    @objc func copyCompleteRows(_ sender: Any?) { copyToPasteboard(headers: true, rows: true) }
    @objc func inspectCell(_ sender: Any?) { inspect?() }
    func copyToPasteboard(headers: Bool, rows: Bool) {
        guard let text = copyValue?(headers, rows), !text.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            copyToPasteboard(headers: event.modifierFlags.contains(.shift), rows: false)
        } else if event.keyCode == 36 { inspect?() }
        else if [123, 124, 125, 126].contains(event.keyCode) { move?(event.keyCode, event.modifierFlags.contains(.shift)) }
        else { super.keyDown(with: event) }
    }
}
struct ResultsGrid: View {
    let result: ResultSet
    @State private var search = ""
    @State private var inspected: InspectedCell?
    private var rows: [[String?]] {
        search.isEmpty ? result.rows : result.rows.filter { row in row.contains { ($0 ?? "NULL").localizedCaseInsensitiveContains(search) } }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Buscar nas linhas carregadas", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 330)
                if !search.isEmpty { Button("Limpar") { search = "" }.buttonStyle(.borderless) }
                Spacer()
                Text("\(rows.count) de \(result.rows.count) linhas carregadas").font(.caption).foregroundStyle(.secondary)
            }.padding(8)
            GridTable(columns: result.columns, rows: rows) { inspected = $0 }
            Text("Clique: célula · ⇧clique: intervalo · ⌘C: copiar · ⇧⌘C: com cabeçalhos · Duplo clique: conteúdo")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(7)
        }.sheet(item: $inspected) { cell in
            CellInspector(cell: cell)
        }
    }
}
struct CellInspector: View {
    let cell: InspectedCell
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(cell.column).font(.title3.bold()).lineLimit(2)
                Spacer(); Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(cell.value == nil ? "NULL (ausência de valor)" : "Texto · \(cell.value!.utf8.count) bytes carregados")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView([.horizontal, .vertical]) {
                Text(cell.value ?? "NULL").font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading).padding(8)
            }.background(Color(nsColor: .textBackgroundColor))
            HStack {
                Text("Exibe o conteúdo recebido. Limites do driver/resultado continuam valendo.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Copiar conteúdo") {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cell.value ?? "NULL", forType: .string)
                }
            }
        }.padding(20).frame(width: 720, height: 480)
    }
}
struct GridTable: NSViewRepresentable {
    let columns: [String]
    let rows: [[String?]]
    let onInspect: (InspectedCell) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let table = ResultTableView()
        table.delegate = context.coordinator; table.dataSource = context.coordinator
        table.columnAutoresizingStyle = .noColumnAutoresizing; table.rowHeight = 26
        table.gridStyleMask = [.solidVerticalGridLineMask]; table.selectionHighlightStyle = .none
        scroll.documentView = table
        let coordinator = context.coordinator
        table.choose = { [weak coordinator, weak table] row, column, extend in
            guard let coordinator else { return }
            if !extend || !coordinator.selection.valid { coordinator.selection.anchorRow = row; coordinator.selection.anchorColumn = column }
            coordinator.selection.row = row; coordinator.selection.column = column
            coordinator.selection.all = false; coordinator.selection.valid = true; table?.reloadData()
        }
        table.copyValue = { [weak coordinator] headers, completeRows in
            guard let coordinator else { return "" }
            return GridTools.tsv(columns: coordinator.columns, rows: coordinator.rows,
                columnIndexes: completeRows ? IndexSet(integersIn: 0..<coordinator.columns.count) : coordinator.selection.columns(count: coordinator.columns.count),
                rowIndexes: coordinator.selection.rows(count: coordinator.rows.count), headers: headers)
        }
        table.inspect = { [weak coordinator] in
            guard let c = coordinator, c.selection.valid, c.rows.indices.contains(c.selection.row), c.columns.indices.contains(c.selection.column) else { return }
            let row = c.rows[c.selection.row]
            c.onInspect?(InspectedCell(column: c.columns[c.selection.column], value: row.indices.contains(c.selection.column) ? row[c.selection.column] : nil))
        }
        table.selectEverything = { [weak coordinator, weak table] in
            coordinator?.selection.valid = true; coordinator?.selection.all = true; table?.reloadData()
        }
        table.move = { [weak coordinator, weak table] key, extend in
            guard let c = coordinator, !c.rows.isEmpty, !c.columns.isEmpty else { return }
            c.selection.valid = true; c.selection.all = false
            c.selection.row = min(c.rows.count - 1, max(0, c.selection.row + (key == 125 ? 1 : key == 126 ? -1 : 0)))
            c.selection.column = min(c.columns.count - 1, max(0, c.selection.column + (key == 124 ? 1 : key == 123 ? -1 : 0)))
            if !extend { c.selection.anchorRow = c.selection.row; c.selection.anchorColumn = c.selection.column }
            table?.reloadData(); table?.scrollRowToVisible(c.selection.row); table?.scrollColumnToVisible(c.selection.column)
        }
        let menu = NSMenu()
        for (title, action) in [("Copiar células", #selector(ResultTableView.copy(_:))), ("Copiar com cabeçalhos", #selector(ResultTableView.copyWithHeaders(_:))), ("Copiar linhas completas com cabeçalhos", #selector(ResultTableView.copyCompleteRows(_:))), ("Ver conteúdo da célula", #selector(ResultTableView.inspectCell(_:)))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = table; menu.addItem(item)
        }
        table.menu = menu
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? ResultTableView else { return }
        let coordinator = context.coordinator
        coordinator.onInspect = onInspect
        if coordinator.columns != columns {
            for column in table.tableColumns { table.removeTableColumn(column) }
            for (index, name) in columns.enumerated() {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
                column.title = name.isEmpty ? "(sem nome)" : name
                column.width = CGFloat(min(380, max(130, name.count * 8 + 24))); column.minWidth = 70
                table.addTableColumn(column)
            }
        }
        if coordinator.columns != columns || coordinator.rows != rows {
            coordinator.columns = columns; coordinator.rows = rows; coordinator.selection = CellSelection(); table.reloadData()
        }
    }
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var columns: [String] = []; var rows: [[String?]] = []
        var selection = CellSelection()
        var onInspect: ((InspectedCell) -> Void)?
        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard rows.indices.contains(row), let raw = tableColumn?.identifier.rawValue, let column = Int(raw) else { return nil }
            let id = NSUserInterfaceItemIdentifier("cell")
            let field = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField) ?? NSTextField(labelWithString: "")
            field.identifier = id; field.font = .monospacedSystemFont(ofSize: 12, weight: .regular); field.lineBreakMode = .byTruncatingTail
            let value = rows[row].indices.contains(column) ? rows[row][column] : nil
            let selected = selection.rows(count: rows.count).contains(row) && selection.columns(count: columns.count).contains(column)
            field.stringValue = value ?? "NULL"; field.drawsBackground = selected
            field.backgroundColor = .selectedContentBackgroundColor
            field.textColor = selected ? .white : value == nil ? .tertiaryLabelColor : .labelColor
            field.toolTip = value ?? "NULL (ausência de valor)"
            return field
        }
    }
}
