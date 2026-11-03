# SQLGarden 0.3.1 — testes de aula e backlog do próximo update

Testes executados em **21/10/2026**. Consolidação em **28/10/2026**.
Escopo: testar e registrar; **nenhuma correção aplicada ao aplicativo**.

## Resultado

A falha de entrada de aspas foi reproduzida no editor real. A mesma sequência
funcionou num NSTextView AppKit de controle. BEGIN TRANSACTION, ROLLBACK,
COMMIT, savepoints e outros cenários foram exercitados com SQL Server real.

A bateria do motor registrou **19 verificações: 18 aprovadas e 1 não aprovada**.
O caso não aprovado de TRY/CATCH e XACT_ABORT permanece pendente: a sonda posterior
funcionou no cliente e no sqlcmd, mas usou SQL diferente, incluindo SET NOCOUNT ON.
Não é correto declarar que a reprodução original foi resolvida ou que todos os
casos passaram. O campo detail do JSON original descreve a expectativa; quando
passed=false ele não comprova que esse resultado foi observado.

O servidor exclusivo também encerrou com código 139, sem evento OOM e sem evento
Docker kill/stop no intervalo observado. A causa dessa falha do servidor não foi
estabelecida. Não a classificar como crash do SQLGarden.

## Backlog priorizado

### SG-AULA-001 · P1 · Confirmado: aspas e composição de teclado desaparecem

Ambiente: macOS 27.0.1, layout `com.apple.keylayout.Brazilian-Pro`, SQLGarden 0.3.1
em cópia de QA com o executável do release. Testes por teclas, sem colar o texto.

| Sequência | Controle NSTextView | SQLGarden |
|---|---|---|
| Aspa simples, depois espaço | `'` | Apenas espaço; aspa ausente |
| Aspa dupla, depois espaço | `"` | Apenas espaço; aspa ausente |
| Tecla de aspa/acento, depois `a` | `á` | `a` |
| Colar SQL com aspas e Unicode | Não necessário | Conteúdo preservado e SQL executado corretamente |

Impacto: aluno pode não conseguir formar literais SQL pelas teclas. A perda de
acentos por composição pertence à mesma investigação de entrada, não ao parser.
A sequência typeText com `ação` também perdeu um caractere no controle; esse caso
isolado não foi atribuído exclusivamente ao aplicativo.

Suspeita a investigar: interação de texto marcado/composição com atualização do
binding e destaque. `SQLEditor.swift` escreve editor.string em updateNSView e altera
textStorage no destaque; ainda não foi provado qual chamada causa a perda.

Critério de aceite do próximo update: preservar texto marcado, aspas simples e
duplas e acentos pelas teclas no Brasileiro Pro; comparar novamente ao controle;
validar Undo, seleção, troca de aba e digitação de SQL completo. Não usar colagem
como prova de que a digitação foi corrigida. Evidência: aspas-e-teclado.json.

### SG-AULA-002 · P2 · Confirmado: indicação de conexão permanece após 08S01

Uma consulta devolveu Communication link failure / SQLSTATE 08S01. A interface
continuou apresentando Conexão e Executar como sessão conectada. O encerramento
do servidor explica a comunicação perdida; a indicação desatualizada é do cliente.

`Workspace.execute()` apresenta a falha, mas não invalida connected nesse caminho.
Critério de aceite: marcar a sessão como indisponível quando houver perda fatal de
transporte, preservar mensagens/resultados parciais e exigir reconexão explícita.
Não repetir UPDATE/INSERT automaticamente nem presumir o destino de uma transação
após uma falha de rede.

### SG-AULA-003 · P2 · Melhoria de uso em aula: transação pode continuar aberta após erro

BEGIN + UPDATE + divisão por zero falhou, interrompeu o próximo lote GO e deixou
transação aberta. O ROLLBACK que estava nesse lote não executou. A ação Verificar
transação confirmou contagem 1; ROLLBACK separado restaurou os saldos corretamente.
Cancelar e timeout também mantiveram transação até rollback explícito no motor.

