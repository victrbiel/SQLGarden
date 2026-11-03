# Validação SQLGarden 0.4.0

Data: 28/10/2026. Autoria: Victor. Assinatura ad hoc, sem notarização.

## Correções verificadas

- Aspas e composição no Brasileiro Pro: destaque usa atributos temporários do
  layout, sem regravar textStorage nem sincronizar texto marcado antes da confirmação.
  Teclas reais produziram aspa simples, aspa dupla e á na interface, sem colagem.
- Perda de transporte: estado de conexão é invalidado. Após parar apenas o servidor
  de QA, a interface mostrou Desconectado, Executar desativado e reconexão manual.
- Aviso após falha/cancelamento: informa possível transação aberta, sem SELECT,
  COMMIT, ROLLBACK ou repetição automática. A sessão continua compartilhada entre abas.
- Arquivos: abrir, salvar e CSV usam sheets assíncronas. Alertas de conflito/fechamento
  também usam sheets; ausência de janela cancela a ação. Exportação CSV foi realizada
  pela interface e o arquivo conferiu ID/Saldo 1/900 e 2/600.
- Preferência de salvar senha é persistida e começa desativada em instalações novas.
  Quando desativada, não inicia leitura automática do Chaves ao abrir o formulário.
- TRY/CATCH: SQLExecDirect pode indicar SQL_NO_DATA para um comando inicial sem
  linhas afetadas, mesmo com resultados seguintes. A ponte agora chama SQLMoreResults.
  A reprodução original passou, inclusive sem SET NOCOUNT ON.
- Seleção inválida não pode cair silenciosamente na execução do documento inteiro.

## Navegação

Banco ativo em seletor próprio; objetos agrupados por tipo e esquema, com contagens,
busca e grupos recolhíveis. Clique abre o SQL preparado, sem executar dados sozinho.
Menu por objeto oferece dados/definição, colunas e cópia do nome qualificado.
Abertura da tabela Contas foi conferida pela interface com SQL qualificado correto.
Logo, sessão, drafts, histórico, feedback e a exclusão de autocomplete foram preservados.

## Testes desta rodada

| Verificação | Resultado |
|---|---|
| XCTest/StudioCore | 23 testes, zero falhas |
| Ponte C com driver simulado | 15 testes, zero falhas; inclui SQL_NO_DATA antes de outro resultado |
| Integração Microsoft ODBC + SQL Server Express | 14 verificações aprovadas |
| AppKit/SwiftUI + Workspace, com SQL real | 34 verificações aprovadas |
| Regressões de integridade e limites, SQL real | 28 casos, zero falhas |
| Aula: transações, bloqueios, erros e literais | 19 verificações, zero falhas |
| Recuperação após SIGKILL do processo de teste | Aprovada |
| Uso real por interface | Aspas simples/duplas, acento, explorador, CSV e conexão perdida aprovados |

Os testes de aula incluem BEGIN/ROLLBACK, COMMIT visível por outra conexão,
savepoint, transação aninhada, DDL com rollback, temporárias/variáveis entre GO,
TRY/CATCH com XACT_ABORT, transação implícita, bloqueios, cancelamento, timeout,
desconexão e estado final sem transação pendente. A base de dados é exclusiva de QA.

Evidências em docs/evidencias/0.4.0/. A comparação inicial que falhou foi preservada
na auditoria anterior; a rodada atual repetiu a reprodução e fechou 19/19.

## Distribuição e preservação

App universal arm64/x86_64 com macOS mínimo 14.0; build e assinatura conferidos.
DMG verificado, ZIP com fonte, guias e checksums. Aplicativo instalado em Aplicativos
não foi substituído e nenhum banco/volume pessoal foi modificado. Só o servidor novo,
identificado como QA 0.4.0, foi parado ao terminar. Nenhuma credencial é distribuída.

## Limites

Testado em Apple Silicon/macOS 27.0.1, com dependências locais existentes.
Não houve teste físico em Intel, macOS 14 ou Mac limpo, nem notarização Apple.
Os testes delimitam o que foi verificado; não garantem ausência universal de bugs.
A estabilidade do processo SQL Server em Docker/emulação é independente do cliente.
Cancelar, erro ou timeout não garantem rollback; uma falha de rede deixa o resultado
de comandos em trânsito incerto. O app não repete comandos automaticamente.
