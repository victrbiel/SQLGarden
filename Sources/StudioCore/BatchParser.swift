import Foundation

/// GO is a client-side batch separator, never sent to SQL Server. Recognizes
/// strings, quoted/bracketed identifiers and nested block comments across lines.
public enum BatchParser {
    private enum State { case normal, string, quoted, bracket, comment(Int) }
    public struct Batch: Equatable, Sendable {
        public let sql: String
        public let startLine: Int
        public let repetitions: Int
    }
    public static func split(_ text: String) throws -> [Batch] {
        guard !text.utf8.contains(0) else {
            throw StudioError.message("O SQL contém o caractere NUL (U+0000). Remova-o antes de executar. Nenhum lote foi enviado ao servidor.")
        }
        // Scan scalar boundaries, never grapheme clusters: a combining mark can
        // belong to an apostrophe Character, but cannot change SQL punctuation.
        // Keep each original terminator, including CR and CRLF inside literals.
        let scalars = text.unicodeScalars
        var lines: [(String, String)] = []
        var start = scalars.startIndex
        var cursor = start
        while cursor < scalars.endIndex {
            let scalar = scalars[cursor]
            if scalar == "\r" || scalar == "\n" {
                let content = String(scalars[start..<cursor])
                let endStart = cursor
                scalars.formIndex(after: &cursor)
                if scalar == "\r", cursor < scalars.endIndex, scalars[cursor] == "\n" { scalars.formIndex(after: &cursor) }
                lines.append((content, String(scalars[endStart..<cursor])))
                start = cursor
            } else { scalars.formIndex(after: &cursor) }
        }
        lines.append((String(scalars[start..<scalars.endIndex]), ""))
        var state = State.normal
        var pending: [String] = []
        var output: [Batch] = []
        var startLine = 1
        for (offset, original) in lines.enumerated() {
            let (line, terminator) = original
            let lineNumber = offset + 1
            if case .normal = state {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(":") || trimmed.hasPrefix("!!") {
                    throw StudioError.message("Linha \(lineNumber): comandos de modo SQLCMD não são suportados nesta versão.")
                }
                let directive = trimmed.components(separatedBy: "--")[0].trimmingCharacters(in: .whitespaces)
                let parts = directive.split(whereSeparator: { $0.isWhitespace })
                if parts.first?.uppercased() == "GO" {
                    guard parts.count <= 2, let repeatCount = parts.count == 2 ? Int(parts[1]) : 1,
                          (1...100).contains(repeatCount) else {
                        throw StudioError.message("Linha \(lineNumber): use GO ou GO seguido de um número entre 1 e 100.")
                    }
                    let sql = pending.joined()
                    if !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { output.append(Batch(sql: sql, startLine: startLine, repetitions: repeatCount)) }
                    pending = []; startLine = lineNumber + 1
                    continue
                }
            }
            pending.append(line + terminator)
            let chars = Array(line.unicodeScalars)
            var i = 0
            while i < chars.count {
                let c = chars[i]
                let next: Unicode.Scalar? = i + 1 < chars.count ? chars[i + 1] : nil
                switch state {
                case .normal:
                    if c == "-", next == "-" { i = chars.count; continue }
                    if c == "/", next == "*" { state = .comment(1); i += 1 }
                    else if c == "'" { state = .string }
                    else if c == "\"" { state = .quoted }
                    else if c == "[" { state = .bracket }
                case .string:
                    if c == "'" { if next == "'" { i += 1 } else { state = .normal } }
                case .quoted:
                    if c == "\"" { if next == "\"" { i += 1 } else { state = .normal } }
                case .bracket:
                    if c == "]" { if next == "]" { i += 1 } else { state = .normal } }
                case .comment(let depth):
                    if c == "/", next == "*" { state = .comment(depth + 1); i += 1 }
                    else if c == "*", next == "/" { state = depth == 1 ? .normal : .comment(depth - 1); i += 1 }
                }
                i += 1
            }
        }
        let sql = pending.joined()
        if !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { output.append(Batch(sql: sql, startLine: startLine, repetitions: 1)) }
        // Let SQL Server diagnose unclosed quotes/comments, preserving its error.
        return output
    }
}
