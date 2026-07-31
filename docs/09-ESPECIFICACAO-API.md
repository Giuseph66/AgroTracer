# Documento 9 — Especificação da API

## 1. Decisão de framework

**DECISÃO** — **NestJS** (sobre plataforma Fastify como HTTP adapter).
Justificativa contra as alternativas:

| Critério | NestJS (+Fastify adapter) | Fastify puro | Express modular |
|----------|---------------------------|--------------|-----------------|
| Separação por domínios (módulos) | Nativa (modules/providers) | Manual (plugins) | Manual |
| Validação forte de payload | class-validator/zod + pipes integrados | Schemas JSON nativos (bom) | Manual |
| OpenAPI | Geração automática por decorators | Plugin, mais manual | Manual |
| Guards/interceptors (RBAC, AuditLog transversal, idempotência) | Nativos | Hooks, menos estruturado | Middleware ad-hoc |
| Filas/workers (BullMQ), agendadores, microserviços | Integração de primeira classe | Bibliotecas avulsas | Avulsas |
| Curva para equipe multi-time + agentes de IA | Convenções fortes = menos interpretação informal | Mais liberdade = mais divergência | Idem |
| Desempenho bruto | ~Fastify (usa o adapter) | Máximo | Menor |

O requisito dominante é **padronização entre equipes** e transversalidade
(auditoria, idempotência, autorização) — Nest entrega isso com o desempenho do
Fastify por baixo.

## 2. Padrões gerais

| Aspecto | Padrão |
|---------|--------|
| Estilo | REST, recursos no plural, kebab-case em rotas, camelCase em JSON |
| Versionamento | Prefixo de URL `/v1`; quebras ⇒ `/v2` com convivência ≥12 meses; schemas de evento versionados à parte (Doc 5 §6) |
| Autenticação | OIDC (Keycloak): Bearer JWT; app usa Authorization Code + PKCE; serviços usam client credentials |
| Autorização | Guards RBAC/ABAC (Doc 7); decisão temporal para eventos (R28) |
| Idempotência | Escritas de evento: `eventId` no corpo é a chave. Demais POSTs: header `Idempotency-Key` (UUID), retenção do resultado por 48h — repetição retorna resposta original com `Idempotent-Replay: true` |
| Paginação | Cursor (`?cursor=&limit=`, limite máx. 500); resposta `{data, nextCursor, total?}` (total só quando barato) |
| Filtros/ordenação | `?filter[campo]=valor`, operadores `gte/lte/in/like`; `?sort=-occurredAt` |
| Erros | RFC 7807 `application/problem+json`: `{type, title, status, detail, code (ERR-XXX-NNN), correlationId, errors[]}` |
| Correlação | `X-Correlation-Id` aceito ou gerado; propagado a logs, filas, adaptadores |
| Auditoria | Interceptor grava AuditLog para ações administrativas (R35) |
| Rate limit | Por token e por IP; padrão 600 req/min autenticado; QR público 30 req/min/IP; 429 + `Retry-After` |
| Upload | `POST /v1/documents` multipart até 50MB; acima disso, URL pré-assinada (`/v1/documents/upload-intent`) |
| Download | Sempre URL pré-assinada com expiração ≤15min; nunca proxy de bytes pelo core |
| Webhooks | Assinados (HMAC-SHA256, header `X-Webhook-Signature`), retry com backoff, tipos: `event.accepted`, `event.anchored`, `conflict.created`, `shipment.received`, `integration.failed` |
| Assíncrono | Operações longas retornam `202 {jobId}`; polling `GET /v1/jobs/{id}` ou webhook |

## 3. Códigos HTTP padronizados

| Código | Uso |
|--------|-----|
| 200 | Sucesso; inclui replays idempotentes |
| 201 | Recurso criado |
| 202 | Aceito para processamento assíncrono |
| 400 | Payload inválido (schema) |
| 401 | Não autenticado / token expirado |
| 403 | Sem permissão (inclui R28 temporal, dispositivo revogado) |
| 404 | Recurso inexistente no escopo visível |
| 409 | Conflito de negócio (duplicidade, estado incompatível, R14) |
| 422 | Regra de negócio violada com payload válido (R18 etc.) |
| 429 | Rate limit |
| 5xx | Erro do servidor (nunca vaza detalhe interno) |

## 4. Catálogo de endpoints

Colunas: método/rota · descrição · permissão (Doc 7) · idempotência · evento gerado ·
impacto blockchain (âncora padrão P, reforçada R, nenhum —).

### 4.1 Autenticação e usuários

