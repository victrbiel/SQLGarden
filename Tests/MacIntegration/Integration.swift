import Foundation
import StudioCore

// Opt-in tests against a real local SQL Server. Never use a personal database.
// The password is received from the environment and is never printed.
@main struct Integration {
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw StudioError.message(message) }
    }
    static func main() async {
        let client = SQLClient()
        let metadata = SQLClient()
        var passed = 0
        func check(_ message: String) { passed += 1; print("PASS \(passed): \(message)") }
        do {
            guard let password = ProcessInfo.processInfo.environment["SQLGARDEN_INTEGRATION_PASSWORD"], !password.isEmpty else {
                throw StudioError.message("Defina SQLGARDEN_INTEGRATION_PASSWORD somente no ambiente do teste.")
            }
            let database = ProcessInfo.processInfo.environment["SQLGARDEN_TEST_DATABASE"] ?? "SQLGarden_Validacao_20261019"
            try require(database.hasPrefix("SQLGarden_Validacao_") && database.range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil,
                        "O banco de teste precisa ter prefixo SQLGarden_Validacao_ e apenas letras, números e sublinhados.")
            var profile = ConnectionProfile()
            profile.host = "localhost"; profile.port = 1433; profile.database = "master"
            try await client.connect(profile, password: password)
            let edition = try await client.execute("SELECT CAST(SERVERPROPERTY('Edition') AS NVARCHAR(100)), CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100));")
            try require(edition.success && edition.tables.first?.rows.first?[0]?.contains("Express") == true, "A instância não confirmou a edição Express.")
            print("Servidor: \(edition.tables[0].rows[0].map { $0 ?? "NULL" }.joined(separator: " · "))")
            check("driver Microsoft real conecta à edição Express")
            if CommandLine.arguments.contains("--probe") {
                let probe = try await client.execute("SELECT N'ação, coração e São Paulo 🎓' AS Unicode, CAST(NULL AS NVARCHAR(20)) AS Nulo, N'' AS Vazio, N'NULL' AS Literal; SELECT UNICODE(SUBSTRING(N'ação',2,1)) AS Entrada, NCHAR(231)+NCHAR(227) AS Saida;")
                print("PROBE: \(probe.tables.map { $0.rows }) · \(probe.messages)")
                await client.disconnect()
                return
            }
            if CommandLine.arguments.contains("--disconnect-check") {
                // Run only against the known, isolated validation database.
                try require(database == "SQLGarden_Validacao_20261019_Final", "O cenário de desconexão usa somente a base criada por esta validação.")
                let use = try await client.execute("USE \(SQLText.identifier(database));")
                try require(use.success, use.messages)
                let setup = try await client.execute("IF OBJECT_ID(N'dbo.SG_TransporteSemRetry') IS NOT NULL THROW 51001, N'Objeto de teste já existe; nada foi alterado.', 1; CREATE TABLE dbo.SG_TransporteSemRetry (Codigo INT IDENTITY PRIMARY KEY);")
                try require(setup.success, setup.messages)
                let session = try await client.execute("SELECT @@SPID;")
                guard let value = session.tables.first?.rows.first?[0], let spid = Int(value), spid > 0 else { throw StudioError.message("SPID de teste inválido.") }
                try await metadata.connect(profile, password: password)
                let interrupted = Task { try await client.execute("INSERT INTO dbo.SG_TransporteSemRetry DEFAULT VALUES; WAITFOR DELAY '00:00:20'; SELECT 1;", timeout: 8) }
                try await Task.sleep(nanoseconds: 500_000_000)
                let killed = try await metadata.execute("KILL \(spid);")
                try require(killed.success, killed.messages)
                let failure = try await interrupted.value
                try require(!failure.success, "A conexão interrompida não devolveu falha.")
                let count = try await metadata.execute("SELECT COUNT(*) FROM \(SQLText.identifier(database)).dbo.SG_TransporteSemRetry;")
                try require(count.success && count.tables[0].rows[0][0] == "1", "O comando foi repetido ou o INSERT inicial não foi confirmado.")
                try await client.connect(profile, password: password)
                let recovered = try await client.execute("SELECT 1;")
                try require(recovered.success, "Reconexão explícita não recuperou o cliente.")
                check("perda de transporte por KILL da própria sessão devolve erro, não repete INSERT e permite reconexão explícita")
                await client.disconnect(); await metadata.disconnect()
                print("Cenário adicional aprovado; tabela SG_TransporteSemRetry preservada na base exclusiva.")
                return
            }
            let existing = try await client.execute("SELECT DB_ID(\(SQLText.literal(database))); ")
            try require(existing.success && existing.tables.first?.rows.first?[0] == nil, "O banco de teste já existe; nada foi alterado. Escolha outro nome para uma nova execução.")
            let created = try await client.execute("CREATE DATABASE \(SQLText.identifier(database));")
            try require(created.success, created.messages)
            let use = try await client.execute("USE \(SQLText.identifier(database));")
            let current = await client.currentDatabase()
            try require(use.success && current == database, "USE não foi preservado.")
            check("criação de base exclusiva e USE persistente")
            for number in ["01_conexao", "02_objetos", "03_sessao", "04_resultados"] {
                let source = try String(contentsOfFile: "examples/\(number).sql", encoding: .utf8)
                let result = try await client.execute(source)
                try require(result.success, "\(number): \(result.messages)")
                if number == "01_conexao" {
                    let row = result.tables.last?.rows.first
                    try require(row?[0] == "ação, coração e São Paulo 🎓" && row?[1] == nil && row?[2] == "" && row?[3] == "NULL", "Unicode, NULL ou vazio não foram preservados.")
                    try require(result.messages.contains("Conexão com SQLGarden funcionando."), "PRINT não foi devolvido.")
                }
                if number == "04_resultados" {
                    try require(result.tables.count == 5, "Esperados cinco conjuntos de resultado.")
                    try require(result.tables[0].rows[0][4] == "0x0001FF10", "Binário incorreto.")
                    try require(result.tables[1].rows[0][0] == String(repeating: "ação ", count: 3000), "Texto longo não foi preservado.")
                    try require(result.tables[2].rows[0][0]?.contains("\nGO\n") == true, "GO em string foi dividido.")
                }
                check("examples/\(number).sql no servidor real")
            }
            let session = try await client.execute("SELECT Codigo, Texto FROM #SG_Sessao ORDER BY Codigo; SELECT @@TRANCOUNT;")
            try require(session.success && session.tables[0].rows[0][1] == "Primeiro lote" && session.tables[0].rows[1][1] == "Segundo lote, mesma sessão" && session.tables[1].rows[0][0] == "0", "Sessão temporária ou ROLLBACK incorreto.")
            check("#temporária entre chamadas e ROLLBACK sem transação pendente")
            try await metadata.connect(profile, password: password)
            let catalog = try await metadata.execute("SELECT name, type FROM \(SQLText.identifier(database)).sys.objects WHERE name LIKE 'SG[_]%';")
            let metadataDatabase = await metadata.currentDatabase()
            let editorDatabase = await client.currentDatabase()
            try require(catalog.success && catalog.tables.first?.rows.count == 5 && metadataDatabase == "master" && editorDatabase == database, "Explorador interferiu na sessão ou não listou os cinco objetos.")
            check("catálogo separado lista tabela, view, procedure e trigger sem mudar a sessão")
            let partial = try await client.execute("SELECT 42 AS AntesDoErro; THROW 51000, N'Erro intencional de validação', 1;\nGO\nSELECT 999 AS NaoExecutado;")
            try require(!partial.success && partial.tables.count == 1 && partial.tables[0].rows[0][0] == "42" && partial.messages.contains("Erro intencional"), "Resultados parciais ou interrupção no primeiro erro incorretos.")
            check("erro conserva resultado parcial e interrompe os próximos lotes")
            let limited = try await client.execute("SELECT Codigo FROM #SG_Sessao; SELECT 7 AS Depois;", maxRows: 1)
            try require(limited.success && limited.tables.count == 2 && limited.tables[0].rows.count == 1 && limited.tables[0].truncated && limited.tables[1].rows[0][0] == "7", "Limite de linhas perdeu resultados seguintes.")
            check("limite de exibição explícito mantém resultados seguintes")
            let cancelStart = Date()
            let waiting = Task { try await client.execute("WAITFOR DELAY '00:00:20'; SELECT 1;", timeout: 8) }
            try await Task.sleep(nanoseconds: 500_000_000)
            client.cancel()
            let canceled = try await waiting.value
            try require(!canceled.success && Date().timeIntervalSince(cancelStart) < 7, "SQLCancel não interrompeu em menos de sete segundos.")
            let after = try await client.execute("SELECT 123 AS AposCancelar;")
            try require(after.success && after.tables[0].rows[0][0] == "123", "A sessão não recuperou após cancelamento.")
            check("SQLCancel interrompe WAITFOR e a sessão continua utilizável")
            let csv = try await client.execute("SELECT N'ação,\"aspas\"' AS Texto, CAST(NULL AS INT) AS Nulo, N'' AS Vazio;")
            let output = SQLText.csv(csv.tables[0])
            try require(output.contains("\"ação,\"\"aspas\"\"\",,\"\"\r\n"), "CSV perdeu aspas, NULL ou vazio.")
            check("CSV de resultado real preserva Unicode, aspas, NULL e vazio")
            let repeated = try await client.execute("SELECT 8 AS Valor;\nGO 2")
            try require(repeated.success && repeated.tables.count == 2, "GO 2 não repetiu o lote.")
            check("GO 2 é executado pelo SQLClient na mesma conexão")
            await client.disconnect(); await metadata.disconnect()
            try await client.connect(profile, password: password)
            let fresh = try await client.execute("SELECT DB_NAME(), OBJECT_ID('tempdb..#SG_Sessao');")
            try require(fresh.success && fresh.tables[0].rows[0][0] == "master" && fresh.tables[0].rows[0][1] == nil, "A reconexão não abriu uma sessão nova.")
            check("desconectar/reconectar libera a sessão temporária")
            await client.disconnect()
            print("\(passed) verificações reais passaram. Base de teste preservada: \(database). Nenhum banco foi apagado.")
        } catch {
            await client.disconnect(); await metadata.disconnect()
            print("FAIL após \(passed) verificações: \(error.localizedDescription)")
            exit(1)
        }
    }
}
