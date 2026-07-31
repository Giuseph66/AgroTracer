# Documento 6 — Regras de Negócio

Formato: **Enunciado · Aplicação (onde é imposta) · Verificação (como testar) ·
Violação (comportamento)**. Referências cruzadas: Doc 4 (modelo), Doc 5 (eventos),
Doc 8 (offline), Doc 9 (API), Doc 15 (testes).

| # | Regra | Aplicação | Violação → comportamento |
|---|-------|-----------|--------------------------|
| R1 | `animalId` (UUID interno) é imutável desde a criação | Sem endpoint/coluna de update; PK nunca reciclada | Tentativa de update ⇒ 405/erro de domínio |
| R2 | `officialAnimalId` único dentro do contexto oficial aplicável (país+programa) | UNIQUE parcial em Animal; validação em REGISTER_ANIMAL e CORRECT_REGISTRATION | `ERR-ANI-001`, conflito 409 |
| R3 | Um `rfidCode` ativo nunca associado a dois animais simultaneamente | UNIQUE parcial `(rfidCode) WHERE active AND type=RFID`; validação no app (base local) e na API | Offline: bloqueio na tela; sync: `IDENTIFIER_TAKEN` (conflito) |
| R4 | Animal tem histórico de identificadores; apenas 1 ativo por tipo | UNIQUE parcial `(animalId, identifierType) WHERE active` | Rejeição do LINK_IDENTIFIER redundante |
| R5 | Troca de brinco gera obrigatoriamente `REIDENTIFICATION` | Único fluxo que inativa identificador; app não oferece "editar brinco" | Não há caminho alternativo (design) |
| R6 | Identificador anterior nunca é apagado | AnimalIdentifier append-only; `active=false` + vigências | UPDATE/DELETE sem grant no usuário de aplicação |
| R7 | Nenhuma exclusão física de eventos históricos | Grants revogados; sem endpoint DELETE de eventos | Operação inexiste |
| R8 | Correção = novo evento com `correctionOf`; original preservado | Evento `CORRECTED` (Doc 5 §4.10); projeções usam versão corrigida | Editar evento sincronizado ⇒ 405 |
| R9 | "Peso atual" = derivado da última `WEIGHING` válida (não corrigida) | Projeção WeightRecord; campo nunca editável | — |
| R10 | Idade = calculada de `birthDate`; nunca armazenada como campo editável | Cálculo em leitura/projeção | — |
| R11 | GMD = (pesoB − pesoA) / dias, entre pesagens válidas consecutivas; pesagens corrigidas usam valor corrigido, invalidadas são ignoradas | Serviço de projeção | — |
| R12 | Status sanitário = derivado dos eventos sanitários (vacinas em dia, carências, quarentenas) | Projeção HealthRecord/WithdrawalPeriod/Quarantine | — |
| R13 | `lifecycleStatus` = derivado de eventos; nunca alterado por edição direta | Projeção; sem endpoint de escrita | — |
| R14 | Animal com ciclo encerrado (`SLAUGHTERED/DEAD/CLOSED`) rejeita eventos incompatíveis; aceita apenas DOCUMENT_ATTACHED, CORRECTED, CARCASS_CREATED (pós-abate), RECORD_CLOSED | Validação de aceite (Doc 5 §2.5) | `SUBJECT_CLOSED` (conflito 409) |
| R15 | Movimentação exige par expedição (`SHIPMENT_DISPATCHED`) e recebimento (`SHIPMENT_RECEIVED`) | Máquina de estados do Shipment | Recebimento órfão ⇒ `ERR-MOV-002` |
| R16 | Divergência no recebimento (faltante/excedente/identidade) gera ocorrência obrigatória com fluxo de resolução | Processamento do SHIPMENT_RECEIVED (Doc 5 §4.6) | Nunca silenciosa; notificação crítica |
| R17 | Eventos sanitários respeitam credencial profissional: atos privativos exigem VE com `professionalCredential` vigente; delegação a TE parametrizável por programa | Validação de permissão + credencial em `occurredAt` | `ERR-SAN-001` (403 na sync) |
| R18 | Bloqueios por quarentena, carência e protocolo são parametrizáveis por programa, UF e vigência (tabela de parametrização versionada) | Serviço de regras consultado em WEIGHING? não — em SHIPMENT_DISPATCHED, SLAUGHTER, PROPERTY_EXIT, VACCINATION | Bloqueio (rejeição) ou ocorrência grave, conforme parâmetro |
| R19 | Documento nunca é substituído silenciosamente | Storage com versionamento; sem overwrite de storageKey | Upload sobre existente ⇒ nova versão |
| R20 | Nova versão de documento preserva a anterior (`previousVersionId`) | Modelo Document (Doc 4 §4.5) | — |
| R21 | Dados pessoais e documentos completos jamais gravados on-chain | Fronteira do Doc 11; chaincode aceita apenas campos do registro-âncora; revisão de schema obrigatória | Gate de code review + teste automatizado de schema |
| R22 | Duplicidade impedida por `eventId` (global) e `(deviceId, deviceSequence)` | UNIQUE constraints; verificação idempotente na ingestão | Reenvio ⇒ resposta idempotente (200 com resultado original), nunca segundo registro |
| R23 | API idempotente: mesmo `eventId` ou mesma `Idempotency-Key` retornam o resultado original | Doc 9 §4 | — |
| R24 | `occurredAt` (fato) ≠ `recordedAt` (registro): campos distintos, ambos obrigatórios | Envelope (Doc 5 §1); tolerância de relógio no Doc 8 §9 | Divergência excessiva ⇒ flag de revisão |
| R25 | Todo evento registra `deviceId` e `appVersion` | Envelope obrigatório; dispositivo deve estar registrado | `ERR-DEV-001/002` |
| R26 | Assinatura do evento validada antes da aceitação, contra a chave pública registrada do dispositivo | Pipeline de ingestão (etapa 2, antes de qualquer regra de negócio) | Rejeição definitiva `REJECTED_BY_API` |
| R27 | Eventos offline preservam ordem local: `deviceSequence` monotônico; ingestão processa em ordem de sequência por dispositivo | Fila local (Doc 8 §3); ordenação na ingestão | Lacuna de sequência ⇒ processamento adiado do posterior (janela), depois `ORDER_VIOLATION` |
| R28 | Autorização avaliada no momento do evento (`occurredAt`): usuário revogado depois não invalida eventos anteriores; usuário sem permissão à época é rejeitado mesmo se autorizado agora | Snapshot temporal de papéis/vínculos (tabelas com vigência) | 403 com motivo temporal |
| R29 | Vinculação SISBOV/GTA ocorre exclusivamente via adaptadores + reconciliação assíncrona; núcleo nunca chama sistema externo em linha | Arquitetura Doc 12 | — |
| R30 | Falha externa jamais apaga ou bloqueia o evento interno; evento fica `EXTERNAL_INTEGRATION_FAILED` com retry | Estados Doc 8 §5 | — |
| R31 | Toda chamada externa registra request, response, status HTTP e número da tentativa (com expurgo de dados sensíveis nos logs) | IntegrationAttempt log (Doc 12 §6) | — |
| R32 | `SLAUGHTER` ou `DEATH` encerram o ciclo do animal | lifecycleStatus terminal (R13, R14) | — |
| R33 | `CARCASS_CREATED` exige animal `SLAUGHTERED` e é única por animal | FK UNIQUE Carcass.animalId | `ERR-FRI-*` / conflito |
| R34 | Transformações preservam origem e balanço de massa: Σ saídas ≤ Σ entradas × (1+tolerância); tolerância parametrizada (padrão 2%) | Validação em CUT_LOT_CREATED; vínculos carcaça→lote persistidos | `ERR-POS-001` |
| R35 | Toda ação administrativa relevante (gestão de usuários, papéis, dispositivos, orgs, parâmetros, exportações, resoluções de conflito) gera AuditLog append-only | Interceptor transversal no backend | Ausência = defeito bloqueante de release |

