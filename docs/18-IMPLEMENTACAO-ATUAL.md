# Documento 18 — Estado Atual da Implementação

Data de referência: 2026-07-31. Este documento descreve **o que existe e funciona
hoje**, verificado por testes automatizados e teste visual ponta a ponta. É o
ponto de partida para qualquer agente ou equipe que vá implementar o backlog do
Documento 19. Leia junto com `AGENTS.md` (raiz do repositório), que define o
design system e as convenções obrigatórias.

## 1. Visão geral do que funciona

Fluxo completo verificado em execução real:

```
Tela de pesagem (Flutter web/Android)
  → evento criado na fila local (hash SHA-256 canônico + deviceSequence)
    → POST /v1/sync/batches (NestJS)
      → pipeline: dedup → dispositivo → assinatura → hash → sujeito → regras
        → core.event (Postgres, append-only) + projeções + âncora PENDING
          → anchor-worker (3s) → gateway Fabric (simulado) → CONFIRMED
            → app busca prova e exibe selo "Comprovado" com TxID
```

Resultados de teste na data de referência:

| Suíte | Resultado |
|-------|-----------|
| `api npm test` (canonicalização) | 5/5 |
| `api npm run test:e2e` (ingestão contra Postgres real) | 11/11 |
| `app flutter test` (canonical, outbox, widgets) | 31/31 |
| `flutter analyze` | limpo |
| Playwright ponta a ponta (pesagem → âncora → prova na tela) | verificado, capturas em `design-review/` |

## 2. Componentes

### 2.1 Banco (Postgres 16 + PostGIS)

- Sobe com `docker compose -f compose.dev.yml up -d` (porta **5433**).
- Migrações em `api/db/migrations/` (aplicadas no init do container; novas
  migrações devem ser aplicadas manualmente com `psql -f` — não há runner ainda):
  - `001_core.sql` — schemas `core` e `read_model`; tabelas Organization,
    AppUser, Property (com `geom` PostGIS SRID 4674), Device, Animal,
    AnimalIdentifier (com UNIQUE parciais das regras R3/R4), Event,
    EventPayload, AuditLog, SyncJob, SyncConflict, BlockchainAnchor; projeções
    `animal_state`, `weight_record`, `health_record`.
  - `002_grants_and_seed.sql` — papel `traceagro_app` **sem UPDATE/DELETE** nas
    tabelas de histórico (defesa da R7); seed de laboratório (ver §4).
  - `003_ingestion_verdict.sql` — tabela `core.ingestion_verdict`: veredicto de
    todo eventId processado, inclusive rejeitados/conflitos, para idempotência
    R23 sobrevivendo a restart.
  - `004_event_anchor_fn.sql` — função `SECURITY DEFINER`
    `core.confirm_event_anchor(uuid, text)`: única mutação permitida em
    `core.event` (transição PENDING_BLOCKCHAIN → CONFIRMED_ON_BLOCKCHAIN).
  - `005_gmd_range.sql` — alarga `gmd_kg_day` para numeric(7,3) (defesa em
    profundidade do bug de GMD, ver §5).

### 2.2 API (NestJS 11 + Fastify, porta 3999)

Estrutura em `api/src/`:

| Caminho | Responsabilidade |
|---------|------------------|
| `main.ts` | Bootstrap, ValidationPipe global (whitelist + forbidNonWhitelisted), versionamento URI `/v1`, CORS |
| `database/database.module.ts` | Pool `pg` global (env `PGHOST/PGPORT/...`; padrão localhost:5433, papel `traceagro_app`) |
| `events/event.dto.ts` | Envelope canônico (Doc 5 §1) com class-validator; `eventId` exige **UUIDv7** |
| `events/canonical.ts` | Canonicalização JCS simplificada + SHA-256 (`payloadHash`) |
| `events/events.service.ts` | Pipeline de ingestão (Doc 9 §4.4) — ordem das etapas documentada no código |
| `events/events.repository.ts` | SQL: dedup, estado do animal, R3, inserção transacional, projeções (peso/GMD/sanidade/identificador), consultas timeline/animais, mapa eventType→função de chaincode |
| `events/events.controller.ts` | `POST /v1/events`, `POST /v1/sync/batches`, `GET /v1/sync/conflicts` |
| `animals/animals.controller.ts` | `GET /v1/animals?propertyId=`, `GET /v1/animals/:id/timeline` — **não existe CRUD de animal**; escrita é evento |
| `anchor/fabric.gateway.ts` | Porta de saída Fabric. **Simulado** (`FABRIC_MODE != real`): latência + TxID derivado do hash + endorsingOrgs fixos. Trocar por `@hyperledger/fabric-gateway` na Fase 4 sem tocar no resto |
| `anchor/anchor.worker.ts` | `@Interval(3000)`: PENDING → SUBMITTED → CONFIRMED; recupera SUBMITTED travado >30s; máx. 24 tentativas; `FOR UPDATE SKIP LOCKED` (multi-réplica seguro) |
| `anchor/anchor.controller.ts` | `GET /v1/anchors` (resumo por status), `GET /v1/anchors/:subjectId/proof` |
| `devices/devices.controller.ts` | `GET /v1/devices/:id/sync-state` → `lastSequence` (retomada de numeração) |