Isso é comportamento esperado do SQL Server, não falha do ROLLBACK no aplicativo.
Melhoria proposta: aviso claro após erro/cancelamento/timeout de que pode haver
transação pendente, mantendo a verificação manual. Não acrescentar SELECT oculto
que altere @@ROWCOUNT/@@ERROR nem fazer COMMIT/ROLLBACK automático.

### SG-AULA-004 · P2 · Investigar: diálogo de exportação CSV inacessível na automação

Na demonstração anterior, a consulta foi salva em vendas-pagas.sql. Ao exportar
CSV, a automação permaneceu na janela principal; a amostra do processo indicou
Workspace.export → NSSavePanel.runModal → NSApplication.runModalForWindow.
Não foi possível concluir a exportação por essa interface de automação.

Ainda falta confirmar se um usuário consegue operar o diálogo normalmente.
Não declarar corrupção de CSV nem falha geral de exportação com essa evidência.
Reproduzir manualmente e avaliar apresentação do painel vinculada à janela e
reentrada das ações de arquivo. A exportação não foi marcada como concluída.

### SG-AULA-005 · P2 · Pendente: reprodução original TRY/CATCH e XACT_ABORT

O teste original esperava XACT_STATE=-1, TRANCOUNT=1 no CATCH e 0 após rollback,
mas sua asserção falhou e o relatório original não gravou as linhas retornadas.
Uma sonda com SET NOCOUNT ON e uma seleção adicional retornou (-1,1,2627) e 0
no SQLClient; o sqlcmd também retornou esses valores.

Próximo passo: repetir o SQL original exatamente, gravar success, mensagens,
todos os conjuntos e linhas; comparar ao sqlcmd antes de atribuir a falha ao
cliente, ao servidor ou à asserção. Não publicar correção sem essa separação.

## O que funcionou nos testes reais

- Interface: BEGIN transferiu os saldos fictícios de 1000/500 para 750/750;
  ROLLBACK em outra aba devolveu 1000/500 e a verificação mostrou sessão limpa.
- Interface: COMMIT confirmou 900/600. Após erro, ROLLBACK explícito desfez a
  alteração pendente e preservou os valores confirmados.
- Motor: outra conexão observou o COMMIT; savepoint e rollback parcial funcionaram.
- Motor: COMMIT interno não confirmou a transação externa; rollback externo desfez tudo.
- Motor: temporária persistiu entre GO; variável local não atravessou GO, como esperado.
- Motor: CREATE TABLE dentro da transação foi desfeito por ROLLBACK.
- Motor: transação implícita, bloqueio entre duas conexões e liberação por rollback.
- Motor: cancelamento e timeout interromperam a espera; rollback posterior foi necessário.
- Motor: desconectar desfez alteração não confirmada; reconexão mostrou contagem 0.
- Motor: SQL com aspas escapadas, Unicode e identificador com espaços foi preservado.

O teste do botão Parar na interface ficou bloqueado pela perda de comunicação
antes de aparecer a espera. Isso não é prova de defeito no botão. Cancelamento
pelo SQLClient foi aprovado na bateria do motor.

## Evidências, preservação e limites

- aspas-e-teclado.json: árvores de acessibilidade da comparação de entrada.
- evidencias/transacoes-motor.json e .log: resultados brutos da bateria original.
- evidencias/transacoes-interface-observacoes.json: resumo das interações registradas
  nesta conversa; não é uma exportação automática das árvores AX de transações.
- evidencias/xact-state-*.log: sonda e comparação com sqlcmd.
- casos/: exemplos para reprodução apenas no banco exclusivo indicado nos arquivos.
- evidencias/*.swift: testes auxiliares; não foram incorporados ao aplicativo.

Foram usados bancos exclusivos SQLGarden_Validacao_… em servidor próprio de teste,
sem volumes pessoais. A consulta que o usuário havia aberto foi preservada; as
edições de teste foram feitas em novas abas. Nenhum executável do release nem
arquivo em Sources/ foi alterado nesta auditoria. Credenciais e logs privados do
servidor não acompanham a entrega. Não houve nova validação do ambiente em 28/10;
os resultados acima pertencem à execução de 21/10. O estado atual do Docker não
foi alterado para produzir esta consolidação.
