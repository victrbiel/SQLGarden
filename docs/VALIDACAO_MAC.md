# Validação SQLGarden 0.3.0

Data: 19 de outubro de 2026. Desenvolvido por Victor.

## Ambiente e resultados comprovados

Mac Apple Silicon, macOS 27.0.1. Driver Microsoft ODBC 18.7.1.1, unixODBC
2.3.14 e OpenSSL 3.6.5 existentes. SQL Server 2022 Express 16.0.4305.5
executado em um container de QA novo, com porta exclusiva em 127.0.0.1,
senha aleatória privada e sem montagem de volumes pessoais. Os bancos e
containers anteriores não foram usados nos testes. Nenhuma senha é distribuída.

- 19 testes StudioCore passaram: parser GO, escaping, CSV, persistência atômica,
  fallback de backup, seleção UTF-16, CRLF, retenção/exclusão do histórico,
  cópia TSV e diagnóstico com códigos SQLSTATE de enumeração fechada.
- 12 testes da ponte C passaram com driver simulado: cancelamento, limites,
  resultados parciais, Unicode, NULL/vazio, binários e diagnósticos.
- 14 verificações com servidor e driver reais passaram: sessão, GO, temporárias,
  transações, Unicode, resultados múltiplos, CSV, erros parciais e cancelamento.
- 18 verificações AppKit/modelo passaram, incluindo autosave, Undo nativo,
  régua de linhas, seleção/cópia da grade nativa, histórico de sucesso/erro/
  cancelamento, exclusão/desativação e estado de transação na mesma sessão.
- Rodada local final: 8 verificações passaram, incluindo preservação dos dois
  arquivos ilegíveis de recuperação ao desativar histórico. O ajuste final
  não alterou a execução SQL já verificada no servidor real.
- Cenário adicional em dois processos: o processo de escrita confirmou autosave
  e recebeu SIGKILL; um processo novo recuperou rascunho, aba ativa e seleção,
  sem reconectar ou executar SQL.
- A consulta de inspeção captura XACT_STATE antes de consultar @@SPID, evitando
  o valor 1 observado com @@TRANCOUNT 0 quando ambos estavam no mesmo SELECT.
  A correção foi verificada com BEGIN TRANSACTION e ROLLBACK reais.
- Interface aberta em cópia com identificador próprio, sem carregar perfil ou
  rascunhos pessoais: editor com números de linha, histórico, formulário de
  feedback, diagnóstico inicialmente desmarcado e revisão editável conferidos.
- Botão Preparar e-mail abriu uma mensagem real no Mail com relatório sintético,
  destinatário e assunto corretos, corpo revisado e anexo SQLGarden-relatorio.txt
  conferidos. O rascunho de teste foi fechado sem salvar/enviar.
  O app não confirma entrega; nenhum envio de e-mail foi realizado neste QA.
- Build universal arm64/x86_64. Executável e launcher declaram macOS mínimo 14.0.
  Assinatura ad hoc verificada com codesign --verify --deep --strict.
- DMG visual gerado com fundo original e apenas app/atalho Aplicativos visíveis;
  verificação por hdiutil e conferência do conteúdo/assinatura do app montado.
- ZIP completo verificado, com hashes SHA-256 e fontes sem caches, perfis,
  segredos, volumes ou estado de QA.

Evidências de testes da 0.3.0 estão em evidencias/0.3.0/. Logs de build têm
caminhos de desenvolvimento substituídos por [PROJETO]. O histórico de validação
da 0.2.0 foi preservado em VALIDACAO_0.2.0.md.

## Limites que permanecem

Não houve teste físico em Mac Intel, macOS 14 nem Mac recém-instalado.
Build universal não equivale a validar ODBC e dependências em hardware Intel.
O fluxo de quarentena/Gatekeeper após download em outro Mac não foi validado.
A assinatura é ad hoc, sem Developer ID/notarização. As dependências continuam
externas e precisam estar instaladas no Mac de destino.

O envio e recebimento real de e-mail depende da conta e do serviço configurados;
a composição local com corpo e anexo foi conferida, sem enviar mensagens.
Há alternativas de copiar/salvar o relatório para uso com webmail. Diagnósticos
são eventos técnicos limitados desta abertura, não crash dumps nem logs globais.

O estado da transação é uma fotografia solicitada explicitamente pelo usuário,
invalida-se após nova execução e não muda COMMIT/ROLLBACK automaticamente.
Autosave usa debounce de 300 ms: a edição mais recente pode não sobreviver se
houver interrupção antes da escrita. Arquivos SQL continuam recomendados como
cópias permanentes. Histórico e rascunhos são locais e podem conter SQL pessoal.

SQL Server em emulação Apple Silicon não tem suporte oficial da Microsoft;
os resultados acima comprovam este ambiente de QA, sem promessa para todo Docker.
