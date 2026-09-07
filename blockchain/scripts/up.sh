#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
"$SCRIPT_DIR/bootstrap.sh"
fabric_path

if [[ ! -d "$CHAINCODE_DIR" ]]; then
  echo "Chaincode ausente em $CHAINCODE_DIR" >&2
  exit 1
fi

# `docker container inspect` acerta também em container PARADO. Checar só a
# existência fazia a subida da rede ser pulada quando havia restos de uma
# execução anterior — o deployCC então rodava sem material criptográfico e
# falhava em "cannot init crypto". Aqui só conta peer efetivamente no ar.
peer_running() {
  [[ "$(docker container inspect -f '{{.State.Running}}' \
        peer0.org1.example.com 2>/dev/null)" == 'true' ]]
}
peer_exists() {
  docker container inspect peer0.org1.example.com >/dev/null 2>&1
}

(
  cd "$NETWORK_DIR"
  if ! peer_running; then
    # Restos parados ocupam os nomes de container e de volume que a rede vai
    # recriar — inclusive de outro checkout do fabric-samples na mesma máquina,
    # porque o projeto Compose se chama "compose" nos dois casos. Sem limpar,
    # a rede sobe sobre um ledger alheio.
    if peer_exists; then
      echo "Restos de execução anterior encontrados; limpando antes de subir."
      ./network.sh down
    fi
    ./network.sh up createChannel -ca -c "$FABRIC_CHANNEL" -s couchdb
  fi
  ./network.sh deployCC \
    -c "$FABRIC_CHANNEL" \
    -ccn "$FABRIC_CHAINCODE" \
    -ccp "$CHAINCODE_DIR" \
    -ccl go \
    -ccv "$FABRIC_CHAINCODE_VERSION" \
    -ccep "$FABRIC_ENDORSEMENT_POLICY"
)

echo "Fabric pronto: channel=$FABRIC_CHANNEL chaincode=$FABRIC_CHAINCODE"