| Endpoint | Descrição | Permissão | Idem. | Evento | BC |
|----------|-----------|-----------|-------|--------|----|
| `POST /v1/auth/token` | Troca code/refresh por tokens (proxy OIDC) | pública | — | AuditLog | — |
| `POST /v1/auth/logout` | Revoga refresh | autenticado | — | AuditLog | — |
| `GET /v1/me` | Perfil + papéis + vínculos vigentes | autenticado | — | — | — |
| `GET /v1/users` · `POST /v1/users` · `PATCH /v1/users/{id}` | Gestão de usuários da org | ADMO/ADMP | Key | AuditLog | — |
| `POST /v1/users/{id}/roles` · `DELETE .../roles/{roleId}` | Vínculo de papel (com vigência) | ADMO/ADMP | Key | AuditLog | — |
| `POST /v1/users/{id}/revoke` | Revogação imediata | ADMO/ADMP | Key | AuditLog | — |

### 4.2 Organizações e território

| Endpoint | Descrição | Permissão | Idem. | Evento | BC |
|----------|-----------|-----------|-------|--------|----|
| `GET/POST /v1/organizations` · `PATCH /{id}` · `POST /{id}/suspend` | Gestão de orgs | ADMP (cria/suspende), ADMO (edita a própria) | Key | AuditLog | — |
| `GET/POST /v1/properties` · `PATCH /{id}` | Propriedades (geometria versionada) | PROD/ADMO | Key | AuditLog | — |
| `GET/POST /v1/properties/{id}/paddocks` · `/corrals` | Áreas | PROD/TECN | Key | AuditLog | — |
| `GET/POST /v1/properties/{id}/herd-lots` · `POST /herd-lots/{id}/close` | Lotes de manejo | PROD/TECN/OPER | Key | AuditLog | — |

### 4.3 Animais e identificadores

| Endpoint | Descrição | Permissão | Idem. | Evento | BC |
|----------|-----------|-----------|-------|--------|----|
| `GET /v1/animals` | Busca (RFID, visual, oficial, lote, status) | escopo Doc 7 | — | — | — |
| `GET /v1/animals/{id}` | Ficha consolidada (projeções) | escopo | — | — | — |
| `GET /v1/animals/{id}/timeline` | Linha do tempo de eventos (paginada) | escopo | — | — | — |
| `GET /v1/animals/{id}/identifiers` | Histórico de identificadores | escopo | — | — | — |
| `GET /v1/identifiers/resolve?rfid=` | Resolve RFID→animal (usado pelo app) | escopo | — | — | — |
| Criação/alteração de animal | **Não existe endpoint CRUD** — exclusivamente via eventos (§4.4) | — | — | — | — |

### 4.4 Eventos (núcleo)

| Endpoint | Descrição | Permissão | Idem. | Evento | BC |
|----------|-----------|-----------|-------|--------|----|
| `POST /v1/events` | Ingestão de 1 evento online (envelope Doc 5) | por eventType (Doc 7) | eventId | o próprio | P/R por tipo |
| `POST /v1/sync/batches` | Ingestão em lote ordenado (app offline) | idem, por evento | eventId+deviceSequence | os do lote | P/R |
| `GET /v1/sync/batches/{id}` | Resultado do lote | dono/ADMO | — | — | — |
| `GET /v1/events/{id}` | Envelope + payload + estado + âncora | escopo | — | — | — |
| `GET /v1/events?filter[...]` | Consulta (tipo, sujeito, período, status) | escopo | — | — | — |
| `POST /v1/events/{id}/correct` | Atalho para evento CORRECTED | Doc 7 col. X | eventId novo | CORRECTED | P |
| `GET /v1/event-schemas/{type}/{version}` | JSON Schema do payload | pública autenticada | — | — | — |

Validações de `POST /v1/sync/batches` (pipeline, na ordem): autenticação →
dispositivo ativo → assinatura por evento (R26) → dedup (R22) → ordem de sequence
(R27) → schema do payload → permissão temporal (R28) → regras de negócio (Doc 6) →
persistência transacional por evento → resposta com veredicto individual
`{eventId, status: ACCEPTED|REJECTED|CONFLICT, code?, conflictId?}`.

### 4.5 Domínios específicos (fachadas de consulta; escrita é sempre evento)

| Endpoint | Descrição | Permissão |
|----------|-----------|-----------|
| `GET /v1/animals/{id}/weights` · `GET /v1/herd-lots/{id}/weights` | Pesagens e GMD | escopo |
| `GET /v1/animals/{id}/health` · `/withdrawals` · `/quarantines` | Sanidade e bloqueios ativos | escopo |
| `GET /v1/animals/{id}/reproduction` · `/offspring` | Reprodução e genealogia | escopo |
| `GET/POST /v1/shipments` (cria DRAFT) · `GET /{id}` · `POST /{id}/cancel` | Embarques (dispatch/receive via eventos) | Doc 7 |
| `GET /v1/shipments/{id}/discrepancies` | Divergências do recebimento | envolvidos |
| `GET/POST /v1/gta-records` | Registro de GTA + metadados | Doc 7 |
| `GET /v1/animals/{id}/ownership` · `/custody` | Cadeias de propriedade/custódia | escopo |

