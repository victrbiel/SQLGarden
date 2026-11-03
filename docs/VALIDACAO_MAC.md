# Validação no Mac — 19/10/2026

## Ambiente confirmado

- macOS 27.0.1 (26A434), ARM64; Xcode 27.1 (27A9275), Swift 6.4.
- unixODBC 2.3.14; Microsoft ODBC Driver 18.7.1.1 ARM64.
- OpenSSL 3.6.5 no processo SQLGarden; o alias global OpenSSL 4.0.3 foi preservado.
- Docker Engine 29.7.2 no Docker Desktop; VM ARM64 com cerca de 3,8 GiB de RAM.
- SQL Server 2022 Express Edition (64-bit), 16.0.4305.5, Linux x64 emulado.
- Imagem `mcr.microsoft.com/mssql/server:2022-latest`, digest
  `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.

O contexto Docker estava vazio: nenhum container, imagem ou volume listado.
Após o usuário autorizar instalar o Express se ausente, foi criado somente
`sqlgarden-express`, com volume `sqlgarden-express-data`, porta
`127.0.0.1:1433:1433`, limite de 3 GiB/2 CPUs, memória SQL de 2048 MiB e
restart `unless-stopped`. Nenhum container ou volume anterior foi substituído.
Não foi alterada a preferência de iniciar Docker no login do Mac.

## Testes automatizados e driver real

- [x] `bash scripts/test.sh`: 12 testes C e 9 testes StudioCore, zero falhas.
- [x] `bash scripts/build-app.sh`: release ARM64 SwiftUI/AppKit compilado.
- [x] `codesign --verify --deep --strict`: assinatura ad hoc válida.
- [x] `bash scripts/test-integration.sh`: 14 verificações reais passaram.
- [x] Conexão real confirma Express e versão; a consulta à própria sessão em
  `sys.dm_exec_connections` devolveu `encrypt_option=TRUE` na interface.
- [x] `CREATE DATABASE` apenas numa base exclusiva de validação; `USE` persistente.
- [x] `examples/01_conexao.sql`: versão, sessão, PRINT, Unicode, NULL e vazio.
- [x] `examples/02_objetos.sql`: duas tabelas, view, procedure, trigger e auditoria.
- [x] `examples/03_sessao.sql`: temporária entre chamadas, GO e ROLLBACK; `@@TRANCOUNT=0`.
- [x] `examples/04_resultados.sql`: cinco resultados, texto longo, binário, GO na string e GO 2.
- [x] Metadados em conexão separada: cinco objetos listados sem mudar a base do editor.
- [x] Erro intencional mantém resultado parcial e impede os lotes seguintes.
- [x] Limite de uma linha fica explícito e mantém o resultado seguinte.
- [x] SQLCancel interrompe WAITFOR; consulta seguinte funciona na mesma sessão.
- [x] CSV derivado de dados reais preserva Unicode, aspas, NULL e vazio.
- [x] Reconexão abre sessão nova e libera a tabela temporária anterior.

As evidências estão em `docs/evidencias/mac-tests.log`, `mac-build.log` e
`mac-integration.log`, mais `mac-disconnect.log` para o cenário adicional de
perda de transporte. Os 12 testes simulados originais continuam sendo testes
de ABI/ponte, separados das 14 verificações reais.

## Testes pela interface

- [x] App abriu pelo LaunchServices, com janela SwiftUI/AppKit, a partir de
  `Downloads/SQLGarden/dist/SQLGarden.app`, sem o processo instalador.
- [x] Layout legível em escuro e claro. Claro foi testado numa cópia temporária
  com `NSRequiresAquaSystemAppearance`; o modo do sistema não foi alterado.
- [x] Splitter foi redimensionado e a barra lateral recolhida/reaberta.
- [x] Conexão real pelo app e catálogo com bases e objetos de teste.
- [x] Troca de banco pelo explorador atualiza a barra do editor.
- [x] Clicar na tabela abre SQL qualificado, sem executá-lo automaticamente.
- [x] Seleção de uma linha contendo emoji executa apenas aquela seleção.
- [x] Botão Parar interrompe WAITFOR e mostra HY008 sem travar a janela.
- [x] ⌘C copia a linha da grade; colagem em outra aba confirma o conteúdo.
- [x] Exportação CSV pelo NSSavePanel; bytes UTF-8/CRLF, aspas, NULL e vazio conferidos.
- [x] Abrir `.sql` com nome Unicode e espaços, executar e ver dois resultados.
- [x] Criar aba, editar Unicode, salvar arquivo com espaço, esvaziar, salvar e
  conferir arquivo de zero bytes.
- [x] Encerrar com consultas não salvas mostra aviso; Voltar mantém o editor.
- [x] Docker lista, para e inicia o container criado nesta tarefa.
- [x] Reconexão após reiniciar o container funciona e preserva as bases de teste.
- [x] Senha salva pelo próprio app reaparece mascarada em Conectar, inclusive
  após encerrar e reabrir o pacote da pasta Downloads.
- [x] Desmarcar “Salvar senha” e conectar remove o item opcional:
  consulta sem acesso ao segredo retornou `errSecItemNotFound` (-25300).
- [x] Perfil persistido foi inspecionado sem campo de senha.

## Problemas reais corrigidos

1. ODBC falhou ao carregar OpenSSL 4. A seleção de OpenSSL 3 agora é local ao
   processo, por inicializador nativo do bundle. `setup-mac.sh` instala a versão
   3 explicitamente. O driver continuou com `Encrypt=yes`.
2. Unicode chegava como `aÃ§Ã£o`. Configurar LC_CTYPE UTF-8 antes de conectar
   corrigiu acentos e emoji, confirmado no servidor e na grade.
3. ⌘C era interceptado pelo menu e não copiava a grade. Implementado `copy:`.
4. A porta aparecia `1.433`; agora aparece `1433` na barra de status.
5. Provisionar um item do Chaves por utilitário externo provocou uma solicitação
   de autorização. A instalação final usa o próprio app para criar seu item.
   Nenhum diálogo de segurança foi automatizado nem proteção do Chaves reduzida.

## Dados de teste e credenciais

Duas bases novas foram preservadas:

- `SQLGarden_Validacao_20261019`: criada na tentativa inicial interrompida ao
  detectar Unicode incorreto; não contém os objetos dos exemplos.
- `SQLGarden_Validacao_20261019_Final`: contém somente os objetos `SG_` dos testes,
  incluindo `SG_TransporteSemRetry` do cenário de desconexão.

Nenhum banco foi apagado. Nenhum arquivo pessoal foi aberto para testar SQL.
A busca exata pelo segredo gerado em 3.113 arquivos de trabalho/entrega
(fontes, logs, caches e binários) não encontrou ocorrências.
A senha aleatória não foi escrita em fontes, arquivos de configuração ou logs.
Ela está no Chaves. Como na instalação padrão de SQL Server em Docker, a senha
inicial também é uma variável dos metadados do container, acessível a quem já
controla o daemon; esses metadados secretos não foram impressos.

A conexão final é `127.0.0.1:1433`, `sa`, `master`. O item usado pelo app tem
serviço `app.sqlgarden.connection`, conta `127.0.0.1:1433/sa`. Há uma cópia de
recuperação criada pelo instalador no serviço `app.sqlgarden.local-server`,
conta `sqlgarden-express`. A entrada auxiliar `localhost:1433/sa`, criada antes
da correção de provisionamento, ficou sem uso; sua remoção foi recusada pelo
Chaves (-25244) e não foi forçada. Não foram lidas credenciais pessoais.

## Limites ainda abertos

- Perda de transporte foi simulada com KILL de uma sessão criada pelo próprio
  teste: o INSERT já confirmado ocorreu uma única vez e a reconexão explícita
  funcionou. Não foi desligada a rede física nem testado failover remoto.
- Não foram testados logins restritos, servidor remoto com certificado público,
  limites máximos de 32 MiB/64 resultados no driver real ou carga prolongada.
- Executáveis Swift e inicializador declaram mínimo macOS 14.0. O teste de
  execução foi neste macOS 27.0.1; macOS 14 não foi testado fisicamente.
- Assinatura local ad hoc; não há Developer ID, notarização ou pacote universal.
  Recompilar altera a identidade ad hoc e pode exigir nova autorização do Chaves.
- O funcionamento x64 emulado foi validado nesta máquina. A Microsoft não oferece
  suporte ao SQL Server nesses ambientes de emulação; isso não equivale a suporte
  oficial nem validação de produção.

Referências: [OpenSSL 4 e ODBC 18.7 no repositório Microsoft](https://github.com/microsoft/homebrew-mssql-release/issues/113),
[programação ODBC e charset](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/programming-guidelines),
[suporte a containers](https://learn.microsoft.com/en-us/sql/linux/containers/deploy).
