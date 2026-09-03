#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_samples

org_dir="$NETWORK_DIR/organizations/peerOrganizations/org1.example.com"
key_files=("$org_dir/users/User1@org1.example.com/msp/keystore/"*_sk)
if [[ ${#key_files[@]} -ne 1 || ! -f "${key_files[0]}" ]]; then
  echo "Chave User1 Org1 não encontrada. Execute blockchain/scripts/up.sh." >&2
  exit 1
fi

printf 'export FABRIC_MODE=%q\n' real
printf 'export FABRIC_ENDPOINT=%q\n' localhost:7051
printf 'export FABRIC_TLS_SERVER_NAME=%q\n' peer0.org1.example.com
printf 'export FABRIC_MSP_ID=%q\n' Org1MSP
printf 'export FABRIC_CHANNEL=%q\n' "$FABRIC_CHANNEL"
printf 'export FABRIC_CHAINCODE=%q\n' "$FABRIC_CHAINCODE"
printf 'export FABRIC_CLIENT_CERT_PATH=%q\n' "$org_dir/users/User1@org1.example.com/msp/signcerts/cert.pem"
printf 'export FABRIC_CLIENT_KEY_PATH=%q\n' "${key_files[0]}"
printf 'export FABRIC_TLS_ROOT_CERT_PATH=%q\n' "$org_dir/peers/peer0.org1.example.com/tls/ca.crt"
printf 'export FABRIC_ENDORSING_ORGS=%q\n' Org1MSP,Org2MSP
