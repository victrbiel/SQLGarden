#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Este instalador é para macOS.' >&2; exit 1; }
# Install dependencies for the native app, even if Terminal was launched via Rosetta.
if [[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then
  prefix=/opt/homebrew
else
  prefix=/usr/local
fi
brew_bin="$prefix/bin/brew"
if [[ ! -x "$brew_bin" ]]; then
  echo "Homebrew nativo não encontrado em $prefix."
  echo 'Instale-o pelo site oficial https://brew.sh e execute este arquivo novamente.'
  echo 'O Homebrew pode solicitar as ferramentas de linha de comando da Apple (não é preciso instalar o Xcode completo).'
  [[ "${1:-}" == --check ]] || read -r -p 'Pressione Return para fechar. ' _answer
  exit 1
fi
export PATH="$prefix/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
if [[ "${1:-}" == --check ]]; then
  "$brew_bin" list --versions unixodbc openssl@3 msodbcsql18
  "$prefix/opt/unixodbc/bin/odbcinst" -q -d
  exit
fi
echo 'SQLGarden — dependências oficiais do cliente SQL Server.'
echo 'Serão instalados unixODBC, OpenSSL 3 e Microsoft ODBC Driver 18 via Homebrew.'
echo 'Este arquivo não instala o servidor, não cria containers e não altera bancos.'
echo 'Licença Microsoft: https://aka.ms/odbc18eula'
read -r -p 'Você aceita a licença do driver e deseja continuar? Digite SIM: ' answer
[[ "$answer" == SIM ]] || { echo 'Instalação cancelada.'; exit 0; }
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_ACCEPT_EULA=Y
"$brew_bin" install unixodbc openssl@3
"$brew_bin" tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
"$brew_bin" install microsoft/mssql-release/msodbcsql18
"$prefix/opt/unixodbc/bin/odbcinst" -q -d
echo 'Pronto. Abra o SQLGarden e use Conectar. Sua senha será informada no app.'
read -r -p 'Pressione Return para fechar. ' _answer
