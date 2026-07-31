# Documento 2 — PRD (Product Requirements Document)

## 1. Visão

Ver Documento 1, seção 3. Síntese: plataforma de rastreabilidade bovina orientada a
eventos, offline-first no campo, com prova de integridade multi-organização em
Hyperledger Fabric e reconciliação com sistemas oficiais por adaptadores.

## 2. Problema

Registro zootécnico e sanitário fragmentado, sem conectividade no ponto de coleta,
sem trilha de auditoria confiável, sem prova de integridade aceita por terceiros
(certificadoras, frigoríficos, importadores).

## 3. Público-alvo

- Propriedades de cria, recria e engorda (ciclo completo ou parcial), de 300 a 50.000 cabeças.
- Certificadoras de protocolos privados e habilitadas SISBOV.
- Frigoríficos com programas de originação verificada.
- Exportadores que precisam responder a exigências documentais (EUDR e similares).

## 4. Personas

| Persona | Contexto | Necessidade central | Dores |
|---------|----------|---------------------|-------|
| **Produtor** (dono/gestor) | Escritório da fazenda, conectividade parcial | Visão do rebanho, conformidade, valor na venda | Retrabalho, multas, lotes desqualificados |
| **Operador de curral** | Brete, luvas, poeira, sem internet | Registrar rápido: ler brinco, pesar, aplicar, seguir | Apps lentos, telas pequenas, digitação |
| **Técnico agropecuário** | Campo, múltiplas propriedades | Manejo, lotes, dietas, escore corporal | Dados espalhados, sem histórico |
| **Veterinário** | Campo + responsabilidade legal | Registrar atos privativos com respaldo (receita, carência) | Prova de autoria, bloqueios de carência manuais |
| **Certificador** | Remoto + visitas | Verificar integridade sem refazer coleta | Auditoria por amostragem cara e frágil |
| **Administrador da fundação** | Operação da plataforma | Governança da rede, onboarding de orgs, saúde do sistema | — |
| **Administrador de organização** | TI da org participante | Gerir usuários, dispositivos, permissões da sua org | — |
| **Auditor** | Independente | Ler tudo (escopo autorizado), alterar nada | Trilhas incompletas |
| **Transportador** | Estrada, offline | Aceitar/entregar custódia, associar GTA | Papel, responsabilidade difusa |
| **Operador de frigorífico** | Recepção e desossa | Receber lote, confirmar identidade, criar carcaça/cortes | Divergência entre GTA e físico |
| **Comprador** | Trading/varejo | Verificar dossiê do lote antes de pagar | Confiança em PDF adulterável |
| **Consumidor** | Ponto de venda | Escanear QR, ver origem | — |

## 5. Casos de uso principais

| ID | Caso de uso | Persona | Resumo |
|----|-------------|---------|--------|
| UC-01 | Registrar animal | Operador/Técnico | Nascimento ou entrada; gera `REGISTER_ANIMAL` + `LINK_IDENTIFIER` |
| UC-02 | Pesagem em brete | Operador | Leitura RFID → peso da balança → `WEIGHING`; lote contínuo |
| UC-03 | Vacinação de lote | Veterinário/Técnico | Seleção de lote → aplicação → `VACCINATION` por animal + `WITHDRAWAL_PERIOD` |
| UC-04 | Troca de brinco | Operador + aprovação | `REIDENTIFICATION` com identificador anterior preservado |
| UC-05 | Expedição de embarque | Produtor/Operador | Seleção de animais → `SHIPMENT_DISPATCHED` + associação de GTA |
| UC-06 | Recebimento de embarque | Destinatário | Conferência RFID → `SHIPMENT_RECEIVED`; divergência gera ocorrência |
| UC-07 | Transferência de propriedade | Produtor→Comprador | `OWNERSHIP_TRANSFERRED` com aceite de ambas as partes |
| UC-08 | Abate | Frigorífico | `SLAUGHTER` → `CARCASS_CREATED` → `CUT_LOT_CREATED` |
| UC-09 | Certificação de lote | Certificador | Verificação → `CERTIFIED`/`REJECTED` com endosso Fabric |
| UC-10 | Sincronização offline | App (automático) | Fila local → API idempotente → âncora blockchain |
| UC-11 | Consulta pública | Consumidor | QR → trilha resumida não sensível + prova de integridade |
| UC-12 | Auditoria | Auditor | Consulta de eventos, hashes, âncoras; exportação de dossiê |
| UC-13 | Correção de evento | Autor + permissão | Novo evento com `correctionOf`; original preservado |
| UC-14 | Reconciliação SISBOV | Sistema/Admin org | Job assíncrono confronta base interna × oficial; divergências viram fila |

