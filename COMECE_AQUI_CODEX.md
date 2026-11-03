# Instrução para o Codex no Mac

Abra a pasta SQLGarden e envie:

> Continue este projeto de app nativo de macOS chamado SQLGarden. Leia README.md,
> docs/ARQUITETURA.md e docs/VALIDACAO_MAC.md antes de alterar código. Quero uma
> interface com acabamento Apple para usar meu SQL Server no Docker, próxima do
> fluxo do SSMS da faculdade. Sem Python integrado nesta primeira versão: uso o
> VS Code para Python. O código foi criado em Linux; a ponte C passou em 12
> testes com driver simulado, mas o SwiftUI ainda não foi compilado nem testado
> no Mac. Primeiro compile, corrija os erros reais e conclua os testes disponíveis.
> Depois abra o app e valide a interface e a conexão com meu SQL Server existente.
> Use o container que já tenho. Não recrie containers, não remova volumes, não
> troque senhas e não apague bancos. Solicite minhas credenciais somente se forem
> necessárias e deixe que eu as digite na interface; não grave senhas no código
> nem em logs. Instale dependências ausentes pelo fluxo previsto se necessário.
> Mantenha SwiftUI/AppKit, T-SQL real, sessão persistente, GO, mensagens e resultados
> múltiplos. Valide USE, tabelas temporárias, transações, Unicode, NULL, erros e
> cancelamento. Rode exemplos de criação de objetos somente em uma base de teste
> própria após revisar os nomes e o escopo. Atualize docs/VALIDACAO_MAC.md com o que
> realmente passou. Gere dist/SQLGarden.app e me entregue o app abrindo no Mac.
> Não comece adicionando funções novas nem reescrevendo toda a arquitetura:
> conclua esta primeira versão. Use Sol 6.1 Alto como modelo principal.

## Ordem prática

1. Verificar macOS, `swift --version`, Homebrew e driver ODBC 18.
2. Rodar `bash scripts/test.sh`. Corrigir problemas de compilação encontrados.
3. Rodar `bash scripts/build-app.sh` e `open dist/SQLGarden.app`.
4. Observar a janela em claro/escuro e corrigir problemas reais de layout.
5. Usar **Conectar**, mantendo o SQL Server que já funciona no Docker.
6. Executar o checklist de `docs/VALIDACAO_MAC.md`.

Não existe sincronização automática entre esta conversa e o Codex local. Para
pedir ajuda aqui, envie o erro completo ou os arquivos alterados relevantes.
