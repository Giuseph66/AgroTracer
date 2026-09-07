#!/bin/bash
set -euo pipefail

# Roda uma única vez, no initdb, depois das migrações 001..010 (ordem alfabética
# em /docker-entrypoint-initdb.d).
#
# A migração 002 cria o papel da aplicação com senha de laboratório escrita em
# texto no SQL versionado. Num servidor exposto essa senha não pode continuar
# valendo — aqui ela vira o valor de PGPASSWORD do deploy/.env.

: "${APP_DB_USER:?APP_DB_USER ausente}"
: "${APP_DB_PASSWORD:?APP_DB_PASSWORD ausente}"

# O SQL vem por stdin: `psql -c` não expande :variavel, e interpolar a senha
# direto na string deixaria aspas e barras invertidas quebrarem o comando.
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v app_user="$APP_DB_USER" -v app_pw="$APP_DB_PASSWORD" <<'SQL'
ALTER ROLE :"app_user" WITH PASSWORD :'app_pw';
SQL

echo "papel $APP_DB_USER com a senha do ambiente"