Contratos de resposta da ingestão: sempre veredicto individual por evento
`{eventId, status: ACCEPTED|REJECTED|CONFLICT, code?, detail?, conflictId?, duplicate?}`.
Reenvio de eventId conhecido ⇒ veredicto original + `duplicate: true`.

Regras de negócio ativas no pipeline: R3 (IDENTIFIER_TAKEN), R14
(SUBJECT_CLOSED), R22/R23 (dedup/idempotência), R27 (ordem por deviceSequence),
faixa de peso 15–1500 kg (ERR-PES-001), hash obrigatório (ERR-EVT-HASH),
assinatura presente (ERR-EVT-SIGNATURE — ver limitação §6.2), animal inexistente
(SUBJECT_UNKNOWN vira conflito, não erro).

Projeções calculadas **pelo servidor** (nunca aceitas do cliente): peso atual,
GMD (somente entre pesagens com ≥1 dia de intervalo), carência
(`withdrawal_until` = maior vigente), vínculo de identificadores.

### 2.3 App (Flutter 3.44, Android + web)

Estrutura em `app/lib/`:

| Caminho | Responsabilidade |
|---------|------------------|
| `core/theme/tokens.dart` | Tokens de design (cores, espaçamento, raios) — fonte única, ver AGENTS.md |
| `core/theme/theme.dart` | ThemeData Material 3 a partir dos tokens (Archivo/Archivo Black/Spline Sans Mono via google_fonts) |
| `core/widgets/ear_tag.dart` | Componente-assinatura: brinco desenhado em CustomPainter (3 tamanhos) |
| `core/widgets/common.dart` | SyncBadge (estados Doc 8 §5), SectionLabel, TaCard, ConnectivityPill, formatadores de data |
| `core/sync/canonical.dart` | Canonicalização + SHA-256 em Dart — **gêmea byte a byte** de `api/src/events/canonical.ts` |
| `core/sync/event_envelope.dart` | Envelope Doc 5 §1; `DevIdentity` (fixture do laboratório, ver §4); assinatura ainda stub |
| `core/sync/outbox.dart` | Fila de eventos: sequência monotônica, estados, `adoptServerSequence()` (nunca retrocede), stream de mudanças. **Em memória — persistência Drift é backlog B11** |
| `core/sync/sync_service.dart` | Push em lote (500), backoff 5s→15min, ping de conectividade, adoção de sequência no boot, repescagem de provas de âncora a cada 8s, clock skew via header Date |
| `core/services.dart` | `AppServices` + InheritedWidget `Services`; `apiBaseUrl` via `--dart-define=TRACEAGRO_API` (padrão localhost:3999) |
| `data/api_client.dart` | Leitura: animais e timeline; conversão wire→domínio; formatação de RFID/SISBOV para exibição |
| `data/herd_repository.dart` | Rebanho em memória alimentado pela API; `TimelineResult` distingue vazio de inacessível; **zero dados de exemplo** |
| `domain/models.dart` | Animal, TraceEvent, SyncState (Doc 8), LifecycleStatus, EventKind com `wireName` |
| `features/home/` | Início: header pasture, resumo de fila, grade de ações, "Hoje na fazenda" |
| `features/read/` | Leitura RFID **simulada** (3 estados: aguardando/identificado/desconhecido) |
| `features/weighing/` | UC-02 pesagem no brete: lê→estabiliza→confirma→libera; alerta de variação >30%; entrada manual com flag; fita da sessão com estado de sync por animal |
| `features/animal/` | Ficha: brinco grande, derivados, banner de carência, linha do tempo com SyncBadge por evento |
| `features/animals/` | Lista com busca por visual/RFID/SISBOV/lote; estados vazios distintos (carregando/busca/sem rede/sem cadastro) |
| `features/sync/` | Central: card de conexão, conflitos ("precisam de você"), fila de envio com prova |
| `features/settings/` | Servidor, estado, última sync, clock skew, identidade do aparelho, sync manual |

