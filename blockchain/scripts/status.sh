#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_samples

docker ps --filter 'name=peer0.org' --filter 'name=orderer.example.com' \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
