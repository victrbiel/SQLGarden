import AppKit
import SwiftUI

struct SQLEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var identity: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        scroll.borderType = .noBorder; scroll.autohidesScrollers = true
        let editor = SQLTextView(frame: .zero)
        editor.isRichText = false; editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false; editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false; editor.isContinuousSpellCheckingEnabled = false
        editor.isAutomaticTextCompletionEnabled = false
        editor.isGrammarCheckingEnabled = false; editor.isAutomaticLinkDetectionEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        editor.textContainerInset = NSSize(width: 20, height: 18)
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = false
        editor.usesFindBar = true; editor.isIncrementalSearchingEnabled = true
        editor.allowsUndo = true; editor.delegate = context.coordinator
        editor.backgroundColor = .textBackgroundColor
        scroll.documentView = editor
        let ruler = LineNumberRuler(scroll: scroll, editor: editor)
        scroll.verticalRulerView = ruler; scroll.hasVerticalRuler = true; scroll.rulersVisible = true
        context.coordinator.ruler = ruler
        context.coordinator.editor = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if coordinator.identity != identity {
            coordinator.identity = identity
            editor.undoManager?.removeAllActions()
            coordinator.updating = true; editor.string = text
            let length = (text as NSString).length
            let location = min(selection.location, length)
            editor.setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
            coordinator.updating = false; coordinator.highlight()
        } else if !editor.hasMarkedText(), !editor.string.utf8.elementsEqual(text.utf8) {
            coordinator.updating = true; editor.string = text; coordinator.updating = false
            coordinator.highlight()
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLEditor
        var identity: UUID?
        weak var editor: NSTextView?
        weak var ruler: LineNumberRuler?
        var updating = false
        init(_ parent: SQLEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard !updating, let editor, !editor.hasMarkedText() else { return }
            parent.text = editor.string; parent.selection = editor.selectedRange()
            highlight()
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !updating, let editor, !editor.hasMarkedText() else { return }
            parent.selection = editor.selectedRange()
        }
        func highlight() {
            guard let editor, !editor.hasMarkedText(), let layout = editor.layoutManager else { return }
            ruler?.updateLines()
            let source = editor.string
            let range = NSRange(location: 0, length: (source as NSString).length)
            updating = true; defer { updating = false }
            layout.addTemporaryAttribute(.foregroundColor, value: NSColor.labelColor, forCharacterRange: range)
            // Keep long scripts editable. Parsing execution is independent of
            // this intentionally lightweight visual highlighter.
            guard range.length < 200_000 else { return }
            let patterns: [(String, NSColor)] = [
                (#"(?i)\b(SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AS|AND|OR|NOT|NULL|IS|IN|EXISTS|BETWEEN|LIKE|ORDER|BY|GROUP|HAVING|TOP|DISTINCT|UNION|ALL|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|ALTER|DROP|TABLE|DATABASE|VIEW|PROCEDURE|PROC|TRIGGER|FUNCTION|BEGIN|END|EXEC|EXECUTE|DECLARE|IF|ELSE|RETURN|GO|USE|PRINT|TRAN|TRANSACTION|COMMIT|ROLLBACK|TRY|CATCH|THROW|IDENTITY|PRIMARY|KEY|FOREIGN|REFERENCES|DEFAULT|CONSTRAINT|INT|VARCHAR|NVARCHAR|DECIMAL|DATETIME|BIT)\b"#, .systemPurple),
                (#"\b[0-9]+(?:\.[0-9]+)?\b"#, .systemOrange),
                (#"(?s)'(?:''|[^'])*'|\[(?:\]\]|[^\]])*\]|\"(?:\"\"|[^\"])*\"|--[^\n]*|/\*.*?\*/"#, .systemGreen)
            ]
            for (pattern, color) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                for match in regex.matches(in: source, range: range) {
                    let fragment = (source as NSString).substring(with: match.range)
                    let actual: NSColor = fragment.hasPrefix("--") || fragment.hasPrefix("/*") ? .secondaryLabelColor : color
                    layout.addTemporaryAttribute(.foregroundColor, value: actual, forCharacterRange: match.range)
                }
            }
        }
    }
}
