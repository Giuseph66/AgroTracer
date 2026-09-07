#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

have_binaries() { [[ -x "$SAMPLES_DIR/bin/peer" ]]; }
have_network()  { [[ -x "$NETWORK_DIR/network.sh" ]]; }

if have_binaries && have_network; then
  echo "Fabric ${FABRIC_VERSION} já disponível em $SAMPLES_DIR"
  exit 0
fi

mkdir -p "$RUNTIME_DIR"

# fabric-samples vem por git, e precisa vir ANTES dos binários.
#
# O install-fabric.sh só clona se o diretório de destino não existir, e dois
# caminhos criam esse diretório sem o conteúdo do repositório: a extração dos
# binários (bin/, config/) e — o caso que quebrou em produção — o bind mount de
# .../test-network/organizations declarado em deploy/compose.app.yml, que o
# Docker materializa vazio quando a API sobe antes da rede Fabric existir.
# Nos dois casos o clone era pulado em silêncio e o network.sh nunca aparecia.
# Por isso clonamos à parte e mesclamos sobre o que já estiver lá.
if ! have_network; then
  tmp="$(mktemp -d "$RUNTIME_DIR/.samples.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  git clone --depth 1 \
    https://github.com/hyperledger/fabric-samples.git "$tmp/fabric-samples"
  mkdir -p "$SAMPLES_DIR"
  cp -a "$tmp/fabric-samples/." "$SAMPLES_DIR/"
  rm -rf "$tmp"
  trap - EXIT
fi

if ! have_binaries; then
  installer="$RUNTIME_DIR/install-fabric.sh"
  curl -fsSL \
    https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh \
    -o "$installer"
  chmod +x "$installer"

  (
    cd "$RUNTIME_DIR"
    "$installer" \
      --fabric-version "$FABRIC_VERSION" \
      --ca-version "$FABRIC_CA_VERSION" \
      binary docker
  )
fi

have_network || { echo "fabric-samples sem test-network/network.sh" >&2; exit 1; }
echo "Fabric ${FABRIC_VERSION} instalado em $SAMPLES_DIR"