## Regras complementares (derivadas dos documentos técnicos)

| # | Regra | Origem |
|---|-------|--------|
| R36 | Org suspensa: eventos novos rejeitados; histórico permanece legível | Doc 3 §2 |
| R37 | Transferência de propriedade exige aceite bilateral registrado; proposta expira (padrão 30 dias) | Doc 5 §4.7 |
| R38 | Certificador não certifica escopo da própria organização | Doc 3 §15 |
| R39 | `publicCode` de CutLot/Certificate é não sequencial e não enumerável | Doc 3 §26 |
| R40 | Dispositivo revogado: sync bloqueada; eventos ainda locais podem ser reemitidos por outro dispositivo com nova autoria explícita (novo eventId, referência ao original local) | Doc 8 §10 |
| R41 | Parametrizações (R18, faixas de peso, tolerâncias) são versionadas com vigência; avaliação usa a versão vigente em `occurredAt` | Consistência com R28 |
| R42 | Relatórios e projeções nunca são fonte de verdade; qualquer projeção é regerável por replay de eventos | Doc 4 §3 |

**QUESTÃO EM ABERTO** — janela máxima para `CORRECTED` por autor original sem
aprovação de superior (proposta: 72h após aceite; depois exige papel de aprovação).
Decidir com o piloto.
