# Documento 5 — Catálogo de Eventos

## 1. Envelope canônico

Todo evento, de qualquer tipo, usa o envelope abaixo. O payload específico do tipo
vai em documento separado (`EventPayload.canonicalJson`) referenciado por
`payloadRef`; `payloadHash` é o SHA-256 da serialização canônica (regras no
Documento 11 §4).

```json
{
  "eventId": "018f6b2a-7c3d-7e21-a5b0-9f31c2d4e8a1",
  "schemaVersion": "1.0",
  "eventType": "VACCINATION",
  "subjectType": "ANIMAL",
  "animalId": "018f6b2a-....",
  "officialAnimalId": "076000123456789",
  "rfidCode": "982000123456789",
  "subjectId": "018f6b2a-....",
  "occurredAt": "2026-07-30T14:22:05-03:00",
  "recordedAt": "2026-07-30T14:22:31-03:00",
  "organizationId": "UUID",
  "actorId": "UUID",
  "deviceId": "UUID",
  "deviceSequence": 4812,
  "appVersion": "1.4.2",
  "propertyId": "UUID",
  "payloadRef": "UUID",
  "payloadHash": "sha256-hex-64",
  "signature": "base64(assinatura ECDSA P-256 sobre payloadHash + campos do envelope)",
  "sourceSystem": "MOBILE_OFFLINE",
  "correctionOf": null,
  "blockchainTxId": null
}
```

Observações fixas:

- `officialAnimalId` e `rfidCode` no envelope são **cópias de conveniência para
  conferência** no momento do evento; a fonte de verdade do vínculo é
  `AnimalIdentifier`. Divergência entre a cópia e o vínculo vigente gera rejeição
  (`ORDER_VIOLATION`/`IDENTIFIER_TAKEN`).
- `blockchainTxId` é sempre nulo na origem; preenchido pelo anchor-worker.
- Assinatura cobre: `eventId | eventType | subjectId | occurredAt | deviceSequence | payloadHash`.

## 2. Atributos comuns de aceitação (valem para todos os tipos)

1. `eventId` inédito (R22); repetido ⇒ resposta idempotente com resultado original.
2. `(deviceId, deviceSequence)` inédito (R22).
3. Dispositivo ativo, assinatura válida (R25, R26).
4. Ator com permissão para o tipo, avaliada em `occurredAt` (R28, Doc 7).
5. Sujeito existente e em estado compatível (R13, R14).
6. Payload válido contra JSON Schema do `schemaVersion`.
7. Todos os eventos aceitos são ancorados (hash) — coluna "Endosso" abaixo indica
   apenas quando a âncora exige **política de endosso reforçada** (múltiplas orgs)
   em vez da política padrão.

## 3. Tabela mestra

Legenda — Ator: OP operador, TE técnico, VE veterinário, PR produtor, CE certificador,
TR transportador, FR frigorífico, AD admin org, SY sistema. Endosso: **P** padrão
(OrgFundacao + org autora), **R** reforçado (política específica no Doc 10 §8).
Corr.: pode ser alvo de `correctionOf`.