## 6. Funcionalidades (visão de release)

| Funcionalidade | MVP (F1) | Campo (F2) | Piloto (F3) | Rede (F4) | Oficial (F5) | Frigorífico (F6) |
|----------------|:-:|:-:|:-:|:-:|:-:|:-:|
| Cadastro org/propriedade/usuários | ✔ | | | | | |
| Registro de animais e identificadores | ✔ | | | | | |
| Eventos zootécnicos/sanitários via API | ✔ | | | | | |
| Âncora blockchain (1 org, dev) | ✔ | | | | | |
| App Flutter offline + RFID + balança | | ✔ | | | | |
| Sincronização idempotente + conflitos | | ✔ | | | | |
| Movimentação, custódia, GTA (manual) | | ✔ | ✔ | | | |
| Operação real em propriedade | | | ✔ | | | |
| Fabric 3 orgs + políticas de endosso | | | | ✔ | | |
| Certificação com endosso | | | | ✔ | | |
| Adaptador SISBOV homologação | | | | | ✔ | |
| Abate, carcaça, cortes, QR público | | | | | | ✔ |

## 7. Requisitos funcionais

| ID | Requisito | Prioridade |
|----|-----------|------------|
| RF-001 | Registrar animal com os 4 identificadores separados (UUID, oficial, RFID, visual) | P0 |
| RF-002 | Todo fato zootécnico/sanitário/logístico é um evento imutável do catálogo (Doc 5) | P0 |
| RF-003 | App opera 100% das operações de campo sem conectividade | P0 |
| RF-004 | Sincronização idempotente por `eventId` + `deviceSequence` | P0 |
| RF-005 | Eventos assinados no dispositivo; assinatura validada antes do aceite | P0 |
| RF-006 | Estados derivados (peso atual, status sanitário, ciclo de vida) calculados de eventos, nunca editados diretamente | P0 |
| RF-007 | Correção via novo evento com `correctionOf`; nada é apagado | P0 |
| RF-008 | Movimentação com expedição e recebimento; divergência gera ocorrência | P0 |
| RF-009 | Documentos versionados com hash SHA-256 e âncora on-chain | P0 |
| RF-010 | Âncora blockchain de todo evento aceito, assíncrona, com estado rastreável | P0 |
| RF-011 | RBAC/ABAC conforme Documento 7, avaliado no momento do evento | P0 |
| RF-012 | Leitura RFID via Bluetooth/USB/serial com fila de leituras | P0 (F2) |
| RF-013 | Captura de peso da balança por integração ou digitação com flag de origem | P1 |
| RF-014 | Bloqueios parametrizáveis por quarentena/carência/protocolo (programa, UF, vigência) | P1 |
| RF-015 | Adaptadores SISBOV/GTA/estaduais desacoplados com reconciliação | P1 (F5) |
| RF-016 | Transformação pós-abate com preservação de origem e balanço de massa | P1 (F6) |
| RF-017 | Verificação pública por QR (GS1 Digital Link) sem dados sensíveis | P1 (F6) |
| RF-018 | Notificações (divergência, falha de integração, carência vencendo) | P2 |
| RF-019 | Relatórios (GMD, inventário, sanitário, dossiê de auditoria) | P2 |
| RF-020 | AuditLog de toda ação administrativa relevante | P0 |

## 8. Requisitos não funcionais

