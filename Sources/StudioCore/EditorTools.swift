import Foundation

public enum EditorTools {
    public enum Operation { case comment, indent, unindent }
    /// Change complete selected lines; the end at the next line's start is exclusive.
    public static func transform(_ text: String, selection: NSRange, operation: Operation) -> (range: NSRange, replacement: String) {
        let source = text as NSString
        let location = min(max(0, selection.location), source.length)
        let length = min(max(0, selection.length), source.length - location)
        let last = length > 0 ? location + length - 1 : location
        let start = source.lineRange(for: NSRange(location: location, length: 0)).location
        let end = NSMaxRange(source.lineRange(for: NSRange(location: last, length: 0)))
        let range = NSRange(location: start, length: end - start)
        let block = source.substring(with: range)
        // Work on the original line endings, including CRLF.
        let regex = try! NSRegularExpression(pattern: "[^\\r\\n]*(?:\\r\\n|\\r|\\n|$)")
        let lines = regex.matches(in: block, range: NSRange(location: 0, length: (block as NSString).length))
            .filter { $0.range.length > 0 }.map { (block as NSString).substring(with: $0.range) }
        let uncomment = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
        let changed = lines.map { line -> String in
            switch operation {
            case .indent: return "    " + line
            case .unindent:
                if line.hasPrefix("\t") { return String(line.dropFirst()) }
                return String(line.dropFirst(line.prefix(4).prefix(while: { $0 == " " }).count))
            case .comment:
                let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
                let rest = line.dropFirst(leading.count)
                if rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return line }
                if uncomment { return String(leading) + rest.dropFirst(2) }
                return String(leading) + "--" + rest
            }
        }.joined()
        return (range, changed)
    }
    public static func location(ofLine line: Int, in text: String) -> Int? {
        guard line > 0 else { return nil }
        let ns = text as NSString
        var current = 1; var offset = 0
        while current < line && offset < ns.length {
            offset = NSMaxRange(ns.lineRange(for: NSRange(location: offset, length: 0))); current += 1
        }
        guard current == line else { return nil }
        if offset == ns.length && line > 1 && !text.hasSuffix("\n") && !text.hasSuffix("\r") { return nil }
        return offset
    }
}
public enum GridTools {
    public static func tsv(columns: [String], rows: [[String?]], columnIndexes: IndexSet, rowIndexes: IndexSet, headers: Bool) -> String {
        // Quote multiline/tabbed values; NULL is unquoted, literal "NULL" is quoted.
        func cell(_ value: String?) -> String {
            guard let value else { return "NULL" }
            if value == "NULL" || value.rangeOfCharacter(from: CharacterSet(charactersIn: "\t\r\n\"")) != nil {
                return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return value
        }
        var lines: [String] = []
        let indexes = columnIndexes.filter { columns.indices.contains($0) }
        if headers { lines.append(indexes.map { cell(columns[$0]) }.joined(separator: "\t")) }
        for row in rowIndexes where rows.indices.contains(row) {
            lines.append(indexes.map { cell(rows[row].indices.contains($0) ? rows[row][$0] : nil) }.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n")
    }
}
