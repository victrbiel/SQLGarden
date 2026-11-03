# SQLGarden

Cliente nativo de macOS para estudar e trabalhar com **SQL Server**. Interface
em SwiftUI/AppKit, consultas T-SQL e conexão ao SQL Server que você já executa
no Docker. Não inclui Python integrado nesta versão.

**Estado em 19/10/2026: compilado e validado neste Mac Apple Silicon.**
A versão ARM64 abriu em SwiftUI/AppKit. Passaram 12 testes da ponte C,
9 testes Swift e 14 verificações contra SQL Server Express real, além dos
fluxos de interface registrados em `docs/VALIDACAO_MAC.md`.

Neste Mac, o SQL Server 2022 Express foi instalado após autorização expressa,
pois o Docker estava vazio. A conexão preparada usa `127.0.0.1:1433`, usuário
`sa`, senha aleatória no Chaves e container `sqlgarden-express`.
Abra `dist/SQLGarden.app`, clique em **Conectar** e confirme a conexão.
O Docker Desktop precisa estar aberto. Os testes usam somente bases
`SQLGarden_Validacao_…`; nenhum banco ou volume foi apagado.

## Começar no Mac

1. Extraia a pasta SQLGarden. Abra essa pasta no Codex.
2. Leia `COMECE_AQUI_CODEX.md` ou envie seu conteúdo ao Codex.
3. Com seu Docker funcionando, execute no Terminal dentro da pasta:

```bash
bash scripts/setup-mac.sh
bash scripts/test.sh
bash scripts/build-app.sh
open dist/SQLGarden.app
```

O instalador prepara unixODBC, **OpenSSL 3** e o **Microsoft ODBC Driver 18** via Homebrew.
Ele não instala o Docker, cria containers nem modifica os bancos existentes.
Se as dependências já estão instaladas, pode pular o setup. Você precisa de
macOS 14 ou posterior, ferramentas Swift 5.9 ou posteriores e Python 3 somente
para o teste auxiliar da ponte C. O app não usa Python.

No app, clique em **Conectar**. Para um container publicado em `1433`, use
`localhost`, porta `1433`, usuário e senha já configurados no SQL Server.
Informe a porta publicada no Mac, que pode ser diferente da porta interna.
O banco inicial padrão é `master`.

O certificado próprio do Docker local exige normalmente “Confiar no certificado
do servidor”. A conexão continua criptografada. A senha pode ser salva no
Chaves; não é gravada no UserDefaults nem incluída nos arquivos do projeto.

## O que a primeira versão implementa

- Janela nativa com barra lateral, abas de consultas, modo claro/escuro do sistema.
- Conexão por autenticação SQL Server usando o driver oficial da Microsoft.
- Bancos acessíveis, tabelas, views, procedures, triggers e funções no explorador.
- Abrir consulta para um objeto e consultar a definição ou colunas.
- Abrir e salvar arquivos `.sql` em UTF-8.
- Editor com destaque básico de T-SQL e execução da seleção ou do arquivo inteiro.
- Separação de `GO` e `GO n`, respeitando strings, identificadores e comentários.
- Resultados múltiplos, mensagens de `PRINT`, erros e contagem de linhas afetadas.
- Grade de resultados com cópia de linhas e exportação CSV.
- Sessão persistente para transações, `USE` e tabelas `#temporarias`.
- Lista de containers existentes e controles de iniciar/parar.
- Senha opcional no Chaves e parâmetros da conexão salvos entre aberturas.

## Uso rápido

| Ação | Atalho |
| --- | --- |
| Nova consulta | ⌘N |
| Abrir SQL | ⌘O |
| Salvar consulta | ⌘S |
| Executar seleção ou consulta inteira | ⌘↩ |
| Parar consulta | ⌘. |
| Fechar aba com verificação de alterações | ⇧⌘W |
| Copiar linhas selecionadas na grade | ⌘C |

Todas as abas compartilham **uma sessão de execução**. Por exemplo, `USE MinhaBase`
em uma aba muda a base das consultas seguintes nas demais. O explorador usa
outra conexão, sem executar consultas de catálogo na sessão do editor.
Variáveis `@locais` duram o lote; tabelas `#temporarias` duram a sessão.
O separador `GO` encerra um lote, mas mantém a conexão.

Para criar uma base, escreva `CREATE DATABASE Nome;` no editor, execute e
atualize o explorador. Duplo clique não é necessário: clicar num objeto abre
uma consulta, que você revisa e executa. Não há execução automática de SQL
ao clicar em tabelas.

O app não cria COMMIT/ROLLBACK extras nem repete comandos automaticamente
após falhas. Se uma consulta falhar no meio de uma transação explícita,
verifique o estado e execute `ROLLBACK` ou `COMMIT` conforme a atividade.
Cancelar uma consulta não desfaz automaticamente todos os efeitos anteriores.

## Escopo e limites

Esta é uma ferramenta de estudo em desenvolvimento, não uma réplica completa
do SSMS. Não implementa designers visuais de tabela, edição direta das células,
diagramas ER, planos de execução gráficos, restore assistido, SQLCMD `:r`,
autenticação integrada do Windows, múltiplos perfis ou Python embutido.

