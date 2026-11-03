import Foundation
import StudioCore
struct Item: Codable { let name: String; let passed: Bool; let detail: String }
@main struct ClassroomAudit {
 static func main() async {
  let client=SQLClient(), observer=SQLClient()
  var items:[Item]=[]
  func record(_ name:String,_ passed:Bool,_ detail:String) {
   items.append(Item(name:name,passed:passed,detail:detail)); print("\(passed ? "PASS" : "FAIL"): \(name): \(detail)");fflush(stdout)
  }
  func query(_ sql:String, timeout:Int=5) async throws -> SQLResponse { try await client.execute(sql,timeout:timeout,maxRows:1000) }
  func balances(_ response:SQLResponse)->[String?] { response.tables.first?.rows.map{$0[0]} ?? [] }
  do {
   var p=ConnectionProfile();p.host="127.0.0.1";p.port=Int(ProcessInfo.processInfo.environment["SQLGARDEN_TEST_PORT"]!)!
   let password=ProcessInfo.processInfo.environment["SQLGARDEN_INTEGRATION_PASSWORD"]!
   try await client.connect(p,password:password)
   let version=try await query("SELECT CAST(SERVERPROPERTY('Edition') AS nvarchar(100));")
   record("Conexão real",version.success && version.tables.first?.rows.first?[0]?.contains("Express")==true,"Microsoft ODBC + SQL Server Express")
   let db="SQLGarden_Validacao_Aula_" + String(Int(Date().timeIntervalSince1970))
   let setup=try await query("IF DB_ID(N'\(db)') IS NOT NULL THROW 51000,N'Base já existe; nenhuma alteração.',1;\nGO\nCREATE DATABASE [\(db)];\nGO\nUSE [\(db)];\nGO\nCREATE TABLE dbo.Contas(ID int PRIMARY KEY,Saldo int NOT NULL CHECK(Saldo>=0));INSERT dbo.Contas VALUES(1,1000),(2,500);")
   guard setup.success else { throw StudioError.message(setup.messages) }
   p.database=db;try await observer.connect(p,password:password)
   record("Base de aula exclusiva",true,"Criada sem volumes ou bancos pessoais")
   let rollback=try await query("BEGIN TRANSACTION;UPDATE dbo.Contas SET Saldo=750;SELECT Saldo FROM dbo.Contas ORDER BY ID;ROLLBACK;SELECT Saldo FROM dbo.Contas ORDER BY ID;SELECT @@TRANCOUNT;")
   record("BEGIN/ROLLBACK",rollback.success && balances(rollback)==["750","750"] && rollback.tables[1].rows.map{$0[0]}==["1000","500"] && rollback.tables.last?.rows.first?[0]=="0","Alterações visíveis na própria sessão e desfeitas exatamente")
   let commit=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo-100 WHERE ID=1;UPDATE dbo.Contas SET Saldo=Saldo+100 WHERE ID=2;COMMIT;")
   let committed=try await observer.execute("SELECT Saldo FROM dbo.Contas ORDER BY ID;")
   record("COMMIT visto por outra conexão",commit.success && balances(committed)==["900","600"],"Outra conexão leu 900/600 depois do COMMIT")
   let save=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo+10 WHERE ID=1;SAVE TRANSACTION PontoAula;UPDATE dbo.Contas SET Saldo=Saldo+20 WHERE ID=1;ROLLBACK TRANSACTION PontoAula;SELECT Saldo FROM dbo.Contas WHERE ID=1;ROLLBACK;")
   record("SAVE TRANSACTION / rollback parcial",save.success && balances(save)==["910"],"Rollback até o savepoint preserva a primeira alteração; rollback final limpa a sessão")
   let nested=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo+1 WHERE ID=1;BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo+2 WHERE ID=1;COMMIT;SELECT @@TRANCOUNT;ROLLBACK;SELECT Saldo FROM dbo.Contas WHERE ID=1;")
   record("Transação aninhada",nested.success && balances(nested)==["1"] && nested.tables.last?.rows.first?[0]=="900","COMMIT interno não confirmou a transação externa; rollback externo desfez tudo")
   let temp=try await query("CREATE TABLE #AulaTemp(n int);\nGO\nINSERT #AulaTemp VALUES(42);\nGO\nSELECT n FROM #AulaTemp;")
   record("Temporária atravessa GO",temp.success && balances(temp)==["42"],"Sessão preservada entre lotes")
   let variable=try await query("DECLARE @ValorAula int=42;\nGO\nSELECT @ValorAula;")
   record("Variável não atravessa GO",!variable.success,"Erro SQL esperado, sem tentativa de corrigir automaticamente")
   let ddl=try await query("BEGIN TRAN;CREATE TABLE dbo.DDLAula(n int);ROLLBACK;SELECT OBJECT_ID(N'dbo.DDLAula');")
   record("CREATE TABLE dentro de ROLLBACK",ddl.success && balances(ddl)==[nil],"Objeto criado na transação não existe após rollback")
   let failed=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo+5 WHERE ID=1;SELECT 1/0;\nGO\nROLLBACK;")
   let pending=try await query("SELECT @@TRANCOUNT;SELECT Saldo FROM dbo.Contas WHERE ID=1;")
   record("Erro interrompe lotes, transação pode ficar aberta",!failed.success && balances(pending)==["1"] && pending.tables.last?.rows.first?[0]=="905","ROLLBACK em GO posterior não executou porque o lote anterior falhou; exige rollback explícito")
   _=try await query("ROLLBACK;")
   let caught=try await query("SET XACT_ABORT ON;BEGIN TRAN;BEGIN TRY INSERT dbo.Contas VALUES(1,123);END TRY BEGIN CATCH SELECT XACT_STATE(),@@TRANCOUNT;IF XACT_STATE()<>0 ROLLBACK;END CATCH;SET XACT_ABORT OFF;SELECT @@TRANCOUNT;")
   print("CATCHDATA success=\(caught.success), messages=\(caught.messages), rows=\(caught.tables.map{$0.rows})")
   record("TRY/CATCH e XACT_ABORT",caught.success && caught.tables.first?.rows.first == ["-1","1"] && caught.tables.last?.rows.first?[0]=="0","Estado não confirmável -1 observado; CATCH fez rollback explícito")
   let implicit=try await query("SET IMPLICIT_TRANSACTIONS ON;UPDATE dbo.Contas SET Saldo=Saldo WHERE ID=1;SELECT @@TRANCOUNT;ROLLBACK;SET IMPLICIT_TRANSACTIONS OFF;")
   record("IMPLICIT_TRANSACTIONS",implicit.success && balances(implicit)==["1"],"UPDATE abriu transação implícita; rollback e modo OFF explícitos")
   _=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo+1 WHERE ID=1;")
   let locked=try await observer.execute("SET LOCK_TIMEOUT 500;SELECT Saldo FROM dbo.Contas WHERE ID=1;",timeout:3)
   _=try await query("ROLLBACK;")
   let unlocked=try await observer.execute("SELECT Saldo FROM dbo.Contas WHERE ID=1;")
   record("Bloqueio entre duas conexões",!locked.success && unlocked.success && balances(unlocked)==["900"],"Leitura bloqueou durante a transação; rollback liberou o bloqueio")
   let waiting=Task { try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo-25 WHERE ID=1;WAITFOR DELAY '00:00:15';",timeout:5) }
   try await Task.sleep(nanoseconds:500_000_000);client.cancel();let canceled=try await waiting.value
   let afterCancel=try await query("SELECT @@TRANCOUNT;SELECT Saldo FROM dbo.Contas WHERE ID=1;")
   record("Cancelar não é ROLLBACK",!canceled.success && balances(afterCancel)==["1"] && afterCancel.tables.last?.rows.first?[0]=="875","Cancelamento interrompeu WAITFOR e manteve a transação aberta até rollback explícito")
   _=try await query("ROLLBACK;")
   let timed=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=Saldo+3 WHERE ID=1;WAITFOR DELAY '00:00:08';",timeout:1)
   let afterTimeout=try await query("SELECT @@TRANCOUNT;")
   record("Timeout não é ROLLBACK",!timed.success && balances(afterTimeout)==["1"],"Timeout devolveu erro, sem confirmar ou desfazer a transação")
   _=try await query("ROLLBACK;")
   let quote=try await query("SELECT N'ação',N'd''água',N'\"aspas duplas\"',N'João' AS [Nome do aluno];")
   record("Literais com aspas e Unicode",quote.success && quote.tables.first?.rows.first == ["ação","d'água","\"aspas duplas\"","João"],"Transporte e parser preservam o conteúdo quando o texto chega corretamente ao editor")
   _=try await query("BEGIN TRAN;UPDATE dbo.Contas SET Saldo=999 WHERE ID=1;")
   await client.disconnect();try await client.connect(p,password:password)
   let afterDisconnect=try await query("SELECT Saldo FROM dbo.Contas ORDER BY ID;SELECT @@TRANCOUNT;")
   record("Desconectar desfaz transação não confirmada",afterDisconnect.success && balances(afterDisconnect)==["900","600"] && afterDisconnect.tables.last?.rows.first?[0]=="0","SQL Server desfez o UPDATE pendente ao encerrar a sessão")
   let syntax=try await query("USE DATABASE NomeDeExemplo;")
   record("Sintaxe inválida de aula gera erro",!syntax.success,"USE DATABASE não é sintaxe T-SQL; o cliente deve manter o erro do servidor")
   let clean=try await query("SELECT @@TRANCOUNT;SELECT Saldo FROM dbo.Contas ORDER BY ID;")
   record("Estado final limpo",clean.success && balances(clean)==["0"] && clean.tables.last?.rows.map{$0[0]}==["900","600"],"Sem transação aberta e sem alterações não confirmadas")
  } catch {record("Infraestrutura/execução",false,error.localizedDescription); _=try? await query("IF @@TRANCOUNT>0 ROLLBACK;")}
  await client.disconnect();await observer.disconnect()
  let out=URL(fileURLWithPath:ProcessInfo.processInfo.environment["SQLGARDEN_CLASSROOM_JSON"]!)
  let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys];try? enc.encode(items).write(to:out)
  print("TOTAL \(items.count), FALHAS \(items.filter{!$0.passed}.count)")
  if items.contains(where:{!$0.passed}) {exit(1)}
 }
}