### 4.6 Documentos e certificados

| Endpoint | Descrição | Permissão | Idem. | Evento | BC |
|----------|-----------|-----------|-------|--------|----|
| `POST /v1/documents` · `POST /v1/documents/upload-intent` | Upload (hash conferido) | Dc (Doc 7) | Key | — | — |
| `POST /v1/documents/{id}/versions` | Nova versão (preserva anterior) | Dc | Key | — | — |
| `POST /v1/documents/{id}/attach` | Vincula a sujeito | Dc | eventId | DOCUMENT_ATTACHED | P |
| `GET /v1/documents/{id}` · `GET .../download` | Metadados / URL assinada | escopo | — | AuditLog (P3) | — |
| `GET /v1/documents/{id}/verify` | Recalcula hash × âncora | escopo | — | — | leitura |
| `POST /v1/certification-requests` | Solicita certificação | PROD | Key | — | — |
| `POST /v1/certificates` (via evento CERTIFIED) · `POST /{id}/revoke` | Emissão/revogação | CERT | eventId | CERTIFIED/REJECTED | **R** |
| `GET /v1/public/certificates/{publicCode}` | Visão pública | pública | — | — | leitura |

### 4.7 Dispositivos e sincronização

| Endpoint | Descrição | Permissão | Idem. |
|----------|-----------|-----------|-------|
| `POST /v1/devices/enroll` | Enrolamento (envia chave pública, recebe deviceId + último sequence) | usuário autenticado + aprovação ADMO parametrizável | Key |
| `GET /v1/devices` · `POST /v1/devices/{id}/revoke` · `/block` | Gestão | ADMO | Key |
| `POST /v1/devices/{id}/readers` · `/scales` | Pareamento de periféricos | OPER/ADMO | Key |
| `GET /v1/sync/pull?collections=&cursor=` | Pull incremental por coleção | dispositivo ativo | — |
| `GET /v1/sync/conflicts` · `POST /v1/sync/conflicts/{id}/resolve` | Central de conflitos | Doc 7 | Key |

### 4.8 Blockchain, auditoria, relatórios, integrações

| Endpoint | Descrição | Permissão |
|----------|-----------|-----------|
| `GET /v1/anchors?subjectId=` · `GET /v1/anchors/{id}` | Estado de âncoras | escopo |
| `GET /v1/anchors/{id}/proof` | Prova: TxID, bloco, orgs endossantes, hash | escopo; versão resumida pública |
| `POST /v1/anchors/{id}/retry` | Reancoragem após FAILED | ADMP |
| `GET /v1/audit-logs?filter[...]` | Consulta de trilha | AUDI/ADMO(org)/ADMP |
| `POST /v1/reports` (202) · `GET /v1/reports/{id}` | Relatórios assíncronos | Doc 7 |
| `POST /v1/exports/dossier` | Dossiê verificável (animal/lote/propriedade) | Ex (Doc 7) |
| `GET /v1/integrations/sisbov/status` · `GET .../divergences` · `POST .../divergences/{id}/resolve` | Reconciliação SISBOV (Doc 12) | ADMO/CERT |
| `GET /v1/public/trace/{publicCode}` | Trilha pública do QR (CutLot/Certificate) | pública, rate-limited |
| `GET /v1/jobs/{id}` | Estado de job assíncrono | dono |

## 5. Exemplo de contrato — `POST /v1/sync/batches`

Request (resumido):

```json
{
  "batchId": "UUIDv7",
  "deviceId": "UUID",
  "clockSkewMs": -4200,
  "events": [ { "...envelope Doc 5 §1, com payload embutido..." } ]
}
```

Response `200`:

```json
{
  "batchId": "...",
  "results": [
    {"eventId": "...", "status": "ACCEPTED", "duplicate": false},
    {"eventId": "...", "status": "CONFLICT", "code": "IDENTIFIER_TAKEN", "conflictId": "..."},
    {"eventId": "...", "status": "REJECTED", "code": "ERR-SAN-001",
     "detail": "professional credential required at occurredAt"}
  ]
}
```

Lote é processado por evento (falha individual não derruba o lote); resposta sempre
200 quando o lote foi processado, com veredictos individuais.

## 6. OpenAPI

- Especificação OpenAPI 3.1 gerada do código (decorators) e publicada em
  `/v1/openapi.json` + UI interna; contrato versionado no repositório e validado em
  CI (breaking-change check).
- Exemplos de request/response obrigatórios para todo endpoint de escrita.
