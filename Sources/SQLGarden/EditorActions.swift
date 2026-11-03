import AppKit
import StudioCore

final class SQLTextView: NSTextView {
    override func complete(_ sender: Any?) {} // No autocomplete in 0.3.
    @objc func toggleSQLComment(_ sender: Any?) { transform(.comment) }
    @objc func indentSQL(_ sender: Any?) { transform(.indent) }
    @objc func unindentSQL(_ sender: Any?) { transform(.unindent) }
    private func transform(_ operation: EditorTools.Operation) {
        let result = EditorTools.transform(string, selection: selectedRange(), operation: operation)
        guard shouldChangeText(in: result.range, replacementString: result.replacement) else { return }
        textStorage?.replaceCharacters(in: result.range, with: result.replacement)
        didChangeText()
        setSelectedRange(NSRange(location: result.range.location, length: (result.replacement as NSString).length))
        undoManager?.setActionName("Editar linhas SQL")
    }
    override func insertTab(_ sender: Any?) {
        if selectedRange().length > 0 { transform(.indent) } else { insertText("    ", replacementRange: selectedRange()) }
    }
    override func insertBacktab(_ sender: Any?) { transform(.unindent) }
    @objc func goToSQLLine(_ sender: Any?) {
        let alert = NSAlert(); alert.messageText = "Ir para linha"
        let field = NSTextField(string: "1"); field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field; alert.addButton(withTitle: "Ir"); alert.addButton(withTitle: "Cancelar")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let line = Int(field.stringValue), let offset = EditorTools.location(ofLine: line, in: string) else { NSSound.beep(); return }
        window?.makeFirstResponder(self)
        setSelectedRange(NSRange(location: offset, length: 0)); scrollRangeToVisible(selectedRange())
    }
}
final class LineNumberRuler: NSRulerView {
    weak var editor: NSTextView?
    private var starts = [0]
    override var isFlipped: Bool { true }
    init(scroll: NSScrollView, editor: NSTextView) {
        self.editor = editor
        super.init(scrollView: scroll, orientation: .verticalRuler)
        clientView = editor; ruleThickness = 52
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc func refresh() { needsDisplay = true }
    func updateLines() {
        guard let editor else { return }
        let ns = editor.string as NSString
        starts = [0]; var offset = 0
        while offset < ns.length {
            offset = NSMaxRange(ns.lineRange(for: NSRange(location: offset, length: 0)))
            if offset < ns.length || (offset == ns.length && (editor.string.hasSuffix("\n") || editor.string.hasSuffix("\r"))) { starts.append(offset) }
        }
        ruleThickness = CGFloat(max(52, String(starts.count).count * 8 + 22)); needsDisplay = true
    }
    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        let glyphs = layout.glyphRange(forBoundingRect: editor.visibleRect.offsetBy(dx: -editor.textContainerOrigin.x, dy: -editor.textContainerOrigin.y), in: container)
        let firstChar = glyphs.location < layout.numberOfGlyphs ? layout.characterIndexForGlyph(at: glyphs.location) : (editor.string as NSString).length
        let firstLine = starts.lastIndex(where: { $0 <= firstChar }) ?? 0
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]
        for index in firstLine..<starts.count {
            let offset = starts[index]
            let lineRect: NSRect
            if offset < (editor.string as NSString).length {
                lineRect = layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: offset), effectiveRange: nil)
            } else { lineRect = layout.extraLineFragmentRect }
            let point = convert(NSPoint(x: 0, y: lineRect.minY + editor.textContainerOrigin.y), from: editor)
            if point.y > bounds.maxY { break }
            let label = String(index + 1) as NSString
            label.draw(at: NSPoint(x: ruleThickness - label.size(withAttributes: attributes).width - 10, y: point.y + 1), withAttributes: attributes)
        }
    }
}
