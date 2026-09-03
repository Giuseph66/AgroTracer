# Fabric local — TraceAgro

Rede local de desenvolvimento para validar API → Hyperledger Fabric. Não é
produção nem substitui a rede/credenciais dos parceiros.

## Componentes

- Fabric 2.5.16 LTS e Fabric CA 1.5.22, baixados sob `.runtime/`;
- test-network oficial: `Org1MSP`, `Org2MSP`, dois peers, um orderer e CouchDB;
- canal `traceagro-main`;
- chaincode Go `traceagro-cc`, limitado a registros-âncora do Doc 11.

O código/on-chain guarda apenas `eventId`, `payloadHash`, função, MSP, TxID e
timestamp. Nunca payload completo ou dados pessoais.

## Subir

```bash
cp blockchain/.env.example blockchain/.env
blockchain/scripts/up.sh
blockchain/scripts/status.sh
```

O bootstrap baixa binários, imagens e `fabric-samples` oficial em
`blockchain/.runtime/`, ignorado pelo Git. Docker precisa estar ativo.

## Conectar API

Após a rede subir, carregue os certificados gerados para a identidade
`User1@org1`. A chave tem nome aleatório; não copie caminho manualmente:

```bash
eval "$(blockchain/scripts/api-env.sh)"
(cd api && npm run dev)
```

Isto não modifica `api/.env` nem imprime conteúdo de chaves.

## Painel central

Com a API em execução, abra [http://localhost:4009/blockchain/](http://localhost:4009/blockchain/).
O painel reúne estados das âncoras, últimas transações e a prova de um evento.
Ele autentica pela própria API e mantém o token somente na memória do navegador.
Em modo de desenvolvimento, use a credencial de laboratório do Doc 18 §4.
O contador **Fabric atual** considera somente âncoras cujo endosso coincide com
`FABRIC_ENDORSING_ORGS`; registros simulados ou de outra rede são rotulados no
histórico e não se passam por prova da rede local.

## Verificar prova sem API

```bash
blockchain/scripts/invoke-anchor.sh <eventId> <payloadHash>
blockchain/scripts/query-proof.sh <eventId>
```

## Encerrar

```bash
blockchain/scripts/down.sh
```

`down.sh` remove containers, artefatos e volumes do test-network local.
