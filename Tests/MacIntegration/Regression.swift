import Foundation
import StudioCore

struct Observation: Codable {
    let name: String
    let category: String
    let passed: Bool
    let detail: String
}
@main struct Probe {
    static func main() async {
        let client = SQLClient(); var observations: [Observation] = []
        func record(_ name: String, _ category: String, _ passed: Bool, _ detail: String) {
            observations.append(Observation(name: name, category: category, passed: passed, detail: detail))
            print("\(passed ? "PASS" : "FINDING") [\(category)] \(name): \(detail)"); fflush(stdout)
        }
        func query(_ sql: String, rows: Int = 1000, timeout: Int = 5) async throws -> SQLResponse {
            try await client.execute(sql, timeout: timeout, maxRows: rows)
        }
        do {
            var profile = ConnectionProfile()
            profile.host = "127.0.0.1"; profile.port = Int(ProcessInfo.processInfo.environment["SQLGARDEN_TEST_PORT"]!)!
            try await client.connect(profile, password: ProcessInfo.processInfo.environment["SQLGARDEN_INTEGRATION_PASSWORD"]!)
            let baseline = try await query("SELECT @@VERSION; CREATE TABLE #AuditMarker(n int);")
            record("conexao", "baseline", baseline.success, "SQL Server de QA; objetos somente em #temporárias")
            let go = try await query("SELECT N'GO' AS texto;\nGO 2 -- repeticao\n/* externo /* interno */\nGO\n*/\nSELECT N'ação 🎓' AS unicode;")
            record("GO literal/comentario/repeticao", "parser", go.success && go.tables.count == 3 && go.tables.last?.rows.first?[0] == "ação 🎓", "3 conjuntos; GO dentro de string/comentário não separou lote")
            for (name, sql) in [("GO zero", "INSERT #AuditMarker VALUES(1);\nGO 0"), ("SQLCMD", "INSERT #AuditMarker VALUES(2);\n:r arquivo.sql"), ("GO comentario bloco", "INSERT #AuditMarker VALUES(3);\nGO /*comentario*/") ] {
                do { _ = try await query(sql); record(name, "parser", false, "entrada não foi rejeitada") }
                catch { let count = try await query("SELECT COUNT(*) FROM #AuditMarker;"); record(name, "parser", count.tables[0].rows[0][0] == "0", "rejeição antes de enviar qualquer INSERT") }
            }
            let crlf = try await query("SELECT DATALENGTH(N'A\r\nB'), UNICODE(SUBSTRING(N'A\r\nB',2,1));")
            record("CRLF dentro de literal", "integridade", crlf.tables.first?.rows.first == ["8", "13"], "esperado bytes=8/codigo=13; recebido=" + String(describing: crlf.tables.first?.rows.first))
            let cr = try await query("SELECT UNICODE(SUBSTRING(N'A\rB',2,1));")
            record("CR dentro de literal", "integridade", cr.tables.first?.rows.first?[0] == "13", "esperado 13; recebido=" + String(describing: cr.tables.first?.rows.first))
            let nulSQL = "INSERT #AuditMarker VALUES(77);\nGO\n--\u{0}"

            do { let value = try await query(nulSQL); record("NUL no texto SQL", "integridade", !value.success, "sucesso=\(value.success), conjuntos=\(value.tables.count); deveria rejeitar a entrada em vez de executar prefixo") }
            catch {
                let untouched = try await query("SELECT COUNT(*) FROM #AuditMarker;")
                record("NUL no texto SQL", "integridade", untouched.tables.first?.rows.first?[0] == "0", "entrada rejeitada antes de qualquer lote; zero INSERTs")
            }
            let combining = try await query("SELECT N'\u{301}inicio\nGO\nfim' AS Literal;\nGO\nSELECT 2;")
            record("marca combinante junto à aspa", "parser", combining.success && combining.tables.count == 2 && combining.tables.first?.rows.first?[0] == "\u{301}inicio\nGO\nfim", "GO interno preservado; somente o separador externo é reconhecido")
            let exactCRLF = try await query("SELECT N'A\r\nB', N'A\rB';")
            record("CRLF e CR no texto recebido", "integridade", exactCRLF.tables.first?.rows.first == ["A\r\nB", "A\rB"], "valores recebidos preservam todos os caracteres")
            let nulLong = String(repeating: "x", count: 4093) + "\0" + "🎓" + String(repeating: "a", count: 10000) + "\0"
            let nulStream = try await query("SELECT REPLICATE(CAST(N'x' AS nvarchar(max)),4093)+NCHAR(0)+N'🎓'+REPLICATE(CAST(N'a' AS nvarchar(max)),10000)+NCHAR(0);")
            record("NUL e Unicode entre blocos ODBC", "integridade", nulStream.tables.first?.rows.first?[0] == nulLong, "NUL interno, final e Unicode de quatro bytes preservados")
            let values = try await query("SELECT CAST(NULL AS nvarchar(10)), N'', N'NULL', CAST(123456789012345678901234567890.12345678 AS decimal(38,8)), CAST(0x0001FF00 AS varbinary(max)), N'ação 🎓';")
            let row = values.tables[0].rows[0]
            record("NULL vazio decimal binario Unicode", "tipos", values.success && row == [nil,"","NULL","123456789012345678901234567890.12345678","0x0001FF00","ação 🎓"], "valores exatos=" + String(describing: row))
            let embedded = try await query("SELECT N'A'+NCHAR(0)+N'B' AS Texto, DATALENGTH(N'A'+NCHAR(0)+N'B') AS Bytes;")
            record("NUL em resultado textual", "integridade", embedded.tables.first?.rows.first?[0] == "A\u{0}B", "esperado texto com 3 caracteres / bytes=6; recebido=" + String(reflecting: embedded.tables.first?.rows.first))
            let capped = try await query("SELECT TOP (1200) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM sys.all_objects; SELECT 99;", rows: 1000)
            record("limite de linhas e resultado seguinte", "limites", capped.tables.count == 2 && capped.tables[0].rows.count == 1000 && capped.tables[0].truncated && capped.tables[1].rows[0][0] == "99", "1000 linhas, aviso de limite e segundo conjunto preservado")
            let long = try await query("SELECT REPLICATE(CAST(N'ação 🎓' AS nvarchar(max)),100000) AS Grande, 7 AS Seguinte; SELECT 8 AS Outro;")
            record("celula acima de 256 KiB", "limites", long.tables.count == 2 && long.tables[0].truncated && long.tables[0].rows[0][1] == "7" && long.tables[1].rows[0][0] == "8", "celula limitada, coluna seguinte e outro conjunto preservados; bytes=" + String(long.tables[0].rows[0][0]?.utf8.count ?? 0))
            let unicodeName = String(repeating: "界", count: 128)
            let alias = try await query("SELECT 1 AS \(SQLText.identifier(unicodeName));")
            record("nome Unicode de 128 caracteres", "tipos", alias.tables[0].columns[0] == unicodeName, "nome de coluna completo preservado")
            let columns512 = (0..<512).map { "\($0) AS C\($0)" }.joined(separator: ",")
            let limit512 = try await query("SELECT " + columns512)
            record("512 colunas", "limites", limit512.success && limit512.tables[0].columns.count == 512, "fronteira permitida")
            let limit513 = try await query("SELECT " + columns512 + ",512 AS C512")
            record("513 colunas", "limites", !limit513.success && limit513.messages.contains("512"), "limite explícito; sem travamento")
            let recovered = try await query("SELECT 123;")
            record("sessao apos limite de colunas", "recuperacao", recovered.success, "sessão continua utilizável")
            let sets64 = try await query((0..<64).map { "SELECT \($0);" }.joined(separator: "\n"))
            record("64 conjuntos", "limites", sets64.success && sets64.tables.count == 64, "fronteira permitida")
            let sets65 = try await query((0..<65).map { "SELECT \($0);" }.joined(separator: "\n"))
            record("65 conjuntos", "limites", !sets65.success && sets65.tables.count == 64 && sets65.messages.contains("64"), "limite explícito; 64 conjuntos retidos")
            let acrossGO = try await query((0..<65).map { "SELECT \($0);\nGO" }.joined(separator: "\n"))
            record("65 conjuntos em lotes GO", "limites", !acrossGO.success && acrossGO.tables.count == 64, "limite agregado preserva primeiros 64 conjuntos")
            let partial = try await query("SELECT 42; THROW 51000, N'erro proposital QA', 1;\nGO\nINSERT #AuditMarker VALUES(9);")
            let marker = try await query("SELECT COUNT(*) FROM #AuditMarker;")
            record("erro parcial impede lote seguinte", "execucao", !partial.success && partial.tables.first?.rows.first?[0] == "42" && marker.tables[0].rows[0][0] == "0", "resultado anterior retido; INSERT posterior não executado")
            let trans = try await query("BEGIN TRAN; INSERT #AuditMarker VALUES(10);\nGO\nSELECT @@TRANCOUNT;\nGO\nROLLBACK; SELECT COUNT(*) FROM #AuditMarker;")
            record("transacao e temporaria entre GO", "execucao", trans.success && trans.tables.last?.rows.first?[0] == "0", "ROLLBACK preserva semântica entre lotes")
            let start = Date(); let waiting = Task { try await query("BEGIN TRAN; INSERT #AuditMarker VALUES(11); WAITFOR DELAY '00:00:15';", timeout: 5) }
            try await Task.sleep(nanoseconds: 500_000_000); client.cancel()
            let canceled = try await waiting.value
            let afterCancel = try await query("SELECT @@TRANCOUNT; IF @@TRANCOUNT>0 ROLLBACK; SELECT COUNT(*) FROM #AuditMarker;")
            record("cancelar preserva transacao ate ROLLBACK", "execucao", !canceled.success && Date().timeIntervalSince(start)<6 && afterCancel.tables.first?.rows.first?[0] == "1" && afterCancel.tables.last?.rows.first?[0] == "0", "cancelamento interrompe; transação continua aberta até ROLLBACK explícito")
            let timeout = try await query("WAITFOR DELAY '00:00:08'; SELECT 1;", timeout: 1)
            let afterTimeout = try await query("SELECT 1;")
            record("timeout e reutilizacao", "execucao", !timeout.success && afterTimeout.success, "timeout devolve erro; próxima consulta funciona")
            let many = try await query("SELECT TOP (3000) REPLICATE(CAST('x' AS varchar(max)),16384) AS Bloco FROM sys.all_objects a CROSS JOIN sys.all_objects b;", rows: 3000)
            record("resultado acima de 32 MiB", "limites", !many.success && many.messages.contains("Limite"), "limite explícito; linhas retidas=" + String(many.tables.first?.rows.count ?? 0))
            let afterMemory = try await query("SELECT 456;")
            record("sessao apos limite de memoria", "recuperacao", afterMemory.success, "consulta curta funciona após limite")
            await client.disconnect()
        } catch { record("execucao do probe", "infraestrutura", false, error.localizedDescription) }
        let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try? encoder.encode(observations).write(to: URL(fileURLWithPath: ProcessInfo.processInfo.environment["SQLGARDEN_AUDIT_JSON"]!))
        print("TOTAL \(observations.count), findings \(observations.filter{!$0.passed}.count)")
        if observations.contains(where: { !$0.passed }) { exit(1) }
    }
}
