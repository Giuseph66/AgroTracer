#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
"$SCRIPT_DIR/bootstrap.sh"
fabric_path

if [[ ! -d "$CHAINCODE_DIR" ]]; then
  echo "Chaincode ausente em $CHAINCODE_DIR" >&2
  exit 1
fi

(
  cd "$NETWORK_DIR"
  if ! docker container inspect peer0.org1.example.com >/dev/null 2>&1; then
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
