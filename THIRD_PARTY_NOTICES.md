# Componentes e licenças

SQLGarden foi desenvolvido por Victor e é distribuído sob MIT (`LICENSE`).
O kit visual enviado para o projeto é preservado como recurso original.

O pacote do app contém código do SQLGarden e imagens do projeto. Não contém
executáveis ou bibliotecas de terceiros. As dependências são instaladas
separadamente e mantêm suas próprias licenças:

- Microsoft ODBC Driver 18 e Microsoft SQL Server Express: termos Microsoft;
  os instaladores opcionais apresentam os links e exigem aceite explícito local.
- unixODBC: termos do projeto unixODBC, distribuído pelo Homebrew.
- OpenSSL 3: Apache License 2.0, distribuído pelo Homebrew.
- Docker Desktop: termos da Docker, instalado separadamente pelo usuário.
- Homebrew: licença e termos do próprio projeto.
- Swift/SwiftUI/AppKit e frameworks do sistema: componentes Apple/Swift usados
  conforme as ferramentas e o sistema operacional; frameworks Apple não são
  copiados nem redistribuídos dentro do pacote.

Não há redistribuição do SQL Server, do driver proprietário, de imagens Docker,
de instalações Homebrew ou de credenciais. O app não é afiliado, aprovado ou
endossado pela Microsoft, Apple ou Docker.

Referências: https://aka.ms/odbc18eula,
https://www.microsoft.com/en-us/sql-server/sql-server-downloads,
https://www.unixodbc.org/, https://openssl-library.org/source/license/,
https://www.docker.com/legal/, https://brew.sh.
