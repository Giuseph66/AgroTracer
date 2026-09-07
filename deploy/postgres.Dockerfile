# syntax=docker/dockerfile:1.7
#
# Postgres+PostGIS com o schema do TraceAgro já dentro da imagem.
#
# As migrações e o script de senha do papel da aplicação são COPIADOS, não
# montados: montar o diretório de migrações e, por cima dele, o script avulso
# faria o runtime criar o ponto de montagem DENTRO do diretório do repositório,
# deixando um arquivo vazio em api/db/migrations/ a cada boot.
#
# Contexto de build: raiz do repositório.
FROM postgis/postgis:16-3.4

# Ordem alfabética em /docker-entrypoint-initdb.d: 001..010 e depois zz_.
COPY api/db/migrations/*.sql /docker-entrypoint-initdb.d/
COPY deploy/db/zz-app-role-password.sh /docker-entrypoint-initdb.d/zz-app-role-password.sh
RUN chmod 0755 /docker-entrypoint-initdb.d/zz-app-role-password.sh
