#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 <eventId>" >&2
  exit 64
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_samples
fabric_path

export TEST_NETWORK_HOME="$NETWORK_DIR"
export OVERRIDE_ORG="${OVERRIDE_ORG:-}"
export VERBOSE=false
source "$NETWORK_DIR/scripts/envVar.sh"
setGlobals 1

peer chaincode query \
  -C "$FABRIC_CHANNEL" \
  -n "$FABRIC_CHAINCODE" \
  -c "{\"Args\":[\"VerifyProof\",\"$1\"]}"