Testes: `test/canonical_test.dart` (lê `api/test/vectors.json` — paridade),
`test/outbox_test.dart` (sequência, estados, R24, R27), `test/widget_test.dart`.

### 2.4 Paridade de hash (crítico)

`api/test/vectors.json` é gerado por `api/test/generate-vectors.js` a partir da
implementação TS. Os testes Dart leem o mesmo arquivo. **Qualquer mudança na
canonicalização exige regenerar os vetores e ver as duas suítes passarem** —
divergência de um byte rejeita todo evento do campo com ERR-EVT-HASH.

## 3. Como rodar

Ver `README.md` (raiz). Resumo: compose (banco 5433) → `api: npm run build &&
PORT=3999 npm start` → `app: flutter run`. Web de teste:
`flutter build web --release` + servidor estático em 8347.

## 4. Identidade de laboratório (fixture — substituir no login real)

Semeada na migração 002 e fixa em `app/lib/core/sync/event_envelope.dart`
(`DevIdentity`):

| Entidade | UUID |
|----------|------|
| Org produtora (Fazenda Santa Rita Agropecuária) | `22222222-2222-4222-8222-222222222222` |
| Org fundação | `22222222-2222-4222-8222-000000000001` |
| Usuário João P. | `33333333-3333-4333-8333-333333333333` |
| Usuária Dra. Carla M. (CRMV-GO 8812) | `33333333-3333-4333-8333-000000000002` |
| Propriedade Fazenda Santa Rita | `66666666-6666-4666-8666-666666666666` |
| Dispositivo Field Terminal A1 | `44444444-4444-4444-8444-444444444444` |
| Animais 4127/4088/3950/4201 | `11111111-1111-4111-8111-0000000041XX` |

O item B1 do backlog (login) substitui `DevIdentity` por sessão real — é a
primeira dependência de quase tudo.

## 5. Bugs encontrados e corrigidos (histórico de decisão)

| # | Bug | Causa | Correção | Regressão coberta por |
|---|-----|-------|----------|----------------------|
| 1 | Âncora órfã em SUBMITTED | Worker morria entre submeter e confirmar; busca só pegava PENDING | Repescagem de SUBMITTED com `submitted_at` >30s (idempotente na rede: mesma chave de estado) | e2e "evento aceito é ancorado" |
| 2 | GMD estourava numeric(5,3) | Pesagens no mesmo dia ⇒ denominador fração de dia ⇒ valor absurdo | Regra de domínio: GMD só com ≥1 dia de intervalo (senão mantém anterior); coluna alargada como defesa | e2e "projeção de peso" |
| 3 | ORDER_VIOLATION em série após reabrir o app | Fila em memória zerava a sequência; servidor rejeitava colisões (comportamento correto do servidor) | `GET /v1/devices/:id/sync-state` + `Outbox.adoptServerSequence()` no boot (nunca retrocede) | outbox_test "adota a sequência do servidor" |
| 4 | Histórico fabricado na ficha | Fallback para dados de exemplo quando a API falhava | Mock deletado; `TimelineResult.unreachable`; estados vazios honestos em todas as telas | widget tests + revisão visual |

Nenhum bug conhecido em aberto na data de referência.

## 6. Limitações conhecidas (não são bugs — são backlog)

1. **Fila em memória** — eventos pendentes se perdem ao fechar o app. Backlog B11 (Drift+SQLCipher). É a maior lacuna para o offline real.
2. **Assinatura stub** — `signature: 'sig-stub-dev'`; servidor valida apenas presença. Backlog B12 (ECDSA P-256 no Keystore + verificação R26).
3. **Fabric simulado** — gateway gera TxID localmente. Rede real é Fase 4 (Doc 10). O contrato acima do gateway não muda.
4. **Sem autenticação** — API aberta; identidade vem do envelope. Backlog B1.
5. **Leitura RFID simulada** — sorteia animal do rebanho. Backlog B10 (hardware real, prioridade do usuário após o backlog atual).
6. **Sem runner de migração** — migrações novas aplicadas via psql manual. Corrigir junto de B1.
7. **Eventos suportados na prática** — WEIGHING de ponta a ponta; LINK_IDENTIFIER no pipeline; demais tipos validados no envelope mas sem tela nem projeção específica.
8. **Pull incremental não implementado** — app baixa lista completa de animais a cada refresh; cursores do Doc 8 §11 pendentes.
