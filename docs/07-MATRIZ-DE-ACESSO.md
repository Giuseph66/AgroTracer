# Documento 7 — Matriz de Acesso (RBAC + ABAC)

## 1. Modelo de autorização

**DECISÃO** — RBAC define o *teto* de capacidades por papel; ABAC restringe o
*alcance* por atributos de contexto. Uma ação é permitida somente se: (a) o papel
concede a permissão E (b) todas as condições de atributo são satisfeitas E (c) a
avaliação vale para o instante `occurredAt` do evento (R28).

### Atributos ABAC avaliados

| Atributo | Fonte | Exemplos de condição |
|----------|-------|----------------------|
| `user.organizationId` | Vínculo vigente | Evento na org do usuário |
| `user.propertyBindings[]` | Vínculo usuário↔propriedade com vigência | Operador só age em propriedades vinculadas |
| `user.professionalCredential` | Cadastro validado (CRMV etc.) | Atos privativos veterinários (R17) |
| `animal.currentPropertyId` / custódia | Projeção | Só age sobre animal sob custódia/propriedade da sua org |
| `animal.lifecycleStatus` | Projeção | Ciclo encerrado limita tipos (R14) |
| `event.eventType` | Requisição | Mapa papel×tipo abaixo |
| `context.channel` | Sessão | Ações administrativas só via web autenticada com MFA |
| `delegation` | Parametrização por programa | TE aplica vacina sob protocolo assinado por VE |

## 2. Papéis (roles)

| Código | Papel | Escopo típico |
|--------|-------|---------------|
| OPER | Operador de curral | Propriedades vinculadas da própria org |
| PROD | Produtor / gestor | Todas as propriedades da própria org |
| TECN | Técnico agropecuário | Propriedades vinculadas (pode ser multi-org com vínculos distintos) |
| VETE | Veterinário | Idem TECN + atos privativos |
| CERT | Certificador | Escopos sob avaliação (acesso de leitura ampliado temporário) |
| TRAN | Transportador | Shipments sob sua custódia |
| FRIG | Operador de frigorífico | Shipments destinados + pós-abate da sua planta |
| AUDI | Auditor | Leitura ampla no escopo do mandato; zero escrita de domínio |
| ADMO | Administrador organizacional | Sua organização |
| ADMP | Administrador da plataforma (fundação) | Plataforma; **sem** escrita de eventos de domínio |
| PUBL | Consulta pública | Apenas visões públicas (QR, certificados) |

## 3. Matriz papel × funcionalidade

Legenda: ✔ permitido · A com aprovação/condição ABAC anotada · ✖ negado.
Colunas: **V** visualizar · **C** criar · **E** editar antes da sync (rascunho local) ·
**X** corrigir após sync (`CORRECTED`) · **Ap** aprovar · **Rj** rejeitar ·
**Dc** anexar documento · **Ex** exportar · **S** consultar dados sensíveis ·
**B** consultar prova blockchain.