O destaque de sintaxe é visual e simplificado; não é um parser completo de T-SQL.
`GO /* comentário */` não é aceito: use `GO` numa linha própria ou com `-- comentário`.
Não há restauração automática das abas após fechar o app. Consultas não salvas
geram aviso ao fechar aba ou encerrar normalmente. Salve seus arquivos durante o trabalho.

Há limite configurável de linhas **exibidas** por resultado. Isso não injeta
`TOP` nem modifica a consulta: o SQL Server continua executando o SQL original.
Células muito grandes são limitadas, e binários aparecem em hexadecimal.
O máximo de exibição é aproximadamente 32 MiB e 64 conjuntos de resultados.
Atingir esses limites interrompe a execução e avisa que comandos pendentes
podem não ter rodado. Exporte CSV somente quando a grade não estiver limitada
se precisar do resultado completo. No CSV, NULL é campo sem aspas e texto vazio
é `""`; os consumidores podem tratar ambos da mesma forma.

O cancelamento usa `SQLCancel`, depende do driver/servidor e pode não ser
imediato; o timeout é uma segunda proteção. As consultas do explorador também
podem levar alguns segundos em bancos remotos. Recursos de sistema não foram
medidos: o maior consumo continuará sendo do Docker/SQL Server.

## Estrutura

```text
Sources/SQLGarden/   Interface e serviços macOS
Sources/StudioCore/ Conexão, SQL e separação de lotes (sem SwiftUI)
Sources/SQLBridge/  Ponte C para unixODBC carregado em tempo de execução
Tests/              Testes Swift e testes C com driver simulado
scripts/            Dependências, testes e criação do .app
examples/           Scripts para validação manual no SQL Server
docs/               Arquitetura e checklist no Mac
```

Não existem pacotes Swift externos. A ponte carrega unixODBC dos caminhos
usuais do Homebrew em Apple Silicon ou Intel. O driver da Microsoft continua
sendo uma dependência local, instalado separadamente. Não há binários de
terceiros, servidor, senha ou código do SQL Server redistribuídos no projeto.

## Docker e Apple Silicon

O cliente pode ser nativo ARM64; o motor SQL Server em container continua
sendo x64. A Microsoft não testa nem oferece suporte a SQL Server emulado
no Apple Silicon. Como você já tem um ambiente funcionando, reutilize-o.
Não substitua seu container nem remova volumes para testar o app.

O app se conecta a SQL Server de outras edições também, porém não verifica
automaticamente se a instância é Express. Para conferir:

```sql
SELECT SERVERPROPERTY('Edition') AS Edicao,
       SERVERPROPERTY('ProductVersion') AS Versao;
```

## Referências técnicas

- [Microsoft ODBC no macOS](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/install-microsoft-odbc-driver-sql-server-macos)
- [Programação ODBC em macOS/Linux](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/programming-guidelines)
- [Suporte de SQL Server Linux e limitações de arquitetura](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup)

Não é necessário Apple Developer Program pago para compilar e testar localmente.
O script cria uma assinatura ad hoc. Distribuição pública, assinatura com
Developer ID, notarização e empacotamento das dependências são etapas futuras.


## Correções verificadas no Mac

O driver ODBC 18.7.1.1 falhou quando o alias `openssl` apontava para OpenSSL 4.
O `.app` agora usa um pequeno inicializador nativo que seleciona OpenSSL 3 no
ambiente **somente do processo**. Os links globais do Homebrew e as políticas
TLS do sistema permanecem como estavam. Executar o binário Swift diretamente
ou `swift run` não passa por esse inicializador; para o fluxo normal, abra o `.app`.

O cliente define `LC_CTYPE` UTF-8 uma vez antes de criar sessões ODBC, corrigindo
acentos corrompidos observados no teste real. O comando nativo `copy:` também
corrige ⌘C na grade. A barra de status mostra a porta sem separador de milhar.

## Repetir a validação real

`bash scripts/test.sh` não precisa de um servidor. O teste real é separado:
`bash scripts/test-integration.sh`. Ele exige `SQLGARDEN_INTEGRATION_PASSWORD`
no ambiente e aceita `SQLGARDEN_TEST_DATABASE` com prefixo
`SQLGarden_Validacao_`. Informe a senha por uma leitura silenciosa no Terminal;
não a inclua no comando, no histórico ou no código. O script cria uma base
nova e aborta se ela já existir. Preserva a base ao terminar, inclusive em falhas.
Use um nome novo ao repetir. O cenário adicional `--disconnect-check` usa
somente `SQLGarden_Validacao_20261019_Final`, cria sua própria tabela e encerra
apenas a sessão iniciada pelo teste para conferir ausência de retry. O app não incorpora Python; Python só é usado
pelo teste C já existente.

O provisionamento opcional `--provision-local-server` é exclusivo da instalação
local: recebe `SQLGARDEN_LOCAL_PASSWORD` no ambiente, aceita apenas a conexão
fixa `127.0.0.1:1433/sa` e só atua quando ainda não há um perfil salvo. O próprio
app salva sua credencial no Chaves. O fluxo normal continua sendo **Conectar**.
Ele não instala nem recria servidores.
