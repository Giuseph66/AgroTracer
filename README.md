# TraceAgro

Plataforma de rastreabilidade bovina orientada a eventos, offline-first no campo,
com prova de integridade em Hyperledger Fabric.

A especificação completa está em [`docs/`](docs/00-INDICE.md) — 17 documentos que
vão da visão executiva ao roadmap. Este README cobre apenas como rodar o que já
está implementado.

## Estado atual

| Parte | O que existe | O que falta |
|-------|--------------|-------------|
| App Flutter | Design system, 6 telas, fila de eventos, hash canônico, sincronização, fluxo de pesagem (UC-02) | Banco local Drift/SQLCipher, assinatura ECDSA, RFID/balança reais, vacinação e embarque |
| API NestJS | Ingestão idempotente com pipeline de validação, persistência Postgres, projeções, âncora assíncrona | OIDC/RBAC, documentos, adaptadores externos, OpenAPI publicado |
| Banco | Schema núcleo + projeções, append-only por grants | Particionamento, PostGIS em uso, retenção |
| Blockchain | Worker de ancoragem com estados e recuperação; gateway simulado | Rede Fabric real, chaincode Go, políticas de endosso |

O gateway Fabric é **simulado** (`FABRIC_MODE != real`): ele exercita todo o
caminho de ancoragem — estados, retry, prova — sem rede. Nada no que está acima
dele muda quando a rede real entrar.

## Rodar

Pré-requisitos: Docker, Node 22+, Flutter 3.44+.

```bash
# 1. Banco (Postgres + PostGIS, com schema e dados de laboratório)
docker compose -f compose.dev.yml up -d

# 2. API em http://localhost:3999
cd api && npm install && npm run build && PORT=3999 npm start

# 3. App
cd app && flutter run                    # Android/desktop
flutter run -d chrome --web-port 8347    # navegador
```

O app aponta para `http://localhost:3999` por padrão. Para outro endereço:
`flutter run --dart-define=TRACEAGRO_API=http://192.168.0.10:3999`.

## Testes

```bash
cd api
npm test           # canonicalização e paridade de vetores
npm run test:e2e   # ingestão contra API + Postgres reais (precisa dos dois no ar)
npm run vectors    # regenera test/vectors.json

cd app
flutter test       # 31 testes: canonicalização, fila de eventos, telas
flutter analyze
```

### Paridade de hash entre Dart e TypeScript

O app calcula `payloadHash` e a API recalcula para comparar. Se as duas
implementações divergirem em um byte, **todo evento vindo do campo é rejeitado**
com `ERR-EVT-HASH`. Por isso os dois lados leem os mesmos vetores de
[`api/test/vectors.json`](api/test/vectors.json), e mudar a canonicalização exige
regenerar o arquivo e ver os dois conjuntos de testes passarem.

## Como o dado anda

```
tela de campo → fila local (hash + sequência do dispositivo)
   → POST /v1/sync/batches
      → assinatura → dedup → ordem → schema → permissão → regras de negócio
         → core.event (append-only) + projeções + âncora PENDING
            → anchor-worker → Fabric → CONFIRMED_ON_BLOCKCHAIN + TxID
```

Três propriedades que o código sustenta e os testes verificam:

- **Idempotência**: reenviar o mesmo `eventId` devolve o veredicto original, nunca cria um segundo registro (R22/R23).
- **Append-only**: o papel de aplicação não tem `UPDATE`/`DELETE` em `core.event`; a única transição permitida (confirmar âncora) passa por função `SECURITY DEFINER` (migração 004).
- **Falha externa não apaga evento interno**: a rede Fabric fora do ar mantém a âncora pendente; o evento aceito continua válido (R30).

## Estrutura

```
docs/          especificação (17 documentos)
api/           NestJS + Fastify + Postgres
  db/migrations/  schema, grants, seed de laboratório
  src/events/     ingestão, canonicalização, repositório
  src/anchor/     worker de ancoragem e gateway Fabric
app/           Flutter
  lib/core/theme/   design tokens e tema
  lib/core/sync/    hash canônico, envelope, fila, cliente de sincronização
  lib/features/     telas por domínio
design-review/ capturas usadas na revisão visual
```

## Decisões visíveis no código

- `core.event` é a fonte de verdade; peso atual, GMD e status são **projeções** recalculadas pelo servidor, nunca campos que o cliente informa (R9/R11/R13).
- GMD só é calculado entre pesagens separadas por pelo menos um dia — duas pesagens no mesmo brete não produzem ganho médio diário.
- A ficha de um animal sem histórico mostra que não há histórico. Não existe dado de exemplo preenchendo tela em lugar nenhum.
- A sequência do dispositivo é retomada a partir do servidor ao abrir o app (`GET /v1/devices/{id}/sync-state`), senão um app reinstalado colidiria com números já usados.