| ID | Categoria | Requisito |
|----|-----------|-----------|
| RNF-001 | Offline | App funcional ≥48h sem rede; fila local ≥50.000 eventos |
| RNF-002 | Desempenho campo | Ciclo leitura RFID → confirmação em tela ≤2s; pesagem em brete ≤5s/animal |
| RNF-003 | Desempenho API | p95 ≤500ms para escrita de evento; ingestão em lote ≥200 eventos/s por nó |
| RNF-004 | Sincronização | 10.000 eventos pendentes sincronizados em ≤10min em 4G |
| RNF-005 | Disponibilidade | API 99,5% (piloto), 99,9% (produção); app independe da API |
| RNF-006 | Durabilidade | Zero perda de evento aceito; RPO ≤5min, RTO ≤4h (produção) |
| RNF-007 | Segurança | TLS 1.2+ externo, mTLS interno e Fabric; OIDC + MFA; segredos em Vault/KMS |
| RNF-008 | Privacidade | LGPD conforme Documento 13; dados pessoais nunca on-chain |
| RNF-009 | Auditabilidade | Qualquer evento reconstituível com autoria, dispositivo, hash e âncora |
| RNF-010 | Escala | 1M animais, 100M eventos, 500 dispositivos simultâneos (produção) |
| RNF-011 | Observabilidade | Métricas Prometheus, logs centralizados, tracing com correlationId |
| RNF-012 | Compatibilidade | Android 10+; leitores ISO 11784/11785 (FDX-B/HDX) |
| RNF-013 | Verificação pública | Página QR ≤3s em 4G, sem autenticação |

## 9. Restrições

- Backend Node.js + TypeScript (**DECISÃO** no Doc 9: NestJS).
- Banco operacional PostgreSQL + PostGIS.
- Blockchain exclusivamente Hyperledger Fabric permissionado.
- App exclusivamente Flutter/Dart, Android primeiro.
- Sem dados pessoais/documentos integrais on-chain (Doc 11).
- Sem emissão de documentos oficiais.

## 10. Dependências

Ver Documento 1, seção 11 (D1–D6). Adicionais de produto:

- Definição de protocolo de certificação de referência para o piloto (**QUESTÃO EM ABERTO**).
- Hardware de referência: 1 modelo de leitor RFID e 1 de balança homologados antes da Fase 2.

## 11. Fora de escopo

Ver Documento 1, seção 7. Adicional de produto: modo multiusuário simultâneo no
mesmo dispositivo (um usuário logado por dispositivo por vez); edição de eventos
sincronizados (só correção); app web de campo (campo é mobile).

## 12. Roadmap

Ver Documento 16. Fases 0–8.

## 13. Métricas de produto

| Métrica | Definição | Meta piloto |
|---------|-----------|-------------|
| Taxa de sincronização limpa | eventos aceitos sem intervenção / total | ≥95% |
| Tempo médio por animal no brete | leitura → confirmação | ≤5s |
| Cobertura de identificação | animais com RFID ativo / rebanho | ≥98% |
| Latência de âncora | aceite API → CONFIRMED_ON_BLOCKCHAIN (p95) | ≤5min |
| Divergências de recebimento | ocorrências / embarques | medir (baseline) |
| Adoção | eventos via app / eventos totais | ≥90% |
| Reconciliação oficial (F5) | registros conciliados sem ação manual | ≥99% |

## 14. Critérios de aceite globais

1. Nenhuma tela ou endpoint permite editar evento sincronizado — apenas corrigir.
2. Todo evento aceito possui `payloadHash` verificável e, após âncora, `blockchainTxId`.
3. App em modo avião executa UC-01, UC-02, UC-03, UC-04 integralmente.
4. Reenvio do mesmo evento (mesmo `eventId`) nunca duplica registro nem âncora.
5. Usuário revogado tem eventos rejeitados na sincronização com erro explícito.
6. QR público jamais expõe CPF, coordenadas precisas, preços ou documentos integrais.
7. Suíte de testes do Documento 15 aprovada por fase antes do gate correspondente.
