# SQLGarden 0.2.0 — instalação e uso no Mac

**Desenvolvido por Victor · Código aberto, licença MIT.**

O SQLGarden é uma interface nativa para escrever e executar T-SQL no Microsoft
SQL Server Express. O banco de dados fica no servidor ao qual você se conecta.
O aplicativo não inclui Python e não executa código Python.

## 1. O que vem nesta entrega

- `SQLGarden-0.2.0-Universal.dmg`: imagem de instalação, com app e atalho para Aplicativos.
- `INSTALACAO.md`: este guia.
- `SQLGarden-fonte/`: projeto completo, artes originais, licença, testes e scripts de build.
- `SHA256SUMS.txt`: soma de verificação dos arquivos da entrega.

O DMG também contém **Instalar Dependencias.command** e
**Criar SQL Server Express.command**. São scripts legíveis de Terminal:
o primeiro instala apenas as bibliotecas do cliente; o segundo é opcional e
cria um servidor local somente após você confirmar. Nenhum contém uma senha.

## 2. Requisitos e compatibilidade

- macOS 14 Sonoma ou posterior; Mac Apple Silicon (M1 ou posterior) ou Intel.
- O mesmo app universal contém código `arm64` e `x86_64`; o Mac escolhe a versão nativa.
- Internet para baixar as dependências e, se necessário, a imagem do servidor.
- unixODBC, OpenSSL 3 e Microsoft ODBC Driver 18, instalados com Homebrew.
- Um SQL Server disponível: o da faculdade, um já instalado ou um container local.

**Não é necessário instalar Python nem o Xcode completo para usar o app.**
O Homebrew pode precisar das Command Line Tools da Apple. Apenas quem quiser
compilar o código-fonte precisa das ferramentas Swift/Xcode correspondentes.

Esta versão foi executada e testada em Apple Silicon com macOS 27.0.1.
As duas arquiteturas foram compiladas; os limites exatos dos testes estão em
`SQLGarden-fonte/docs/VALIDACAO_MAC.md`. Compilar para Intel/macOS 14 não comprova
que o app foi executado fisicamente em todas essas combinações.

## 3. Instalar o aplicativo

1. Extraia o ZIP e abra `SQLGarden-0.2.0-Universal.dmg`.
2. Arraste **SQLGarden.app** para **Aplicativos**. Se já usa o SQLGarden, salve
   suas consultas e encerre a versão anterior antes de substituir o app.
3. Ejete a imagem DMG depois de copiar. Abra o app a partir de Aplicativos.
4. Na primeira instalação, prepare o driver conforme a seção seguinte.

### Aviso do macOS na primeira abertura

Este pacote tem assinatura **ad hoc**, para integridade local. Ainda não tem
certificado Apple Developer ID nem notarização Apple. Isso é diferente de um
app notarizado, e o macOS pode bloquear a primeira abertura após o download.

Se você conhece a origem do arquivo e conferiu a entrega de Victor, tente abrir
o app, depois vá a **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo
Assim** e confirme a abertura. Use apenas o fluxo oferecido pelo macOS.
Não desative o Gatekeeper, não remova a quarentena por comandos e não execute
scripts que reduzam a segurança do sistema.

Se o macOS disser que o arquivo está **danificado**, a assinatura for inválida
ou não oferecer uma abertura autorizada, interrompa a instalação e peça uma
cópia íntegra ao autor. Não trate esse aviso como se fosse somente falta de notarização.

