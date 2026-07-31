# Documento 17 — Decisões que a Diretoria Precisa Aprovar Antes do Desenvolvimento

Cada item traz recomendação da arquitetura quando existente. Itens **[BLOQUEANTE]**
impedem o início da Fase 1; os demais podem ser decididos até o gate indicado.

## A. Governança e negócio

| # | Decisão | Opções | Recomendação | Prazo |
|---|---------|--------|--------------|-------|
| A1 **[BLOQUEANTE]** | Modelo de governança da rede: fundação própria, consórcio ou empresa operadora | Fundação/associação; consórcio contratual; SPE | Entidade com estatuto que permita adesão de orgs independentes (viabiliza OrgFundacao crível) | Fase 0 |
| A2 **[BLOQUEANTE]** | Modelo comercial | SaaS por cabeça/mês; licença por propriedade; taxa por certificação; misto | Misto: assinatura por cabeça + serviços de certificação | Fase 0 |
| A3 | Parceria com certificadora específica (destrava SISBOV — D1/D2) | Certificadoras habilitadas no mercado | Iniciar negociação na Fase 0; contrato até gate F4→F5 | Fase 0–4 |
| A4 | Propriedade e frigorífico parceiros do piloto | — | Carta de intenção na Fase 0 | Gate F2→F3 |
| A5 **[BLOQUEANTE]** | Orçamento e prazo-alvo Fases 0–3 | — | Conforme equipe do Doc 16 | Fase 0 |
| A6 | Postura pública sobre descentralização | Transparência total (recomendada) vs. marketing "blockchain" | Comunicar estágio real (Doc 10 §2) — risco reputacional alto na alternativa | Fase 0 |
| A7 | Nome definitivo do produto e marca | TraceAgro é provisório | Verificação de marca INPI antes do piloto | Gate F3 |

## B. Jurídico e privacidade

| # | Decisão | Recomendação | Prazo |
|---|---------|--------------|-------|
| B1 **[BLOQUEANTE]** | Designação do DPO/Encarregado e responsável jurídico LGPD | Antes de tratar dado real (piloto) | Fase 0 |
| B2 **[BLOQUEANTE]** | Aprovação formal da política on-chain/off-chain (Doc 11) — **irreversível após produção** | Aprovar como está, com parecer jurídico sobre natureza das âncoras | Fase 0 |
| B3 | Matriz de responsabilidade jurídica nas integrações oficiais (quem responde por registro incorreto — Doc 12 I8) | Contrato com certificadora define | Gate F5 |
| B4 | Termos de uso, DPA modelo e aviso de privacidade por persona | Minutas na Fase 0; vigentes no piloto | Gate F3 |

## C. Técnica (ratificação das DECISÕES da arquitetura)

A diretoria ratifica (ou veta com justificativa) as decisões já fundamentadas:

| # | Decisão tomada na documentação | Onde |
|---|-------------------------------|------|
| C1 | Backend NestJS sobre adapter Fastify | Doc 9 §1 |
| C2 | Chaincode em Go | Doc 10 §5 |
| C3 | Drift/SQLite + SQLCipher no app; Android primeiro | Doc 8 §2; Doc 2 §9 |
| C4 | Usuários finais sem identidade Fabric individual (autoria via assinatura de dispositivo) | Doc 10 §4 |
| C5 | Event como fonte de verdade; projeções regeráveis | Doc 4 §3 |
| C6 | Piloto em VMs/Compose; K8s na produção | Doc 14 §1 |
| C7 | Redis+BullMQ até Fase 5; reavaliação de Kafka/NATS | Doc 14 §2 |
| C8 | Captura offline nunca bloqueada por expiração de credencial (validação vinculante no servidor) | Doc 8 §8 |
| C9 | JCS (RFC 8785) como canonicalização de hash | Doc 11 §4 |

## D. Questões em aberto consolidadas (não bloqueiam início, têm dono e prazo)

| # | Questão | Onde | Prazo sugerido |
|---|---------|------|----------------|
| D1 | Janela de correção pelo autor original sem aprovação (proposta 72h) | Doc 6 | Fim do piloto (F3) |
| D2 | Hospedagem dos peers das orgs não-fundação (infra própria vs. hospedagem segregada) | Doc 10 §11 | Início da F4 |
| D3 | Metas comerciais quantitativas (fazendas, receita) | Doc 1 §10 | Fase 0 |
| D4 | Protocolo de certificação de referência do piloto | Doc 2 §10 | Gate F2→F3 |
| D5 | Arquivamento frio de partições de eventos antigos | Doc 4 §7 | Fase 7 |
| D6 | Estratégia iOS | Doc 1 §7 | Pós-piloto |

---

**Encaminhamento sugerido**: reunião de diretoria única para A1, A2, A5, B1, B2
(bloqueantes), com ratificação em bloco da seção C; demais itens delegados aos
donos com os prazos acima.
