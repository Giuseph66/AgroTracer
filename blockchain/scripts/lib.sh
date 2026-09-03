#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BLOCKCHAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly RUNTIME_DIR="$BLOCKCHAIN_DIR/.runtime"
readonly SAMPLES_DIR="$RUNTIME_DIR/fabric-samples"

if [[ -f "$BLOCKCHAIN_DIR/.env" ]]; then
  set -a
  source "$BLOCKCHAIN_DIR/.env"
  set +a
fi

: "${FABRIC_VERSION:=2.5.16}"
: "${FABRIC_CA_VERSION:=1.5.22}"
: "${FABRIC_CHANNEL:=traceagro-main}"
: "${FABRIC_CHAINCODE:=traceagro-cc}"
: "${FABRIC_CHAINCODE_VERSION:=0.1.0}"
: "${FABRIC_ENDORSEMENT_POLICY:=AND('Org1MSP.peer','Org2MSP.peer')}"

readonly CHAINCODE_DIR="$BLOCKCHAIN_DIR/chaincode/$FABRIC_CHAINCODE"
readonly NETWORK_DIR="$SAMPLES_DIR/test-network"

fabric_path() {
  export PATH="$SAMPLES_DIR/bin:$SCRIPT_DIR:$PATH"
  export FABRIC_CFG_PATH="$SAMPLES_DIR/config"
}

require_samples() {
  if [[ ! -x "$SAMPLES_DIR/bin/peer" ]]; then
    echo "Fabric ausente. Execute blockchain/scripts/bootstrap.sh." >&2
    exit 1
  fi
}
