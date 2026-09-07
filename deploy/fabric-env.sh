#!/usr/bin/env bash
set -euo pipefail

# Gera o env_file que o container da API consome para falar com a rede Fabric
# local. É o irmão de blockchain/scripts/api-env.sh, com duas diferenças:
#
#  - imprime KEY=VALUE (formato env_file do Compose), não `export ...`;
#  - os caminhos são os que a identidade tem DENTRO do container da API
#    (/fabric/organizations/...), não os do host.
#
# Uso: docker compose -f compose.fabric.yml run --rm fabric-env

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/blockchain/scripts/lib.sh"
require_samples

host_org_dir="$NETWORK_DIR/organizations/peerOrganizations/org1.example.com"
user_dir="users/User1@org1.example.com"

key_files=("$host_org_dir/$user_dir/msp/keystore/"*_sk)
if [[ ${#key_files[@]} -ne 1 || ! -f "${key_files[0]}" ]]; then
  echo "Chave User1 Org1 não encontrada. Rode antes: docker compose -f compose.fabric.yml run --rm fabric-up" >&2
  exit 1
fi
key_name="$(basename "${key_files[0]}")"

# compose.app.yml monta .../test-network/organizations em /fabric/organizations.
in_api="/fabric/organizations/peerOrganizations/org1.example.com"

cat <<ENV
# Gerado por deploy/fabric-env.sh — não edite à mão, não versione.
# Refeito a cada fabric-up que recrie a rede: o nome do arquivo de chave muda.
FABRIC_MODE=real
# A API está em outro projeto Compose; alcança o peer pela porta publicada no
# host. O certificado do peer continua sendo validado contra o nome abaixo.
FABRIC_ENDPOINT=host.docker.internal:7051
FABRIC_TLS_SERVER_NAME=peer0.org1.example.com
FABRIC_MSP_ID=Org1MSP
FABRIC_CHANNEL=$FABRIC_CHANNEL
FABRIC_CHAINCODE=$FABRIC_CHAINCODE
FABRIC_CLIENT_CERT_PATH=$in_api/$user_dir/msp/signcerts/cert.pem
FABRIC_CLIENT_KEY_PATH=$in_api/$user_dir/msp/keystore/$key_name
FABRIC_TLS_ROOT_CERT_PATH=$in_api/peers/peer0.org1.example.com/tls/ca.crt
FABRIC_ENDORSING_ORGS=Org1MSP,Org2MSP
ENV