| eventType | Descrição | Ator | Pré-condições principais | Muda estado derivado | Endosso | Corr. |
|-----------|-----------|------|--------------------------|----------------------|:-:|:-:|
| REGISTER_ANIMAL | Cria identidade digital do animal | OP/TE/PR | Propriedade ativa; identificadores livres | Cria Animal `ACTIVE` | P | ✔ |
| LINK_IDENTIFIER | Associa identificador físico/oficial | OP/TE | R3, R4; animal ativo | AnimalIdentifier ativo | P | ✔ |
| REIDENTIFICATION | Troca identificador com motivo | OP+aprovação TE/PR | Identificador anterior ativo; motivo | Inativa anterior, ativa novo | **R** | ✔ |
| CORRECT_REGISTRATION | Corrige dados cadastrais do animal | TE/PR | Animal existente | Campos cadastrais | P | ✔ |
| WEIGHING | Pesagem | OP | Animal ativo; peso em faixa | Peso atual, GMD | P | ✔ |
| LOT_CHANGE | Troca de lote de manejo | OP/TE | Lote destino ativo; R14 | currentHerdLotId | P | ✔ |
| PADDOCK_CHANGE | Realocação lote→piquete | OP/TE | Piquete da mesma propriedade | Lotação do piquete | P | ✔ |
| DIET_CHANGE | Mudança de dieta do lote | TE | Lote ativo | Dieta vigente | P | ✔ |
| BODY_SCORE | Escore corporal | TE/VE | Escala do programa | Último escore | P | ✔ |
| VACCINATION | Vacinação | VE / TE-delegado | R17; produto catalogado; sem bloqueio | Status sanitário; inicia carência se aplicável | P | ✔ |
| EXAM | Exame/coleta | VE | R17 | Histórico sanitário | P | ✔ |
| DIAGNOSIS | Diagnóstico | VE | R17; exam opcional referenciado | Status sanitário | P | ✔ |
| TREATMENT | Tratamento medicamentoso | VE / TE-delegado | R17; produto catalogado | Inicia carência | P | ✔ |
| WITHDRAWAL_PERIOD | Carência explícita (ajuste/registro) | VE | Evento sanitário de origem | WithdrawalPeriod | P | ✔ |
| QUARANTINE | Início de quarentena | VE/SY | Motivo; sujeito animal ou lote | Bloqueios R18 | **R** | ✔ |
| RELEASE | Fim de quarentena/bloqueio | VE | Quarentena aberta | Remove bloqueio | **R** | ✔ |
| BREEDING | Cobertura natural | TE/OP | Fêmea apta; touro identificado | Histórico reprodutivo | P | ✔ |
| INSEMINATION | IA/IATF | TE/VE | Fêmea apta; sêmen identificado | Histórico reprodutivo | P | ✔ |
| PREGNANCY_CHECK | Diagnóstico de gestação | VE/TE | Fêmea | Status reprodutivo | P | ✔ |
| CALVING | Parto | OP/TE | Fêmea gestante (alerta se não) | Pode encadear REGISTER_ANIMAL | P | ✔ |
| OFFSPRING_LINK | Vínculo mãe-cria | OP/TE/SY | Ambos existem; cria sem mãe vinculada | damId da cria | P | ✔ |
| PROPERTY_ENTRY | Entrada em propriedade | OP/PR | Shipment recebido ou entrada avulsa justificada | currentPropertyId | P | ✔ |
| PROPERTY_EXIT | Saída de propriedade | OP/PR | Animal na propriedade; sem bloqueio R18 | Estado `IN_TRANSIT` | P | ✔ |
| SHIPMENT_DISPATCHED | Expedição de embarque | PR/OP | R15; animais sem bloqueio; GTA conforme UF | Shipment `DISPATCHED`; animais `IN_TRANSIT` | **R** | ✖ (cancela via evento próprio) |
| SHIPMENT_RECEIVED | Recebimento de embarque | FR/PR destino | Shipment `DISPATCHED`; conferência feita | Shipment `RECEIVED[_WITH_DISCREPANCY]` | **R** | ✖ |
| CUSTODY_TRANSFERRED | Transferência de posse física | TR/PR/FR | Cadeia de custódia consistente | Custody | **R** | ✔ |
| OWNERSHIP_TRANSFERRED | Transferência de propriedade jurídica | PR→comprador | Cedente é dono; aceite do comprador | Ownership | **R** | ✔ |
| GTA_REGISTERED | Registro/associação de GTA | PR/TR/FR/AD | Documento anexado; número único | GTARecord | P | ✔ |
| SLAUGHTER | Abate | FR | Animal recebido no frigorífico; carência (R18) | `SLAUGHTERED`; encerra ciclo (R32) | **R** | ✖ |
| DEATH | Óbito | PR/VE | Animal ativo; causa | `DEAD`; encerra ciclo (R32) | **R** | ✖ |
| CARCASS_CREATED | Criação de carcaça | FR | Animal `SLAUGHTERED` sem carcaça (R33) | Carcass | **R** | ✔ |
| CUT_LOT_CREATED | Lote de corte | FR | ProcessingLot com carcaças; R34 | CutLot | **R** | ✔ |
| DOCUMENT_ATTACHED | Anexo de documento a sujeito | vários | Documento carregado com hash | Vínculo doc-sujeito | P | ✔ |
| CERTIFIED | Certificação emitida | CE | Dossiê avaliado; sem conflito de interesse | Certificate `ACTIVE` | **R** | ✖ (revoga via REJECTED/evento de revogação) |
| REJECTED | Rejeição/revogação de certificação | CE | Solicitação ou certificado existente; motivo | Certificate `REVOKED`/negado | **R** | ✖ |
| CORRECTED | Correção genérica de evento | autor original ou superior | Evento alvo aceito; janela/permissão Doc 7 | Marca alvo como corrigido; projeções recalculam | P | ✖ (corrige-se a correção com nova CORRECTED) |
| BLOCKCHAIN_ANCHORED | Confirmação de âncora (interno) | SY | Tx confirmada | Event.blockchainTxId | — (é a âncora) | ✖ |
| RECORD_CLOSED | Encerramento formal do registro | SY/AD | Ciclo encerrado + pendências resolvidas | `CLOSED` (R14) | **R** | ✖ |

