# syntax=docker/dockerfile:1.7
#
# Caixa de ferramentas da emulação Fabric.
#
# A máquina servidora só precisa de Docker: bash, curl, jq, o CLI do Docker e os
# binários do Fabric ficam todos aqui dentro. Os binários do Fabric (peer,
# osnadmin) são ligados à glibc, por isso a base é Debian e não Alpine.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg bash jq tar git procps \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
      -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# Os scripts do fabric-samples chamam `docker compose` contra o socket montado,
# ou seja, contra o daemon do HOST. Os caminhos que eles passam em bind mounts
# são interpretados pelo daemon, não por este container — por isso o repositório
# precisa ser montado no MESMO caminho absoluto de fora. Ver compose.fabric.yml.
ENTRYPOINT ["/bin/bash", "-lc"]
CMD ["blockchain/scripts/status.sh"]