Referência: [abrir apps com segurança no Mac](https://support.apple.com/pt-br/102445).

## 4. Instalar as dependências do cliente

O app não redistribui o driver proprietário da Microsoft. Cada pessoa o instala
pelo repositório oficial e aceita a licença no próprio Mac.

1. Se não tiver Homebrew, instale seguindo [brew.sh](https://brew.sh).
   O instalador oficial explica os comandos e poderá solicitar as ferramentas da Apple.
2. Abra **Instalar Dependencias.command**, incluído no DMG. Também está disponível
   no menu **Help/Ajuda → Instalar dependências do SQL Server…** do app.
3. Leia o que será instalado e a licença do driver. Digite `SIM` somente se concordar.
4. Aguarde o Terminal terminar e mostrar **Pronto**. Reabra o SQLGarden.

O script detecta Apple Silicon/Intel e usa o Homebrew nativo correspondente:
`/opt/homebrew` ou `/usr/local`. Instala unixODBC, **OpenSSL 3** e
`microsoft/mssql-release/msodbcsql18`. Ele não cria servidor nem modifica bancos.
Não solicita a senha do SQL Server. Uma senha administrativa solicitada pelo
Homebrew pertence ao fluxo de instalação do macOS, não à conexão SQL.

Alternativa para quem já usa Terminal:

```bash
brew install unixodbc openssl@3
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install microsoft/mssql-release/msodbcsql18
```

A versão 18.7 do driver apresentou incompatibilidade com o alias OpenSSL 4.
O SQLGarden seleciona **OpenSSL 3 apenas no seu próprio processo**, sem alterar
os links globais do Homebrew. Use o app instalado; executar diretamente o
binário interno pelo Terminal pula esse inicializador.

## 5. Escolher o servidor

### A. A faculdade já fornece um SQL Server

Você só precisa das dependências do cliente. Peça ao professor servidor, porta,
usuário, senha e banco inicial. Docker e um servidor local não são necessários.
Se houver acesso por VPN, conecte a VPN conforme a orientação da instituição.

### B. Você já tem SQL Server em Docker

Abra Docker Desktop e inicie o container existente. Use a **porta publicada no
Mac**, que pode ser diferente de 1433. Não crie outro container para testar o app.
Não apague containers, volumes ou bancos para corrigir uma falha de conexão.

### C. Você precisa de um Express local novo

1. Instale [Docker Desktop para Mac](https://www.docker.com/products/docker-desktop/),
   escolhendo Apple Silicon ou Intel. Confira os termos aplicáveis ao seu uso.
2. Abra Docker Desktop e aguarde o engine ficar pronto.
3. No Apple Silicon, o motor SQL Server é x64 e depende de emulação/tradução.
   Quando necessário, siga as opções de virtualização e emulação da sua versão
   do Docker. Não mude configurações de um ambiente que já funciona sem motivo.
4. Abra **Criar SQL Server Express.command** incluído no DMG.
5. Leia o resumo e a licença do SQL Server. Digite `SIM` somente se concordar.
6. Crie e repita uma senha de pelo menos 12 caracteres, com maiúscula, minúscula,
   número e símbolo. Guarde-a: o instalador não imprime nem salva a senha em arquivo.
7. Aguarde o download e a inicialização. Confirme o container no Docker Desktop.

O script usa a imagem oficial `mcr.microsoft.com/mssql/server:2022-latest`, edição
**Express**, container `sqlgarden-express` e volume `sqlgarden-express-data`.
Publica somente `127.0.0.1:1433`, limita o container a 3 GiB/2 CPUs e define
2048 MiB para a memória do SQL Server. O Docker precisa de memória adicional
para o Linux. A política `unless-stopped` reinicia o container quando o engine
voltar, exceto se você o tiver parado manualmente.

Se já existir um container com esse nome criado pelo SQLGarden, o script oferece
apenas iniciá-lo. Não troca sua senha. Se existir um volume sem o container,
um container de outra origem com o mesmo nome ou a porta estiver ocupada,
o script interrompe e preserva os dados. Ele não contém comandos de exclusão.

**Limite importante:** a Microsoft não oferece suporte oficial a SQL Server
x64 emulado no Apple Silicon. O funcionamento foi validado neste Mac para estudo;
isso não garante compatibilidade com todas as versões de Docker/macOS.
Se a imagem não iniciar em seu Mac, preserve o volume e use o servidor da
faculdade ou peça orientação; não substitua automaticamente por outro banco.

Como na instalação padrão em Docker, a senha inicial faz parte dos metadados
de ambiente do container, acessíveis a quem controla o daemon. Não compartilhe
`docker inspect` completo nem inclua esse conteúdo em capturas de erro.

## 6. Conectar no SQLGarden

Clique em **Conectar**. Para o Express instalado pelo script:

| Campo | Valor |
| --- | --- |
| Nome | Um nome de sua escolha |
| Servidor | `127.0.0.1` |
| Porta | `1433` |
| Banco inicial | `master` |
| Usuário | `sa` |
| Senha | A senha que você criou no instalador |

A conexão é criptografada. **Confiar no certificado do servidor** pode ficar
ativado para o Docker local com certificado próprio. Em servidor remoto com
certificado válido, desative e use o nome do servidor correspondente ao certificado.
Não ative essa opção para contornar um erro inesperado num servidor desconhecido.

**Salvar senha no Chaves** é opcional. A senha não vai para o projeto,
UserDefaults, SQL ou logs. Desmarcar a opção e conectar remove o item salvo
para aquela conexão. Atualizações de um app assinado ad hoc podem fazer o
Chaves pedir nova autorização: confirme apenas para o SQLGarden legítimo.

Cada pessoa usa a própria senha. O pacote distribuído não inclui o perfil,
as credenciais, o container nem os bancos do Mac onde o app foi compilado.

## 7. Primeira consulta e trabalho nas aulas

```sql
SELECT SERVERPROPERTY('Edition') AS Edicao,
       SERVERPROPERTY('ProductVersion') AS Versao;
GO
SELECT DB_NAME() AS BancoAtual, N'ação 🎓' AS Unicode;
```

Use **⌘↩** ou **Executar**. Uma seleção executa somente o trecho selecionado;
sem seleção, executa o arquivo inteiro. `GO` separa lotes no cliente e `GO 2`
repete explicitamente o lote duas vezes. A execução para no primeiro erro.

Para trabalhar, crie uma base com nome próprio, por exemplo `MinhaAula`, e use
`USE MinhaAula;` ou escolha a base na lateral. Clicar numa tabela abre uma
consulta; revise e execute. A ação não modifica a tabela automaticamente.
Os exemplos que criam objetos devem ser usados somente numa base de teste nova.

Todas as abas compartilham **uma sessão**: `USE`, transações e tabelas
`#temporarias` afetam as consultas seguintes de outras abas. O explorador tem
uma conexão separada. Não há COMMIT, ROLLBACK ou reenvio automáticos.

| Ação | Atalho |
| --- | --- |
| Nova consulta | ⌘N |
| Abrir `.sql` | ⌘O |
| Salvar | ⌘S |
| Executar seleção/arquivo | ⌘↩ |
| Parar consulta | ⌘. |
| Fechar aba | ⇧⌘W |
| Copiar linhas selecionadas da grade | ⌘C |

Use o seletor para alternar entre múltiplos resultados e o painel **Mensagens**
para PRINT, contagens e erros. **CSV** exporta o conjunto exibido. O limite de
linhas é de exibição e não acrescenta TOP à sua consulta. Se aparecer **Exibição
limitada**, o CSV também será parcial. NULL é campo sem aspas; texto vazio é `""`.

Salve seus scripts `.sql` em UTF-8. As abas não são restauradas automaticamente
na próxima abertura. O app avisa sobre alterações não salvas ao encerrar.
Parar uma consulta não desfaz automaticamente tudo que já foi executado.

Aparência: use **View/Visualizar → Aparência → Sistema, Claro ou Escuro**.
A logo interna e o ícone do Dock acompanham a aparência do app. O ícone
persistente do Finder usa a arte clara do kit, inclusive no modo escuro;
isso não é um ícone adaptativo do Icon Composer.

## 8. Problemas comuns

- **Driver/arquivo ODBC não encontrado:** execute o instalador de dependências
  no Homebrew nativo, confira a mensagem final e reabra o app.
- **OpenSSL não pôde ser carregado:** confirme `openssl@3` instalado e abra o
  `.app` normalmente. Não repointe symlinks globais de OpenSSL.
- **Conexão recusada/timeout:** confira se Docker/servidor iniciou, host e porta
  publicados. Após iniciar um container, aguarde o SQL Server ficar pronto.
- **Login failed:** confira usuário, senha e banco. O app não redefine a senha
  de containers existentes. Peça as credenciais ao responsável pelo servidor.
- **Erro de certificado:** confira a origem do servidor e a orientação da seção 6.
- **Porta ocupada ou volume já existe:** preserve-os e verifique o ambiente
  existente. O instalador não apaga nem reaproveita volumes automaticamente.
- **Consulta longa:** use Parar. O cancelamento depende do driver/servidor e o
  timeout é uma proteção adicional. Verifique o estado da transação depois.
- **Memória:** os 3 GiB do container são um limite, não o uso fixo do banco. A VM
  tem seu próprio limite e cache; o Docker VMM exige pelo menos 4 GiB para a VM.
  Pare o servidor e feche Docker quando não estiver usando. Alterar limites exige
  novos testes; não diminua a memória de um ambiente importante sem verificar.

Antes de pedir ajuda, envie versão do SQLGarden/macOS, arquitetura do Mac e o
texto do erro. Remova senhas, dados pessoais e resultados privados. Não envie
uma exportação completa dos metadados do container.

## 9. Atualizar, desinstalar e contribuir

Para atualizar, salve as consultas, encerre o app e substitua-o em Aplicativos.
O app não migra nem apaga bancos. O perfil e o Chaves pertencem ao seu Mac.

Para remover apenas a interface, encerre e mova SQLGarden.app para a Lixeira.
Isso **não remove o SQL Server, seus volumes, bancos, arquivos SQL ou credenciais
salvas**. Trate a exclusão de dados como uma decisão separada e faça backup.

O código está em `SQLGarden-fonte/`. Leia `README.md`, `CONTRIBUTING.md` e
`docs/VALIDACAO_MAC.md`. A licença MIT cobre o SQLGarden; driver, SQL Server,
Docker e Homebrew mantêm seus próprios termos. Não há vínculo ou endosso Microsoft/Apple.

## Referências oficiais

- [Driver Microsoft no macOS](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/install-microsoft-odbc-driver-sql-server-macos)
- [SQL Server em containers e suporte à emulação](https://learn.microsoft.com/en-us/sql/linux/containers/deploy)
- [Virtualizadores do Docker Desktop](https://docs.docker.com/desktop/features/vmm/)
- [Memória e configurações Docker](https://docs.docker.com/desktop/settings-and-maintenance/settings/)
- [Homebrew](https://brew.sh)
