import AppKit
import SwiftUI
import StudioCore

private final class CopyTableView: NSTableView {
    var copyRows: (() -> String)?
    // Edit > Copy and its key equivalent are routed through the responder
    // chain before keyDown. Expose the standard action for both paths.
    @objc func copy(_ sender: Any?) {
        guard numberOfSelectedRows > 0, let value = copyRows?() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            copy(nil)
        } else { super.keyDown(with: event) }
    }
}
struct ResultsGrid: NSViewRepresentable {
    let result: ResultSet
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let table = CopyTableView()
        table.delegate = context.coordinator; table.dataSource = context.coordinator
        table.usesAlternatingRowBackgroundColors = true; table.allowsMultipleSelection = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.rowHeight = 26; table.gridStyleMask = [.solidVerticalGridLineMask]
        scroll.documentView = table
        table.copyRows = { [weak table, weak coordinator = context.coordinator] in
            guard let table, let result = coordinator?.result else { return "" }
            return table.selectedRowIndexes.compactMap { index in
                guard result.rows.indices.contains(index) else { return nil }
                return result.rows[index].map { ($0 ?? "NULL").replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\t")
            }.joined(separator: "\n")
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        guard context.coordinator.result?.id != result.id else { return }
        context.coordinator.result = result
        for column in table.tableColumns { table.removeTableColumn(column) }
        let number = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        number.title = "#"; number.width = 48; number.minWidth = 40; table.addTableColumn(number)
        for (index, name) in result.columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
            column.title = name.isEmpty ? "(sem nome)" : name
            let sample = result.rows.prefix(30).compactMap { $0.indices.contains(index) ? $0[index] : nil }.map(\.count).max() ?? 0
            column.width = CGFloat(min(380, max(130, max(name.count, sample) * 8 + 24)))
            column.minWidth = 70; table.addTableColumn(column)
        }
        table.reloadData()
    }
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var result: ResultSet?
        func numberOfRows(in tableView: NSTableView) -> Int { result?.rows.count ?? 0 }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let result, result.rows.indices.contains(row), let column = tableColumn else { return nil }
            let id = NSUserInterfaceItemIdentifier("cell")
            let field = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField) ?? NSTextField(labelWithString: "")
            field.identifier = id; field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            field.lineBreakMode = .byTruncatingTail
            var value: String?
            if column.identifier.rawValue == "row" { value = String(row + 1) }
            else if let index = Int(column.identifier.rawValue), result.rows[row].indices.contains(index) { value = result.rows[row][index] }
            field.stringValue = value ?? "NULL"
            field.textColor = value == nil ? .tertiaryLabelColor : .labelColor
            field.toolTip = value ?? "NULL"
            return field
        }
    }
}
