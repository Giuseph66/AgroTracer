#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [[ -x "$SAMPLES_DIR/bin/peer" ]]; then
  echo "Fabric ${FABRIC_VERSION} já disponível em $SAMPLES_DIR"
  exit 0
fi

mkdir -p "$RUNTIME_DIR"
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
    binary docker samples
)

echo "Fabric ${FABRIC_VERSION} instalado em $SAMPLES_DIR"