## 4. Especificações detalhadas dos payloads críticos

Formato: campos obrigatórios **negrito**; demais opcionais. Regras de rejeição
além das comuns (§2).

### 4.1 REGISTER_ANIMAL

Payload: **speciesCode**, **sex**, **birthType**, birthDate (obrigatória se
`BORN_ON_PROPERTY`), breedCode, damId, sireRef, entryOrigin (propriedade/UF de
origem se `PURCHASED`), initialIdentifiers[] (lista de LINK_IDENTIFIER embutidos,
processados atomicamente).
Rejeição: identificador em uso (`ERR-ANI-001`); birthDate futura (`ERR-ANI-003`);
propriedade de outra org sem vínculo.
Resultado: Animal criado, identificadores ativos, `lifecycleStatus=ACTIVE`.
Documentos: nota fiscal/GTA de entrada quando `PURCHASED` (recomendado, não bloqueante).

### 4.2 REIDENTIFICATION

Payload: **oldIdentifierId**, **newIdentifier** {type, rfidCode|visualTagNumber|officialNumber},
**reason** (`LOST/DAMAGED/RECALL/UPGRADE/ERROR`), approvedBy (userId com papel TE/PR —
obrigatório quando ator é OP), photoDocumentId.
Rejeição: novo identificador em uso; motivo ausente; aprovador sem permissão.
Resultado: identificador antigo `active=false` com `unlinkReason` preservado (R5, R6);
novo ativo. Endosso reforçado: evento sensível a fraude.

### 4.3 WEIGHING

Payload: **weightKg** (decimal 6,2), **weightSource** (`SCALE/MANUAL`),
scaleId (obrigatório se `SCALE`), stabilityFlag, notes.
Rejeição: fora de faixa da categoria (`ERR-PES-001`).
Alerta (aceita, marca `flagged`): variação >30% vs. última pesagem válida.
Resultado: projeção WeightRecord; recálculo de GMD.

### 4.4 VACCINATION / TREATMENT

Payload: **productRef** (catálogo), **dosage** {value, unit}, **route**
(`SC/IM/IV/ORAL/POUR_ON`), batchNumber (lote do produto), expiryDate,
prescriptionDocumentId, appliedBy (se aplicação delegada — R17),
protocolCode (campanha/programa), batchId (agrupador de aplicação em lote).
Rejeição: `ERR-SAN-001` (credencial), `ERR-SAN-003` (produto), bloqueio R18 ativo
incompatível.
Resultado: HealthRecord; WithdrawalPeriod criado automaticamente com
`endAt = occurredAt + carência do produto` quando aplicável.

### 4.5 SHIPMENT_DISPATCHED

Sujeito: `SHIPMENT`. Payload: **shipmentId**, **animalIds[]** (ou herdLotId
expandido no aceite), **purpose**, gtaRecordId (obrigatoriedade parametrizada por
UF/finalidade), carrierOrgId, vehiclePlate, expectedArrival.
Rejeição: animal com quarentena/carência conforme parametrização (`ERR-MOV-001`);
animal fora da propriedade de origem; shipment não-DRAFT.
Resultado: Shipment `DISPATCHED`; para cada animal, `PROPERTY_EXIT` derivado e
estado `IN_TRANSIT`; Custody aberta para transportadora se informada.
Não corrigível: cancela-se com evento de cancelamento antes do recebimento.

### 4.6 SHIPMENT_RECEIVED

Sujeito: `SHIPMENT`. Payload: **shipmentId**, **readAnimalIds[]** (conferência
física por leitura), unexpectedRfids[] (lidos e não esperados), notes.
Processamento: comparação esperado × lido. Completo ⇒ `RECEIVED` + `PROPERTY_ENTRY`
por animal. Divergente ⇒ `RECEIVED_WITH_DISCREPANCY` + ocorrência por animal
faltante/excedente (R16); animais confirmados entram, faltantes permanecem
`IN_TRANSIT` até resolução.
Rejeição: shipment inexistente ou não-DISPATCHED (`ERR-MOV-002`).

