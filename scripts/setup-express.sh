#!/bin/bash
set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
name=sqlgarden-express
volume=sqlgarden-express-data
image='mcr.microsoft.com/mssql/server:2022-latest'
command -v docker >/dev/null || { echo 'Instale Docker Desktop: https://www.docker.com/products/docker-desktop/'; exit 1; }
docker info >/dev/null 2>&1 || { echo 'Abra Docker Desktop, aguarde ficar pronto e tente novamente.'; exit 1; }
if [[ "${1:-}" == --check ]]; then
  docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
  exit 0
fi
echo 'SQLGarden — servidor SQL Server 2022 Express local (opcional).'
echo 'Se o professor já forneceu um servidor, use Conectar no app e não execute esta instalação.'
echo 'No Apple Silicon, o servidor x64 depende da emulação do Docker. Não há suporte oficial da Microsoft à emulação.'
if docker container inspect "$name" >/dev/null 2>&1; then
  managed="$(docker inspect --format '{{index .Config.Labels "app.sqlgarden.managed"}}' "$name")"
  [[ "$managed" == true ]] || { echo 'Já existe um container com esse nome que não foi criado pelo SQLGarden. Nada será alterado.'; exit 1; }
  echo "O container $name já existe. As credenciais e o volume serão preservados."
  read -r -p 'Deseja apenas iniciá-lo? Digite SIM: ' answer
  [[ "$answer" == SIM ]] && docker start "$name"
  exit 0
fi
if docker volume inspect "$volume" >/dev/null 2>&1; then
  echo "O volume $volume já existe. A instalação foi interrompida para não reutilizar dados sem revisão."
  exit 1
fi
if /usr/bin/nc -z -G 1 127.0.0.1 1433 2>/dev/null; then
  echo 'A porta 1433 já está ocupada. Use seu servidor existente ou escolha outra configuração manualmente.'
  exit 1
fi
echo "Será criado $name, volume $volume e porta SOMENTE local 127.0.0.1:1433."
echo 'Limites: 3 GiB no container, 2 CPUs; memória SQL 2048 MiB. O Docker precisa de memória adicional para Linux.'
echo 'Licença SQL Server: https://go.microsoft.com/fwlink/?linkid=857698'
read -r -p 'Você aceita a licença do SQL Server e deseja criar o Express? Digite SIM: ' answer
[[ "$answer" == SIM ]] || { echo 'Cancelado.'; exit 0; }
read -r -s -p 'Crie uma senha forte para o usuário sa (mínimo 12 caracteres): ' sqlgarden_password
printf '\n'
read -r -s -p 'Repita a senha: ' sqlgarden_confirmation
printf '\n'
[[ "$sqlgarden_password" == "$sqlgarden_confirmation" && ${#sqlgarden_password} -ge 12 ]] || { echo 'As senhas não conferem ou têm menos de 12 caracteres.'; exit 1; }
[[ "$sqlgarden_password" =~ [A-Z] && "$sqlgarden_password" =~ [a-z] && "$sqlgarden_password" =~ [0-9] && "$sqlgarden_password" =~ [^a-zA-Z0-9] ]] || { echo 'Use maiúscula, minúscula, número e símbolo.'; exit 1; }
# No password in command arguments, files, stdout or shell history.
# Docker retains the initial environment in its own protected daemon metadata.
printf 'MSSQL_SA_PASSWORD=%s\n' "$sqlgarden_password" | docker run \
  --platform linux/amd64 --name "$name" --hostname "$name" --label app.sqlgarden.managed=true \
  --restart unless-stopped --memory 3g --cpus 2 \
  -e ACCEPT_EULA=Y -e MSSQL_PID=Express -e MSSQL_MEMORY_LIMIT_MB=2048 --env-file /dev/stdin \
  -p 127.0.0.1:1433:1433 -v "$volume:/var/opt/mssql" -d "$image"
unset sqlgarden_password sqlgarden_confirmation
echo 'Container criado. Aguarde a inicialização (pode levar até alguns minutos).'
echo 'No SQLGarden: servidor 127.0.0.1, porta 1433, usuário sa, banco master e a senha que você criou.'
echo 'Não exclua o volume para resolver falhas. Consulte o guia antes de alterar qualquer dado.'
read -r -p 'Pressione Return para fechar. ' _answer
