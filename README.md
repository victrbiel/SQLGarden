# SQLGarden

**Desenvolvido por Victor · MIT · macOS 14+ · Apple Silicon e Intel**

Interface nativa SwiftUI/AppKit para trabalhar com Microsoft SQL Server Express:
editor T-SQL, catálogo, GO, sessão persistente, resultados múltiplos, mensagens,
CSV e credenciais opcionais no Chaves. Sem Python integrado.

## Instalar e usar

Leia **[INSTALACAO.md](INSTALACAO.md)**. O DMG instala a interface. O driver
Microsoft, unixODBC e OpenSSL 3 são instalados separadamente pelo script oficial
incluído. Você pode usar o servidor da faculdade, um container existente ou
criar um Express local pelo instalador opcional. Nenhum segredo acompanha o app.

A versão universal inclui arm64 e x86_64. Execução física foi validada no Mac
Apple Silicon descrito em `docs/VALIDACAO_MAC.md`; não confunda compilação Intel
com teste físico em um Mac Intel. A assinatura atual é ad hoc, sem notarização.

## Desenvolver

Requisitos: macOS 14+, Swift 5.9+ e ferramentas Xcode/Command Line Tools. O app
não tem pacotes Swift externos. O catálogo de recursos usa `actool` do Xcode;
para gerar o pacote visual completo é necessário o Xcode com essa ferramenta.

```bash
bash scripts/test.sh
bash scripts/build-app.sh release universal
open dist/SQLGarden.app
bash scripts/build-dmg.sh
```

`build-app.sh release native` compila só a arquitetura atual. `test.sh` usa Python
3 **apenas no teste auxiliar da ponte C**; nenhum Python é necessário para usar,
instalar, executar SQL ou compilar o aplicativo. Os testes StudioCore podem ser
executados separadamente com `swift test --filter StudioCoreTests`.

`test-integration.sh` é opt-in: requer `SQLGARDEN_INTEGRATION_PASSWORD` no ambiente
e cria uma base nova `SQLGarden_Validacao_…`. Nunca informe senha no comando ou
histórico. `SQLGARDEN_TEST_DATABASE` permite escolher um nome nesse prefixo.
O teste aborta se a base já existir e preserva seus objetos ao concluir.
O cenário `--disconnect-check` exige o nome explícito de uma base de validação
criada pelo teste principal; encerra somente a sessão que o próprio teste iniciou.

## Funcionalidades e limites

- Abas, arquivos UTF-8, execução da seleção ou documento completo.
- GO/GO n sem dividir strings, identificadores ou comentários.
- Uma sessão compartilhada entre abas para USE, transações e #temporárias.
- Conexão separada para metadados: bancos, tabelas, views, procedures, triggers e funções.
- Resultados múltiplos, PRINT, erros parciais, cancelamento e timeout.
- Grade com cópia e CSV. Limite de exibição explícito; nenhum TOP é injetado.
- Controles de listar/iniciar/parar containers existentes, sem exclusão de volumes.
- Artes originais do kit visual, logo Any/Dark e ícone de Dock por aparência.

Não replica todos os recursos do SSMS: sem designers, edição inline, diagramas,
planos gráficos, restore assistido, SQLCMD, autenticação Windows ou Python.
O destaque de sintaxe é simplificado. `GO /* comentário */` não é suportado;
use GO em linha própria ou com comentário `--`. Abas não são restauradas ao
reabrir; salve seus SQLs. Cancelar não executa ROLLBACK automaticamente.
Resultados são limitados a aproximadamente 32 MiB, 64 conjuntos e 512 colunas;
células grandes são limitadas e binários são exibidos em hexadecimal.

## Organização

- `Sources/SQLGarden`: interface e serviços macOS.
- `Sources/StudioCore`: modelos, escaping, CSV e parser de lotes.
- `Sources/SQLBridge`: ponte C carregando unixODBC em runtime.
- `Sources/Launcher`: bootstrap nativo para OpenSSL 3, específico da arquitetura.
- `Resources`: Info.plist, ícones e catálogo das logos.
- `Design`: kit visual original, sem redesenho ou efeitos adicionados.
- `scripts`: testes, dependências, Express opcional e empacotamento reproduzível.
- `Tests`, `examples`, `docs`: validação, SQLs de estudo e arquitetura.

## Licenças

Copyright © 2026 Victor. SQLGarden e as artes fornecidas com o projeto são
publicados sob a licença MIT de `LICENSE`. Bibliotecas e produtos externos
continuam sob suas licenças; consulte `THIRD_PARTY_NOTICES.md`. Este projeto
não redistribui Docker, SQL Server, driver Microsoft ou bibliotecas Homebrew.
