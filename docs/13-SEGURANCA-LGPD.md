# Documento 13 — Segurança, Privacidade e LGPD

## 1. Papéis LGPD

| Papel | Quem | Observação |
|-------|------|------------|
| Controlador | Cada organização participante, quanto aos dados que decide tratar (seus usuários, seus produtores PF, seus documentos) | Definido em contrato de adesão |
| Operador | Entidade gestora da plataforma (fundação), tratando em nome dos controladores | Contrato de tratamento (DPA) obrigatório no onboarding |
| Suboperadores | Provedores de nuvem, storage, e-mail, push | Listados publicamente; mudança comunicada com antecedência |
| Encarregado (DPO) | **QUESTÃO EM ABERTO** — designação pela diretoria (Doc 17) | Canal de titular publicado |

**RISCO** — a rede Fabric multi-organização implica que âncoras (hashes, IDs
controlados) replicam entre orgs. Mitigado pela fronteira do Doc 11: âncoras não
contêm dados pessoais. Parecer jurídico formal sobre a natureza das âncoras é
recomendado antes da produção.

## 2. Inventário de dados pessoais e bases legais

| Dado | Titular | Base legal | Finalidade | Retenção |
|------|---------|-----------|------------|----------|
| Nome, e-mail, telefone de usuários | Usuários | Execução de contrato | Autenticação, operação | Conta ativa + 5 anos (defesa em processos) |
| Credencial profissional (CRMV etc.) | Veterinários/técnicos | Execução de contrato + obrigação legal (atos privativos) | Validação R17 | Idem |
| CPF/CNPJ de produtores PF | Produtores | Execução de contrato; obrigação legal quando exigido por norma sanitária | Titularidade, documentos fiscais | Prazos legais fiscais/sanitários |
| Coordenadas precisas de propriedade | Produtores | Legítimo interesse (operação) com salvaguardas | Mapa, manejo | Enquanto ativa; acesso restrito P3 |
| Logs de acesso e AuditLog | Usuários | Obrigação legal (Marco Civil) + legítimo interesse (segurança) | Segurança, auditoria | Logs técnicos 13 meses; AuditLog permanente (pseudonimizável) |
| Documentos (receitas, laudos com nomes) | Diversos | Execução de contrato/obrigação legal | Dossiê sanitário | Por classe documental (mín. legal aplicável; padrão 5 anos após encerramento do animal) |

Princípios aplicados: **minimização** (só o necessário à finalidade; campos livres
desencorajados e classificados P3 por padrão), **transparência** (aviso de
privacidade por persona), **necessidade** (QR público expõe apenas P0).

## 3. Direitos do titular

| Direito | Implementação |
|---------|---------------|
| Acesso/portabilidade | Exportação dos dados do titular (JSON/PDF) pelo ADMO ou canal do DPO, prazo 15 dias |
| Correção | Dados cadastrais: edição auditada. Eventos: correção via `CORRECTED` (R8) — o original persiste por obrigação de trilha |
| Exclusão | **Onde juridicamente possível**: conta e dados cadastrais anonimizados/excluídos após prazos legais. Eventos históricos e AuditLog: pseudonimização do vínculo pessoa↔registro (substituição do actorId visível por identificador irrecuperável), preservando a trilha institucional. On-chain: nada a excluir por desenho (Doc 11) |
| Revogação de consentimento | Aplicável apenas onde consentimento for base (marketing); operação usa contrato/obrigação legal |

## 4. Arquitetura de segurança

### 4.1 Criptografia e transporte

| Camada | Especificação |
|--------|---------------|
| TLS externo | TLS 1.2+ (preferência 1.3), HSTS, certificados automatizados |
| mTLS interno | Serviço↔serviço, serviço↔Fabric (nativo), serviço↔Postgres (cert) |
| Banco | Criptografia at-rest (volume/TDE) + colunas P3 com criptografia de aplicação (AES-256-GCM, chaves no KMS) |
| Objetos | SSE no bucket + criptografia de envelope para classes P3; URLs pré-assinadas ≤15min |
| App local | SQLCipher + Android Keystore (Doc 8 §8) |

### 4.2 Identidade e segredos

| Item | Especificação |
|------|---------------|
| OIDC | Keycloak; Authorization Code + PKCE (app), client credentials (serviços) |
| MFA | Obrigatório para ADMO, ADMP, CERT, AUDI; opcional-incentivado demais perfis |
| Rotação de chaves | Chaves de aplicação via KMS com rotação anual automática; JWT signing keys rotação trimestral com JWKS |
| KMS/HSM | KMS gerenciado desde o piloto; HSM para raiz das Fabric CAs em produção (Doc 10 §3) |
| Vault | HashiCorp Vault (ou secret manager gerenciado) para segredos de serviço; proibido segredo em variável de ambiente commitada, imagem ou repositório — verificação automática no CI (secret scanning) |
| Revogação de certificados | CRL Fabric ≤1h (Doc 10 §4); certificados de serviço com validade curta |

### 4.3 Proteção do aplicativo e antifraude

| Ameaça | Contramedida |
|--------|--------------|
| Replay de eventos | `eventId` + `deviceSequence` únicos (R22); assinatura cobre sequence; janela de aceitação; nonce de lote |
| Adulteração de payload em trânsito/repouso | Assinatura ECDSA no dispositivo verificada na API (R26) + hash ancorado |
| App adulterado | Play Integrity API na sincronização (sinal, não bloqueio absoluto — conectividade rural); atestação registrada no Device |
| Extração de chave | Chave não exportável no Keystore (hardware-backed quando disponível) |
| Fraude de dados na origem | Camadas do Doc 1 §8 + detecção: alertas de inconsistência (GMD impossível, pesagens em locais/tempos incompatíveis, reidentificações frequentes por operador) — fila de revisão, não bloqueio automático |
| Abuso de API | Rate limit, detecção de enumeração, WAF |
| Logs adulterados | AuditLog append-only sem grants de UPDATE/DELETE; logs centralizados com retenção WORM em produção |

## 5. Resposta a incidentes e continuidade

| Item | Especificação |
|------|---------------|
| Plano de resposta | Papéis definidos (comandante do incidente, comunicação, técnico); severidades S1–S4; runbooks por cenário (vazamento, ransomware, comprometimento de CA, perda de região) |
| Notificação | Incidente com dado pessoal: avaliação e comunicação à ANPD e titulares nos prazos da LGPD; modelo de comunicado pré-aprovado pelo jurídico |
| Comprometimento de CA Fabric | Runbook específico: revogação, rotação de MSP na configuração do canal, auditoria de transações do período |
| Continuidade | RPO ≤5min (WAL shipping), RTO ≤4h (produção); DR testado semestralmente (Doc 14) |
| Backup | Cifrado, região secundária, teste de restauração trimestral com evidência |
| Auditoria de segurança | Pentest anual + antes do go-live de produção; revisão de dependências (SCA) contínua no CI |
