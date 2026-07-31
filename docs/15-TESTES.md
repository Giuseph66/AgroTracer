# Documento 15 — Testes e Critérios de Aceite

## 1. Estratégia

| Nível | Escopo | Ferramentas (referência) |
|-------|--------|--------------------------|
| Unitário | Regras de negócio, canonicalização/hash, máquinas de estado | Jest/Vitest (TS), flutter_test (Dart), go test (chaincode) |
| Contrato | OpenAPI × implementação; JSON Schemas de eventos; vetores de hash idênticos Dart/TS/Go | Schemathesis/dredd + suíte de vetores compartilhada |
| Integração | API + Postgres + Redis + MinIO + Fabric efêmero | Testcontainers/Compose efêmero |
| E2E | Fluxos completos app→API→âncora | Patrol/integration_test (Flutter) + ambiente test |
| Caos/resiliência | Rede, peers, adaptadores | Toxiproxy, kill de containers |
| Carga | Metas RNF | k6 |
| Campo | Hardware real (leitores, balanças, brincos) | Protocolo manual roteirizado |

Critério transversal: todo cenário abaixo tem resultado esperado **verificável e
automatizado onde possível**; os manuais (hardware) têm roteiro e evidência.

## 2. RFID

| Cenário | Resultado esperado |
|---------|--------------------|
| Leitura normal (FDX-B/HDX) | Animal resolvido e tela pronta ≤2s |
| Leitura duplicada em sequência (mesmo animal 2× no brete) | Segunda leitura reconhecida como o mesmo contexto; sem evento duplicado |
| Tag desconhecida | Fluxo "tag desconhecida" (Doc 8 §10): captura com RFID bruto; conflito se não resolvido |
| Tag danificada (leitura falha) | Fallback manual por visualTagNumber com flag de origem manual |
| Troca de tag | REIDENTIFICATION com aprovação; antigo preservado (R5, R6); tentativa de reuso do antigo em outro animal falha |
| Dois leitores próximos (colisão) | Leitura atribuída ao leitor pareado da sessão; sem evento fantasma |
| Perda de comunicação leitor↔app no meio do lote | Fila de leituras preservada; reconexão retoma sem perda/duplicata |

## 3. Offline

| Cenário | Resultado esperado |
|---------|--------------------|
| 48h sem internet, operação plena | Todas as operações de campo executam; fila íntegra (Doc 8 §13.1) |
| Fila extensa (50.000 eventos) | App responsivo; sync completa em lotes; memória estável |
| Bateria acaba durante gravação | Evento atômico: existe completo ou não existe |
| Reinício do dispositivo | Fila e deviceSequence intactos |
| Relógio incorreto (+2 dias) | Eventos aceitos com flag TIME_SUSPECT; skew registrado (Doc 8 §9) |
| Reenvio (resposta perdida) | Dedup por eventId; duplicate=true; zero duplicatas no banco |
| Conflito (RFID tomado, estado obsoleto) | Classificação correta (Doc 8 §7); resolução pelo painel reflete no app |

## 4. Regras de negócio

| Cenário | Resultado esperado |
|---------|--------------------|
| Expedição de animal em quarentena | Bloqueio ou ocorrência conforme parametrização vigente em occurredAt (R18, R41) |
| Abate dentro de carência | `ERR-FRI-002`/ocorrência grave conforme programa |
| Transferência de propriedade sem aceite | Proposta fica pendente; efeito só após aceite; expira em 30 dias (R37) |
| Recebimento com animal faltante | RECEIVED_WITH_DISCREPANCY + ocorrência + notificação ≤1min (R16) |
| Evento em animal encerrado | `SUBJECT_CLOSED` 409; tipos compatíveis (DOCUMENT_ATTACHED, CORRECTED) aceitos (R14) |
| Documento inválido (hash divergente, MIME proibido) | `ERR-DOC-001/002`; versão anterior intacta (R19, R20) |
| Correção de pesagem | Original preservado e marcado; GMD recalculado com valor corrigido (R8, R11) |

## 5. Segurança

| Cenário | Resultado esperado |
|---------|--------------------|
| Usuário revogado sincroniza eventos anteriores à revogação | Aceitos (R28); eventos com occurredAt posterior à revogação rejeitados 403 |
| Certificado Fabric revogado | Endosso falha; alerta; CRL propagada ≤1h |
| Acesso entre organizações (dados de outra org) | 404/403; tentativa registrada |
| Replay de lote/evento | Resposta idempotente; nunca segundo registro (R22) |
| Payload adulterado (assinatura não confere) | REJECTED_BY_API definitivo (R26) |
| Adulteração direta no banco (simulada) | Verificação hash × âncora detecta divergência (Doc 11 §5) |
| Tentativa de vazamento via QR público | Nenhum campo P1+ presente; enumeração bloqueada por rate limit e códigos não sequenciais (R39) |
| Ação administrativa sem AuditLog | Impossível — teste transversal falha o build (R35) |

## 6. Blockchain

| Cenário | Resultado esperado |
|---------|--------------------|
| 1 peer endossante indisponível | Política satisfeita por peer redundante da mesma org; sem impacto |
| Org autora inteira indisponível | Âncora em retry (PENDING_BLOCKCHAIN); evento interno intacto; alerta após SLA |
| Orderer minoritário indisponível | Raft segue; sem impacto |
| Falha de endosso (política não satisfeita) | Âncora FAILED com motivo; retry/escala manual |
| Upgrade de chaincode | Versão nova ativa após aprovação de maioria; transações em voo concluem na anterior |
| Restauração de peer do zero | Re-join e sincronização completa; alturas convergem |
| Verificação independente | Auditor valida inclusão e endossos com material do canal, sem depender da API |

## 7. Integrações externas

| Cenário | Resultado esperado |
|---------|--------------------|
| Timeout do serviço oficial | Retry com backoff; circuito abre após 5 falhas (Doc 12 §6) |
| Resposta parcial/malformada | Registro em integration_attempt; item para fila de erro; sem corrupção interna |
| Payload rejeitado pelo oficial | EXTERNAL_INTEGRATION_FAILED com motivo; painel manual |
| Duplicidade externa | Query prévia evita reenvio duplicado |
| Indisponibilidade prolongada (24h+) | Núcleo opera normalmente; fila drena na volta (R30) |
| Divergência plantada | Detectada pela reconciliação ≤24h, classificada corretamente (Doc 12 §7) |

## 8. Desempenho (k6 + campo)

| Cenário | Meta |
|---------|------|
| Leitura em curral (ciclo completo por animal) | ≤5s/animal, 300 animais sem degradação |
| Cadastro em lote (500 REGISTER_ANIMAL num lote de sync) | Processado ≤60s; veredicto individual correto |
| Consulta de histórico (animal com 2.000 eventos) | Timeline paginada p95 ≤500ms |
| Relatório de inventário (10.000 animais) | ≤60s assíncrono |
| Sincronização em massa (50 dispositivos × 1.000 eventos simultâneos) | Sem erro, sem duplicata; ingestão ≥200 eventos/s |
| QR público sob carga (100 rps) | p95 ≤1s com cache |

## 9. Gates de aceite por fase

Cada fase do roadmap (Doc 16) só passa pelo gate com: 100% dos cenários da fase
verdes, cobertura unitária ≥80% no código de domínio, zero achados críticos de
segurança abertos, e evidência arquivada dos testes manuais de campo.