### 4.7 OWNERSHIP_TRANSFERRED

Fluxo bilateral: evento do cedente cria proposta (`PENDING_ACCEPTANCE`); evento de
aceite do adquirente (mesmo tipo, `role: ACCEPTOR`, referência à proposta) efetiva.
Payload: **animalIds[]**, **counterpartyOrgId**, **role** (`GRANTOR/ACCEPTOR`),
proposalEventId (no aceite), saleDocumentId. Preço **nunca** no payload on-chain —
documento comercial off-chain (Doc 11).
Rejeição: cedente não é proprietário (`ERR-CUS-002`); aceite sem proposta;
proposta expirada (janela parametrizada, padrão 30 dias).

### 4.8 SLAUGHTER / DEATH

SLAUGHTER payload: **slaughterDate**, **sifNumber**, sequenceNumber (ordem no
abate), inspectionDocumentId. Pré: animal `RECEIVED` no frigorífico; carência R18.
DEATH payload: **causeCategory** (`DISEASE/ACCIDENT/PREDATION/UNKNOWN/EUTHANASIA`),
causeDetail, vetReportDocumentId, disposalMethod.
Ambos: encerram ciclo (R32); eventos posteriores incompatíveis rejeitados com
`SUBJECT_CLOSED` (R14). Compatíveis pós-encerramento: DOCUMENT_ATTACHED, CORRECTED,
CARCASS_CREATED (só após SLAUGHTER), RECORD_CLOSED.

### 4.9 CARCASS_CREATED / CUT_LOT_CREATED

CARCASS_CREATED: **animalId**, **carcassWeightKg**, typification, sifNumber.
Rejeição: animal não abatido; carcaça já existente (R33).
CUT_LOT_CREATED (sujeito `CUT_LOT`): **processingLotId**, **cutCode**,
**outputWeightKg**, packagingDate, expiryDate. Rejeição: balanço de massa (R34,
`ERR-POS-001`). Resultado: CutLot com `publicCode` gerado (não sequencial) para QR.

### 4.10 CORRECTED

Payload: **targetEventId**, **reason**, **correctedFields** (subconjunto do payload
original com novos valores) ou **fullReplacementPayload**.
Regras: alvo deve estar `ACCEPTED_BY_API` ou posterior; autor = autor original ou
papel superior autorizado (Doc 7); alvo não pode ser tipo não-corrigível (§3);
cadeia de correções linear (corrigir a correção, não o original duas vezes).
Resultado: original permanece com flag `corrected=true` e link; projeções
recalculadas usando a versão corrigida; ambos ancorados.

### 4.11 DOCUMENT_ATTACHED

Payload: **documentId**, **subjectType**, **subjectId**, **documentClass**, note.
Pré: documento carregado com sha256 conferido. Resultado: vínculo consultável na
linha do tempo do sujeito; hash do documento passa a compor o dossiê verificável.

### 4.12 CERTIFIED / REJECTED

CERTIFIED: **scopeType**, **scopeId**, **protocolCode**, **validFrom**,
**validUntil**, dossierDocumentIds[]. Pré: solicitação existente; certificador de
org distinta do detentor do escopo (`ERR-CER-002`). Endosso: OrgCertificadora +
OrgFundacao obrigatórios.
REJECTED: **scopeType/scopeId**, **reasonCode**, reasonDetail, targetCertificateId
(quando revogação). Mesma política de endosso.

## 5. Dados on-chain por evento

Para **todos** os tipos, sobe on-chain apenas o registro-âncora definido no
Documento 11 §2 (identificadores controlados, tipo, datas, org, hash, assinatura,
referência, correção). Nenhum payload completo sobe. Eventos com endosso **R**
diferem apenas na política de endosso, não no conteúdo ancorado.

## 6. Versionamento de schema

- `schemaVersion` por tipo, semver. Mudança compatível (campo opcional novo) =
  minor; incompatível = major com período de dupla aceitação ≥2 versões de app.
- API valida contra o schema da versão declarada; app antigo nunca é rejeitado por
  existir schema mais novo dentro da janela de suporte.
- Registro central de schemas em repositório versionado, publicado com a API
  (`GET /event-schemas/{type}/{version}`).
