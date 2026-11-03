# Validação e correções — SQLGarden 0.3.1

Data: 21/10/2026. Desenvolvido por Victor. Base: 0.3.0, sem alterações no autocomplete.

## Resultado

As quatro causas de falha documentadas na auditoria anterior foram corrigidas.
A revisão adicional reproduziu e corrigiu cinco outras falhas, listadas abaixo.
As reproduções de integridade agora passam com o driver Microsoft e SQL Server
reais. Isso não comprova ausência de outros bugs.

O novo aplicativo universal e o DMG estão prontos. A instalação anterior e os
rascunhos/perfis pessoais não foram substituídos. Para atualizar, salve suas
consultas, encerre o app e copie SQLGarden.app para Aplicativos, escolhendo Substituir.
A recuperação mantém o mesmo formato; não é necessário apagar dados ou reinstalar bancos.

## Erros corrigidos

| Problema | Correção e evidência |
|---|---|
| CRLF/CR viravam LF dentro de literais SQL | Parser mantém o texto e terminadores originais. SQL real confirmou 8 bytes/13 para A+CRLF+B e devolveu os caracteres exatos. |
| NUL no documento executava somente o prefixo | Preflight rejeita o documento completo antes de qualquer lote. INSERT seguido de GO e NUL não inseriu nenhuma linha. |
| NUL em resultado eliminava o restante da célula | Serialização com comprimento explícito e escape JSON. A+NUL+B, NUL final, Unicode e NUL entre blocos preservados. |
| Chaves bloqueava a interface | Leitura/gravação/remoção fora do MainActor; estado visível, opção manual, invalidação de leituras duplicadas e respostas tardias. |
| Marcas Unicode combinantes escondiam aspas/colchetes do parser | Delimitadores analisados por escalares, preservando GO interno. Reproduzido na base antiga e confirmado com SQL real após a correção. |
| Campos de conexão aceitavam NUL | Rejeição de NUL em servidor, usuário, banco e senha antes de construir a string ODBC. |
| Aviso do driver acrescentava bytes a binário curto | SQL_SUCCESS_WITH_INFO usa o comprimento informado. Driver de teste reproduziu bytes extras antes da correção e retornou exatamente 0x0001FF10 depois. |
| Arquivo externo ilegível podia ser sobrescrito sem aviso | Erro de leitura interrompe o salvamento e preserva os bytes. A base antiga sobrescreveu o arquivo sintético; a nova o preservou. |
| Alteração Unicode com bytes diferentes aparecia como não editada | Comparação UTF-8 exata no estado de alteração, sincronização do editor e conflito de arquivo. A base antiga marcou o teste como limpo; a nova exige salvamento. |

Também foram acrescentadas proteções contra respostas do explorador após
desconectar, parâmetros de conexão alterados durante uma tentativa e cálculo
de seleção com overflow. O guia agora aponta corretamente os scripts para o ZIP
completo; o DMG contém somente o app e o atalho para Aplicativos.

## Testes executados nesta versão

| Camada | Resultado |
|---|---|
| StudioCore/XCTest | 23 testes passaram, incluindo CRLF/CR, GO, Unicode, NUL, persistência, histórico, CSV/TSV e relatórios. |
| Ponte C e driver ODBC simulado | 14 testes passaram, incluindo NUL entre blocos, binário com aviso, resultados parciais e cancelamento. Isso não substitui o driver Microsoft real. |
| Integração com Microsoft ODBC + SQL Server Express real | 14 verificações passaram, em uma base exclusiva SQLGarden_Validacao_…: sessão, temporárias, catálogo separado, GO, erros, limites e cancelamento. |
| Regressões e limites no SQL Server real | 28 casos passaram, zero falhas: integridade exata, parser, tipos, 512/513 colunas, 64/65 conjuntos, limite de linhas, célula acima de 256 KiB, resultado acima de 32 MiB, timeout e recuperação. |
| AppKit/SwiftUI e Workspace | 29 verificações passaram, incluindo execução real, seleção da grade, cópia, Undo, persistência, Chaves e arquivo externo. São testes nativos dos componentes/modelo, não uma nova auditoria por cliques no aplicativo instalado. |
| Chaves real | Entrada sintética com nome único foi criada, lida, removida e sua ausência confirmada. Nenhuma credencial pessoal foi lida ou alterada. |
| Autorização do Chaves pendente/negada/tardia | Simulação controlada de espera/negação para verificar responsividade, alternativa manual e troca de perfil. Não foi automatizado o diálogo de segurança do macOS. |
| Interrupção abrupta | SIGKILL somente no filho de teste; processo novo recuperou rascunho e seleção, sem conectar ou executar automaticamente. |
| Bundle final | Cópia isolada com bundle ID de QA abriu pelo launcher; executável idêntico ao release, processo observado no loop AppKit, encerrado ao final. É um smoke de abertura. |
| Distribuição | App arm64/x86_64, minOS 14.0 nos dois slices; assinatura ad hoc válida. DMG verificado e montado somente leitura; app embarcado idêntico ao build. ZIP e manifestos SHA-256 verificados. |

Evidências legíveis: docs/evidencias/0.3.1/. Os JSONs contêm somente exemplos
sintéticos. O teste anterior de 0.3.0 está preservado em docs/VALIDACAO_0.3.0.md.

## Ambiente e limites da confirmação

Mac Apple Silicon, macOS 27.0.1 (26A434), compilador Swift/Xcode local,
unixODBC, OpenSSL 3 e Microsoft ODBC Driver 18. Servidor Express 2022 em Docker,
em porta aleatória somente de loopback, sem volumes pessoais. O servidor de QA
foi parado ao terminar; o contêiner e a base de validação foram preservados.

Execução física em Intel, macOS 14 e Mac sem dependências não foi realizada
nesta rodada. App com assinatura ad hoc, sem Developer ID/notarização; a geração
universal não comprova essas combinações. O comportamento de autorização real
do Chaves depende do macOS e das permissões concedidas pelo usuário.

Limites de exibição, cancelamento e erro não desfazem comandos já executados.
Não há COMMIT/ROLLBACK nem retry automático. Autenticação Windows, SQLCMD,
autocomplete e modo estudo continuam fora desta atualização.

## Preservação e entrega

Nenhum banco de aula/pessoal, volume existente, senha pessoal ou consulta aberta
foi usado nos testes. Não houve instalação de dependências, envio de e-mail ou
alteração da instalação em Aplicativos. Os testes usaram cópia de fonte, diretórios
e entradas de QA separados. Credenciais transitórias do servidor ficaram somente
no trabalho privado e foram excluídas da distribuição.
