#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Uso: $0 <eventId> <payloadHash>" >&2
  exit 64
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_samples
fabric_path

export TEST_NETWORK_HOME="$NETWORK_DIR"
export OVERRIDE_ORG="${OVERRIDE_ORG:-}"
export VERBOSE=false
source "$NETWORK_DIR/scripts/envVar.sh"
parsePeerConnectionParameters 1 2
setGlobals 1

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "$ORDERER_CA" \
  -C "$FABRIC_CHANNEL" \
  -n "$FABRIC_CHAINCODE" \
  "${PEER_CONN_PARMS[@]}" \
  --waitForEvent \
  --waitForEventTimeout 30s \
  -c "{\"Args\":[\"RecordEvent\",\"$1\",\"$2\"]}"
