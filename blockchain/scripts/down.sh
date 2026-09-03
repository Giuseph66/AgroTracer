#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_samples
fabric_path

(
  cd "$NETWORK_DIR"
  ./network.sh down
)
