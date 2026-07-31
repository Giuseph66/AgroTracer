# Documento 11 — Dados On-Chain e Off-Chain

## 1. Princípio

On-chain vai **apenas o mínimo necessário para provar integridade, autoria
organizacional e sequência** de um fato. Todo conteúdo informacional vive
off-chain (PostgreSQL + storage de objetos) sob controle de acesso. A blockchain é
irrevogável: **qualquer dado gravado on-chain é permanente** — por isso a fronteira
é uma regra de compliance (R21), não uma preferência técnica.

## 2. Dados permitidos on-chain (registro-âncora)

| Campo | Exemplo | Justificativa |
|-------|---------|---------------|
| Identificador controlado do sujeito | `animalId` (UUID), `rfidCode`, `officialAnimalId`, `shipmentId`, `documentId`, `cutLotId.publicCode` | Identificadores operacionais/oficiais de animal e objetos — não identificam pessoa natural |
| Tipo do evento | `VACCINATION` | Semântica mínima da prova |
| Datas | `occurredAt`, `recordedAt` (truncadas a segundo) | Sequência temporal |
| Organização | MSP ID / organizationId | Autoria institucional |
| Função do signatário | papel (ex.: `VETE`), **nunca** nome/CPF | Prova de competência sem dado pessoal |
| Hash | `payloadHash` SHA-256, `sha256` de documento | Núcleo da prova de integridade |
| Assinatura | assinatura ECDSA do dispositivo (sobre o hash) | Não-repúdio da origem |
| Referência lógica | `eventId`, `payloadRef`, `correctionOf`, versão de documento | Ligação verificável ao off-chain |
| Status | `ACTIVE/CLOSED`, fase do shipment | Máquina de estados mínima |
| Versão | `schemaVersion`, versão de documento | Interpretação futura |
| TxID | preenchido pela própria rede | Prova de inclusão |

## 3. Dados obrigatoriamente off-chain (lista proibitiva)

Nunca, em nenhuma função, coleção privada ou campo livre:

- CPF; CNPJ completo quando o contexto o torne sensível (ex.: produtor pessoa física com CNPJ rural individual);
- nomes de pessoas naturais; endereços completos;
- coordenadas geográficas precisas de propriedades (sensíveis por segurança patrimonial) — município/UF são aceitáveis em visões públicas off-chain, não on-chain;
- fotos, vídeos, biometria;
- laudos, receitas, atestados, documentos integrais em qualquer formato;
- preços, condições de negociação, contratos, dados comerciais;
- telemetria bruta e séries extensas de sensores (volume e re-identificação);
- qualquer campo de texto livre digitado por usuário (risco de dado pessoal embutido).

Salvaguardas de engenharia:

1. Chaincode com structs fechados — sem campos `map`/texto livre; validação de
   formato (UUID, hex-64, enums) rejeita conteúdo fora do padrão.
2. Teste automatizado de CI que valida schemas de âncora contra a lista proibitiva.
3. Code review de chaincode exige aprovação do responsável de privacidade (Doc 13).

## 4. Canonicalização e hash

- Serialização canônica do payload: **JCS (RFC 8785)** — chaves ordenadas, sem
  espaços, números normalizados, UTF-8.
- `payloadHash = SHA-256(JCS(payload))`, hex minúsculo.
- Documentos: `sha256` dos bytes do arquivo original (por versão).
- A mesma rotina de canonicalização é usada no app (Dart), na API (TS) e na
  verificação — biblioteca compartilhada com vetores de teste idênticos nos três
  ambientes (Doc 15).

## 5. Verificação de documento off-chain contra âncora on-chain

Procedimento (implementado em `GET /v1/documents/{id}/verify` e executável
manualmente por auditor):

1. Obter o documento (bytes) do storage — ou receber o arquivo do interessado.
2. Calcular `SHA-256(bytes)`.
3. Consultar a âncora: `VerifyProof(documentId)` via Gateway (ou endpoint de prova),
   obtendo `{sha256 ancorado, versão, TxID, bloco, timestamp, orgs endossantes}`.
4. Comparar os hashes:
   - iguais ⇒ **ÍNTEGRO**: este exato conteúdo existia e foi ancorado naquele instante por aquelas organizações;
   - diferentes ⇒ **DIVERGENTE**: o arquivo apresentado não é o ancorado (adulteração ou versão errada — conferir `previousVersionId`).
5. (Auditoria profunda) Validar a inclusão da transação no bloco e as assinaturas
   dos peers endossantes com os certificados MSP da configuração do canal —
   independe da plataforma estar no ar.

O mesmo procedimento vale para eventos: recuperar `EventPayload.canonicalJson`,
recanonicalizar, comparar com `payloadHash` ancorado.

## 6. O que a verificação prova — e o que não prova

| Prova | Sim/Não |
|-------|:-:|
| O conteúdo não foi alterado desde a âncora | ✔ |
| Quem (org, dispositivo, papel) registrou e quando | ✔ |
| Quais organizações endossaram | ✔ |
| O conteúdo é verdadeiro na origem | ✖ (Doc 1 §8) |
| O documento é oficialmente válido perante órgão público | ✖ — validade oficial só com homologação junto ao órgão |
