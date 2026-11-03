# Validação SQLGarden 0.2.0

Data: 19 de outubro de 2026. Desenvolvido por Victor.

## Ambiente e evidência comprovada

Mac Apple Silicon, macOS 27.0.1; Microsoft ODBC Driver 18.7.1.1, unixODBC
2.3.14 e OpenSSL 3.6.5. SQL Server 2022 Express 16.0.4305.5 em Docker,
imagem x64 oficial, acessível somente por 127.0.0.1. Credenciais não integram
este relatório nem o pacote. O Docker foi encerrado após os testes.

- Build release universal concluído. Executável Swift e inicializador C contêm
  arm64 e x86_64; ambos declaram macOS mínimo 14.0.
- Assinatura ad hoc conferida com codesign --verify --deep --strict, inclusive
  na cópia montada do DMG. Sem certificado Developer ID ou notarização.
- 12 testes da ponte C aprovados com driver simulado: cancelamento, limites,
  resultados parciais, Unicode, NULL/vazio, binários e diagnósticos.
- 9 testes StudioCore aprovados nativamente: parser de lotes, validação,
  escaping e exportação. Os mesmos 9 passaram com XCTest x86_64 sob tradução.
  O runner Swift padrão era arm64 e não carregava o bundle Intel; a execução
  Intel foi feita explicitamente pelo runner x86_64 do Xcode.
- 14 verificações com servidor e driver reais aprovadas. Incluem exemplos,
  USE persistente, transações, #temporárias, catálogo separado, GO 2, CSV,
  Unicode, limite de linhas, cancelamento e erro com resultado parcial.
- Cenário adicional: KILL da sessão criada pelo próprio teste provocou falha
  de transporte; o cliente não repetiu INSERT e permitiu reconexão explícita.
- Testes criaram somente base com prefixo SQLGarden_Validacao_. Objetos de
  teste foram preservados; nenhum banco ou volume foi excluído.
- Interface aberta em cópia de QA com identificador e preferências isolados:
  logo original em claro/escuro, seletor de aparência e Sobre com Victor,
  versão 0.2.0, MIT e ícone ativo correspondente à aparência.
- Encerramento com consulta alterada exibiu aviso; Voltar preservou o texto;
  Encerrar e descartar fechou apenas a cópia de QA.
- Ícones ICNS copiados byte a byte do kit; artes sem redesenho ou efeitos.
- Scripts passaram por bash -n. Diagnóstico --check confirmou dependências
  instaladas e o servidor existente. Os instaladores não foram executados
  integralmente em um Mac novo, pois isso alteraria o ambiente de validação.
- DMG passou por hdiutil verify e montagem somente leitura. Binário e guia
  montados idênticos aos originais; atalho Applications aponta /Applications;
  scripts opcionais e licença presentes. Não há Python dentro do app.

Logs de teste sanitizados estão em evidencias/. Eles não contêm senhas,
perfis pessoais ou caminhos do usuário que compilou o aplicativo.

## Limites e verificações ainda necessárias

Não houve teste físico em Mac Intel, macOS 14 ou Mac recém-instalado. Testar
código x86_64 sob tradução não equivale a testar hardware Intel. O app completo
foi executado em arm64; a conexão ODBC Intel precisa de validação física com
as dependências Intel instaladas. Build universal não garante todos os cenários.

O fluxo pós-download com Gatekeeper/quarentena não foi reproduzido em outro
Mac. A assinatura ad hoc é uma limitação de distribuição; siga o guia, sem
reduzir as proteções do sistema. A Microsoft não oferece suporte oficial à
emulação do SQL Server em Apple Silicon. O teste local comprova o ambiente
acima, não suporte oficial nem compatibilidade com toda versão do Docker.

A licença MIT acompanha o código aberto. Dependências permanecem externas,
com seus próprios termos. Nenhum servidor, volume, perfil ou senha é entregue.