| Funcionalidade | OPER | PROD | TECN | VETE | CERT | TRAN | FRIG | AUDI | ADMO | ADMP | PUBL |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Animais (cadastro/ficha) | V C E | V C E X Ex | V C E X | V | V(escopo) | ✖ | V(recebidos) | V Ex | V | V | ✖ |
| Identificadores / LINK | V C E | V C X Ap | V C X Ap | V | V | ✖ | V | V | V | V | ✖ |
| REIDENTIFICATION | C(A: aprovação TECN/PROD) | ✔+Ap | ✔+Ap | V | V | ✖ | ✖ | V | V | V | ✖ |
| Pesagens | V C E | V X Ex | V C E X | V | V | ✖ | V | V Ex | V | V | ✖ |
| Manejo (lote/piquete/dieta/escore) | V C E | V C X | V C E X | V C | V | ✖ | ✖ | V | V | V | ✖ |
| Sanidade — atos privativos (DIAGNOSIS, TREATMENT, QUARANTINE, RELEASE) | ✖ | V | A(delegação R17) | V C E X | V | ✖ | ✖ | V | V | V | ✖ |
| Sanidade — aplicação (VACCINATION sob protocolo) | A(delegação) | V | ✔ C E | ✔ C E X | V | ✖ | ✖ | V | V | V | ✖ |
| Reprodução | V C E | V C X | V C E X | V C E X | V | ✖ | ✖ | V | V | V | ✖ |
| Movimentações — expedir | C E(A: vínculo) | ✔ C X | ✔ C | V | V | V | ✖ | V | V | V | ✖ |
| Movimentações — receber | C(destino) | ✔(destino) | ✔(destino) | V | V | ✖ | ✔(destino) | V | V | V | ✖ |
| Custódia | V | ✔ C | V | V | V | ✔ C(própria) | ✔ C | V | V | V | ✖ |
| Transferência de propriedade | ✖ | ✔ C Ap Rj | ✖ | ✖ | V | ✖ | ✔ Ap(compra) | V | V | V | ✖ |
| GTA (registrar/associar) | V C | ✔ C Dc | ✔ C Dc | V | V | ✔ C Dc | ✔ C Dc | V | V | V | ✖ |
| Documentos | V Dc | V Dc Ex | V Dc | V Dc | V Dc(escopo) | Dc(shipment) | V Dc | V Ex | V | V(metadados) | ✖ |
| Certificação | ✖ | V(solicitar) | ✖ | ✖ | V C Ap Rj X | ✖ | V | V Ex | V | V | V(pública) |
| Frigorífico (SLAUGHTER, carcaça, cortes) | ✖ | V(seus animais) | ✖ | V | V | ✖ | ✔ C X | V | V | V | ✖ |
| Sincronização / conflitos | V(própr.) | ✔ Ap Rj | ✔ Ap Rj | V | ✖ | V(própr.) | ✔(própr.) | V | ✔ Ap Rj | V | ✖ |
| Dispositivos (enrolar/revogar) | V(próprio) | ✔(org) | V | V | ✖ | V(próprio) | ✔(planta) | V | ✔ C Rj | ✔ | ✖ |
| Usuários e papéis | ✖ | V(org) | ✖ | ✖ | ✖ | ✖ | ✖ | V | ✔ C E(org) | ✔ C E | ✖ |
| Organizações | ✖ | V(própria) | ✖ | ✖ | ✖ | ✖ | ✖ | V | E(própria) | ✔ C E | ✖ |
| Parametrizações (R18, faixas) | ✖ | V | V | V | V | ✖ | V | V | A(escopo org) | ✔ | ✖ |
| Auditoria (AuditLog) | ✖ | V(org) | ✖ | ✖ | ✖ | ✖ | ✖ | ✔ Ex | V(org) | ✔ | ✖ |
| Relatórios | V(própr.) | ✔ Ex | ✔ Ex | ✔ Ex | ✔ Ex(escopo) | ✖ | ✔ Ex(planta) | ✔ Ex | ✔ Ex | ✔ | ✖ |
| Dados sensíveis (S): CPF, coordenadas precisas, docs P3 | ✖ | S(própria org) | ✖ | S(clínico) | S(escopo de certificação) | ✖ | ✖ | S(mandato) | S(org) | S(suporte, auditado) | ✖ |
| Prova blockchain (B) | B | B | B | B | B | B | B | B | B | B | B(resumida) |
| Consulta pública QR | — | — | — | — | — | — | — | — | — | — | ✔ |

## 4. Regras transversais de acesso

1. **ADMP não escreve eventos de domínio.** Separação operação × plataforma; suporte
   atua por impersonação auditada com consentimento (AuditLog obrigatório).
2. **AUDI nunca escreve** nada além de anotações de auditoria próprias e exportações.
3. **Correção (X)**: autor original dentro da janela (QUESTÃO EM ABERTO no Doc 6);
   fora dela, papel de aprovação da org (PROD/ADMO) ou superior.
4. **Aprovação (Ap) de REIDENTIFICATION**: papel distinto do executor quando o
   executor é OPER (segregação de funções).
5. **CERT acesso temporário**: leitura ampliada ao escopo somente entre aceite da
   solicitação e emissão do parecer; expira automaticamente.
6. **Multi-org (TECN/VETE)**: vínculos simultâneos permitidos; cada evento carrega a
   org do vínculo usado; dados de uma org jamais visíveis via vínculo de outra.
7. **Escrita administrativa exige MFA** e canal web; app de campo não expõe
   administração.
8. **Toda decisão de negação** retorna código estável (`ERR-AUTH-*`, 403) e é
   registrada quando repetida (possível tentativa de abuso).

## 5. Implementação

- Permissões atômicas `module.action` (ex.: `health.treatment.create`,
  `shipment.receive`, `device.revoke`); papéis são conjuntos versionados.
- Vínculos com vigência (`validFrom/validTo`) para avaliação temporal (R28):
  tabela `user_role_binding` e `user_property_binding` nunca sofrem delete, apenas
  encerramento de vigência.
- Motor de política centralizado no backend (guard NestJS + serviço de política);
  o app espelha as regras para UX offline, mas **a decisão vinculante é sempre do
  servidor** na sincronização.
- Cache local de política no app com a mesma vigência do token offline (Doc 8 §8).
