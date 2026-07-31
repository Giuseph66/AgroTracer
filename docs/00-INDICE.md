# TraceAgro — Plataforma de Rastreabilidade Bovina e Agrícola

## Índice Geral da Documentação

| # | Documento | Arquivo | Público principal |
|---|-----------|---------|-------------------|
| 1 | Visão Executiva | `01-VISAO-EXECUTIVA.md` | Diretoria, investidores |
| 2 | PRD — Product Requirements Document | `02-PRD.md` | Produto, engenharia |
| 3 | Escopo Funcional | `03-ESCOPO-FUNCIONAL.md` | Produto, engenharia, QA |
| 4 | Modelo de Domínio | `04-MODELO-DE-DOMINIO.md` | Engenharia, DBA |
| 5 | Catálogo de Eventos | `05-CATALOGO-DE-EVENTOS.md` | Engenharia, integrações |
| 6 | Regras de Negócio | `06-REGRAS-DE-NEGOCIO.md` | Engenharia, QA, jurídico |
| 7 | Matriz de Acesso (RBAC/ABAC) | `07-MATRIZ-DE-ACESSO.md` | Engenharia, segurança |
| 8 | Arquitetura Offline-First | `08-ARQUITETURA-OFFLINE-FIRST.md` | Equipe mobile, backend |
| 9 | Especificação da API | `09-ESPECIFICACAO-API.md` | Backend, mobile, integrações |
| 10 | Arquitetura Hyperledger Fabric | `10-ARQUITETURA-FABRIC.md` | Blockchain, infraestrutura |
| 11 | Dados On-Chain e Off-Chain | `11-ON-CHAIN-OFF-CHAIN.md` | Blockchain, jurídico, segurança |
| 12 | Integração SISBOV, GTA e Sistemas Estaduais | `12-INTEGRACOES-OFICIAIS.md` | Integrações, jurídico |
| 13 | Segurança, Privacidade e LGPD | `13-SEGURANCA-LGPD.md` | Segurança, DPO, jurídico |
| 14 | Infraestrutura e DevOps | `14-INFRA-DEVOPS.md` | DevOps, SRE |
| 15 | Testes e Critérios de Aceite | `15-TESTES.md` | QA, engenharia |
| 16 | Roadmap | `16-ROADMAP.md` | Diretoria, produto |
| 17 | Decisões Pendentes da Diretoria | `17-DECISOES-DIRETORIA.md` | Diretoria |
| 18 | Estado Atual da Implementação | `18-IMPLEMENTACAO-ATUAL.md` | Engenharia, agentes |
| 19 | Backlog de Implementação | `19-BACKLOG-IMPLEMENTACAO.md` | Engenharia, agentes |

Convenções de código e design system para quem implementa: **`AGENTS.md`** na
raiz do repositório (leitura obrigatória antes dos Docs 18/19).

## Convenções usadas em toda a documentação

- **DECISÃO** — decisão arquitetural ou de produto já tomada nesta documentação, com justificativa.
- **PREMISSA** — suposição assumida como verdadeira; se cair, o item dependente deve ser revisto.
- **DEPENDÊNCIA EXTERNA** — item fora do controle do projeto (órgão público, credencial, terceiro).
- **RISCO** — ameaça identificada, com mitigação quando aplicável.
- **QUESTÃO EM ABERTO** — ponto que exige definição posterior (diretoria, jurídico ou piloto).
- **FORA DE ESCOPO** — explicitamente não contemplado nesta fase.

Identificadores seguem a **Regra Fundamental de Identificação**: `animalId` (UUID interno),
`officialAnimalId` (SISBOV/PNIB), `rfidCode`, `visualTagNumber`, `eventId`, `payloadHash`
e `blockchainTxId` são informações distintas e nunca intercambiáveis.

Todos os documentos assumem modelo **orientado a eventos**: nenhum estado corrente é
armazenado como fonte de verdade; estados são derivados do histórico de eventos.
