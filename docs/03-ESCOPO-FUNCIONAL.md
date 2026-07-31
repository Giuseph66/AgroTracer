# Documento 3 — Escopo Funcional

Estrutura padrão por módulo: **Objetivo · Atores · Entidades · Telas · Operações ·
Permissões · Regras-chave · Eventos gerados · Integrações · Erros esperados ·
Critérios de aceite**. Permissões detalhadas no Documento 7; regras completas no
Documento 6; payloads no Documento 5.

Convenção de erros: códigos `ERR-<MÓDULO>-<NNN>`, mapeados para HTTP no Documento 9.

---

## 1. Identidade e Acesso

- **Objetivo**: autenticar usuários (OIDC), gerir sessões, MFA, credenciais offline.
- **Atores**: todos os usuários; Admin org; Admin plataforma.
- **Entidades**: User, Role, Permission, Device (vínculo).
- **Telas**: login, MFA, recuperação, primeiro acesso, PIN offline.
- **Operações**: login OIDC; refresh; logout; enrolamento MFA; definição de PIN offline; troca de senha.
- **Permissões**: autogestão do próprio perfil; Admin org gere usuários da org.
- **Regras**: token offline com validade máxima parametrizada (padrão 72h); PIN local só desbloqueia dados do próprio usuário; revogação propaga na próxima sincronização.
- **Eventos**: nenhum de domínio; AuditLog (LOGIN, LOGIN_FAILED, MFA_ENROLLED, TOKEN_REVOKED).
- **Integrações**: Keycloak (OIDC).
- **Erros**: `ERR-AUTH-001` credencial inválida; `ERR-AUTH-002` MFA requerido; `ERR-AUTH-003` usuário revogado; `ERR-AUTH-004` token offline expirado.
- **Aceite**: login offline com PIN após 1º login online; revogação bloqueia sincronização com erro claro; MFA obrigatório para perfis administrativos.

## 2. Organizações

- **Objetivo**: cadastrar e gerir organizações participantes (produtora, certificadora, frigorífico, transportadora, auditoria).
- **Atores**: Admin plataforma (cria), Admin org (gere a própria).
- **Entidades**: Organization, User, Property (vínculo).
- **Telas**: lista, detalhe, cadastro, membros, dispositivos da org.
- **Operações**: criar org; ativar/suspender; convidar usuários; definir papéis; vincular MSP Fabric.
- **Regras**: org suspensa não sincroniza eventos novos; CNPJ único; tipo de org restringe papéis atribuíveis.
- **Eventos**: AuditLog (ORG_CREATED, ORG_SUSPENDED, MEMBER_ADDED...).
- **Integrações**: Fabric CA (emissão de identidade MSP na Fase 4).
- **Erros**: `ERR-ORG-001` CNPJ duplicado; `ERR-ORG-002` org suspensa.
- **Aceite**: usuário de org suspensa recebe rejeição em qualquer escrita; trilha completa de mudanças de membros.

## 3. Propriedades

- **Objetivo**: cadastrar propriedades rurais com geometria (PostGIS), inscrição estadual, código de exploração.
- **Atores**: Admin org, Produtor.
- **Entidades**: Property, Organization, Paddock, Corral.
- **Telas**: lista, detalhe com mapa, cadastro, edição de perímetro.
- **Operações**: CRUD de propriedade (edição gera versão, não sobrescreve geometria histórica).
- **Regras**: propriedade pertence a exatamente 1 organização; perímetro é polígono válido; coordenadas precisas classificadas como sensíveis (Doc 11/13).
- **Eventos**: AuditLog; `PROPERTY_ENTRY`/`PROPERTY_EXIT` são do módulo Movimentações.
- **Erros**: `ERR-PROP-001` geometria inválida; `ERR-PROP-002` inscrição duplicada na UF.
- **Aceite**: mapa renderiza perímetro e piquetes; histórico de versões de geometria consultável.

## 4. Lotes, Currais e Piquetes

- **Objetivo**: estruturar a propriedade em áreas (piquetes, currais) e agrupamentos de animais (lotes de manejo).
- **Atores**: Produtor, Técnico, Operador.
- **Entidades**: Paddock, Corral, HerdLot, Animal (associação por evento).
- **Telas**: mapa de piquetes, lista de lotes, composição do lote, movimentação lote↔piquete.
- **Operações**: criar/encerrar lote; mover animais entre lotes (`LOT_CHANGE`); alocar lote a piquete (`PADDOCK_CHANGE`); registrar dieta (`DIET_CHANGE`).
- **Regras**: animal pertence a no máximo 1 lote ativo; composição do lote é derivada de eventos; lote encerrado não recebe animais.
- **Eventos**: `LOT_CHANGE`, `PADDOCK_CHANGE`, `DIET_CHANGE`.
- **Erros**: `ERR-LOT-001` lote encerrado; `ERR-LOT-002` animal com ciclo encerrado.
- **Aceite**: mover 200 animais de lote em operação única offline; histórico de lotação por piquete consultável por período.

## 5. Animais

- **Objetivo**: registro individual do bovino e visão consolidada (ficha do animal).
- **Atores**: Operador, Técnico, Produtor, Veterinário (leitura ampliada).
- **Entidades**: Animal, AnimalIdentifier, Event (histórico).
- **Telas**: busca (RFID/visual/oficial), ficha do animal (linha do tempo), cadastro, genealogia.
- **Operações**: `REGISTER_ANIMAL` (nascimento ou entrada); `CORRECT_REGISTRATION`; consulta de histórico; derivações (peso atual, GMD, idade, status).
- **Regras**: R1, R9–R14 do Documento 6; sexo, raça e data de nascimento validados por domínio; nascimento vincula mãe via `OFFSPRING_LINK`.
- **Eventos**: `REGISTER_ANIMAL`, `CORRECT_REGISTRATION`, `OFFSPRING_LINK`, `RECORD_CLOSED`.
- **Erros**: `ERR-ANI-001` identificador em uso; `ERR-ANI-002` animal encerrado; `ERR-ANI-003` data de nascimento futura.
- **Aceite**: ficha exibe linha do tempo completa com origem (dispositivo/usuário) de cada evento; busca por qualquer dos 4 identificadores.

## 6. Identificadores Físicos

- **Objetivo**: gerir vínculo animal ↔ brinco RFID/visual/oficial, com histórico integral.
- **Atores**: Operador (executa), Técnico/Produtor (aprova reidentificação).
- **Entidades**: AnimalIdentifier, Animal.
- **Telas**: leitura/associação de brinco, troca de brinco (fluxo com motivo), histórico de identificadores.
- **Operações**: `LINK_IDENTIFIER`; `REIDENTIFICATION` (perda, dano, recall); inativação lógica.
- **Regras**: R3–R6 do Documento 6; RFID validado por formato ISO (15 dígitos, país+código); motivo obrigatório em troca.
- **Eventos**: `LINK_IDENTIFIER`, `REIDENTIFICATION`.
- **Integrações**: leitor RFID (módulo 17).
- **Erros**: `ERR-IDF-001` RFID ativo em outro animal; `ERR-IDF-002` formato inválido; `ERR-IDF-003` troca sem motivo.
- **Aceite**: tentar associar RFID ativo a 2º animal falha offline e online; histórico mostra todos os identificadores com vigências.

## 7. Manejo Zootécnico

- **Objetivo**: registrar práticas de manejo: escore corporal, dieta, apartação, castração, desmama.
- **Atores**: Técnico, Operador.
- **Entidades**: Event (payloads específicos), HerdLot.
- **Telas**: manejo individual, manejo em lote, escore corporal com escala configurável.
- **Operações**: `BODY_SCORE`, `DIET_CHANGE`, manejos genéricos tipados.
- **Regras**: escore na escala do programa (1–5 ou 1–9, parametrizado); manejo em lote gera 1 evento por animal com `batchId` comum.
- **Eventos**: `BODY_SCORE`, `DIET_CHANGE`, `LOT_CHANGE`.
- **Erros**: `ERR-MAN-001` escore fora da escala.
- **Aceite**: manejo aplicado a lote de 300 animais offline em ≤2min de operação.

## 8. Pesagens

- **Objetivo**: capturar peso com origem rastreável (balança integrada, manual), calcular GMD.
- **Atores**: Operador.
- **Entidades**: WeightRecord, Event, Scale, Device.
- **Telas**: fluxo de brete (RFID→peso→confirma), pesagem manual, histórico/curva de peso.
- **Operações**: `WEIGHING`; correção via `CORRECTED`.
- **Regras**: R9, R11 do Documento 6; peso plausível (faixa por categoria — bezerro 15–120kg, adulto 120–1.500kg, parametrizável); flag `weightSource: SCALE|MANUAL`; variação >30% vs. última pesagem gera alerta, não bloqueio.
- **Eventos**: `WEIGHING`.
- **Integrações**: balança (módulo 17).
- **Erros**: `ERR-PES-001` peso fora de faixa; `ERR-PES-002` balança sem leitura estável.
- **Aceite**: fluxo de brete ≤5s/animal; GMD calculado entre pesagens válidas ignorando corrigidas.

## 9. Sanidade

- **Objetivo**: vacinações, exames, diagnósticos, tratamentos, carência, quarentena.
- **Atores**: Veterinário (atos privativos), Técnico (conforme delegação), Operador (aplicação supervisionada).
- **Entidades**: HealthRecord, Vaccination, Treatment, Examination, Diagnosis, WithdrawalPeriod, Quarantine.
- **Telas**: aplicação individual/lote, protocolo sanitário, carências ativas, quarentenas.
- **Operações**: `VACCINATION`, `EXAM`, `DIAGNOSIS`, `TREATMENT`, `WITHDRAWAL_PERIOD`, `QUARANTINE`, `RELEASE`.
- **Regras**: R12, R17, R18 do Documento 6; produto veterinário referenciado por catálogo com carência padrão; carência bloqueia `SLAUGHTER` e alerta em `SHIPMENT_DISPATCHED` para abate.
- **Eventos**: os sete acima; `DOCUMENT_ATTACHED` para receitas/laudos.
- **Erros**: `ERR-SAN-001` ator sem credencial profissional exigida; `ERR-SAN-002` animal em quarentena para operação bloqueada; `ERR-SAN-003` produto não catalogado.
- **Aceite**: vacinação de lote gera carência automática por produto; tentativa de expedição para abate dentro de carência exige justificativa ou é bloqueada conforme parametrização do programa.

## 10. Reprodução

- **Objetivo**: cobertura, inseminação, diagnóstico de gestação, parto, vínculo de cria.
- **Atores**: Técnico, Veterinário, Operador.
- **Entidades**: ReproductiveEvent, Animal.
- **Telas**: estação de monta, IATF em lote, diagnóstico, partos.
- **Operações**: `BREEDING`, `INSEMINATION`, `PREGNANCY_CHECK`, `CALVING`, `OFFSPRING_LINK`.
- **Regras**: fêmea apta (idade/status derivados); `CALVING` pode criar novo Animal encadeando `REGISTER_ANIMAL` + `OFFSPRING_LINK`; sêmen/touro referenciado por identificador próprio.
- **Erros**: `ERR-REP-001` sexo incompatível; `ERR-REP-002` gestação sem evento reprodutivo prévio (alerta, não bloqueio).
- **Aceite**: parto offline cria bezerro com vínculo materno; genealogia navegável na ficha.

## 11. Movimentações

- **Objetivo**: movimentar animais entre propriedades com expedição, trânsito e recebimento.
- **Atores**: Produtor/Operador (expede), Transportador (custódia), Destinatário (recebe).
- **Entidades**: Movement, Shipment, Custody, GTARecord.
- **Telas**: montar embarque (seleção por leitura RFID), conferência de recebimento, divergências.
- **Operações**: `PROPERTY_EXIT`, `SHIPMENT_DISPATCHED`, `CUSTODY_TRANSFERRED`, `SHIPMENT_RECEIVED`, `PROPERTY_ENTRY`.
- **Regras**: R15, R16 do Documento 6; embarque referencia GTA quando exigível; recebimento confere lista esperada × lida; faltante/excedente gera `SyncConflict`-like ocorrência de divergência.
- **Erros**: `ERR-MOV-001` animal em quarentena; `ERR-MOV-002` recebimento sem expedição correspondente; `ERR-MOV-003` divergência de contagem.
- **Aceite**: embarque de 100 animais com conferência por leitura; divergência de 1 animal gera ocorrência com fluxo de resolução documentado.

## 12. GTA

- **Objetivo**: registrar e associar GTAs a embarques. **Não emite GTA.**
- **Atores**: Produtor, Transportador, Frigorífico, Admin org.
- **Entidades**: GTARecord, Document, Shipment.
- **Telas**: registro de GTA (upload + metadados), associação a embarque, estado de reconciliação.
- **Operações**: `GTA_REGISTERED`; upload do documento; reconciliação via adaptador (Doc 12).
- **Regras**: número + UF + série únicos; GTA associada a exatamente 1 embarque ativo; documento com hash ancorado.
- **Erros**: `ERR-GTA-001` GTA duplicada; `ERR-GTA-002` quantidade GTA ≠ quantidade embarque (ocorrência).
- **Aceite**: embarque interestadual sem GTA associada gera alerta bloqueante parametrizável por UF.

## 13. Custódia e Propriedade

- **Objetivo**: distinguir e registrar posse física (custódia) e propriedade jurídica.
- **Atores**: Produtor, Transportador, Frigorífico, Comprador.
- **Entidades**: Custody, Ownership, Animal.
- **Operações**: `CUSTODY_TRANSFERRED` (unilateral com aceite implícito no recebimento), `OWNERSHIP_TRANSFERRED` (bilateral: oferta + aceite).
- **Regras**: propriedade só transfere com aceite da parte compradora registrado; custódia segue o fluxo físico; ambos os históricos completos.
- **Erros**: `ERR-CUS-001` transferência de propriedade sem aceite; `ERR-CUS-002` cedente não é proprietário atual.
- **Aceite**: venda de lote exige aceite do comprador na plataforma; histórico exibe cadeia completa de proprietários e custódios.

## 14. Documentos

- **Objetivo**: armazenar documentos (laudos, receitas, notas, GTA digitalizada) com versão, hash e controle de acesso.
- **Atores**: todos com permissão de anexar; Auditor (leitura).
- **Entidades**: Document, BlockchainAnchor.
- **Operações**: upload (multipart → MinIO/S3); `DOCUMENT_ATTACHED`; nova versão; download com URL assinada.
- **Regras**: R19–R21 do Documento 6; SHA-256 calculado no servidor e conferido com o declarado; tipos MIME permitidos por categoria; retenção por classe documental.
- **Erros**: `ERR-DOC-001` hash divergente; `ERR-DOC-002` MIME não permitido; `ERR-DOC-003` tamanho excedido.
- **Aceite**: nova versão preserva anterior; verificação hash on-chain × objeto retorna VÁLIDO/INVÁLIDO.

## 15. Certificação

- **Objetivo**: certificadora avalia animais/lotes contra protocolo e emite parecer com endosso.
- **Atores**: Certificador; Produtor (solicita); Auditor (consulta).
- **Entidades**: Certificate, Document, Event.
- **Operações**: solicitar certificação; avaliar dossiê; `CERTIFIED` / `REJECTED`; revogar certificado.
- **Regras**: `CERTIFIED` exige endosso Fabric de OrgCertificadora + OrgFundacao; certificado tem vigência e escopo (animal, lote, propriedade); rejeição exige motivo.
- **Erros**: `ERR-CER-001` dossiê incompleto; `ERR-CER-002` certificador da mesma org do produtor (conflito de interesse).
- **Aceite**: certificado consultável publicamente por código com prova on-chain; revogação propaga ao QR público.

## 16. Sincronização Offline

- **Objetivo**: transportar eventos do app à API com idempotência, ordem e resolução de conflitos. Especificação completa no Documento 8.
- **Atores**: app (automático), usuário (resolução de conflitos), Admin org.
- **Entidades**: SyncJob, SyncConflict, Event.
- **Operações**: push em lote; pull incremental (dados mestre, animais da propriedade); consulta de estado por evento.
- **Erros**: ver taxonomia no Documento 8, seção 7.
- **Aceite**: ver Documento 8, seção 12 e Documento 15.

## 17. Dispositivos

- **Objetivo**: registrar, atestar e revogar dispositivos móveis, leitores e balanças.
- **Atores**: Admin org; Operador (pareamento local).
- **Entidades**: Device, Reader, Scale, User (vínculo).
- **Operações**: enrolamento do dispositivo (gera par de chaves no hardware seguro); pareamento de leitor/balança; revogação; bloqueio remoto.
- **Regras**: evento sem `deviceId` registrado é rejeitado; chave privada nunca sai do dispositivo (Android Keystore); revogação invalida sincronizações futuras, não eventos passados aceitos.
- **Erros**: `ERR-DEV-001` dispositivo revogado; `ERR-DEV-002` assinatura não corresponde à chave registrada.
- **Aceite**: dispositivo perdido revogado no painel deixa de sincronizar imediatamente; eventos pendentes nele podem ser reemitidos por outro dispositivo com nova autoria.

## 18. Blockchain

- **Objetivo**: ancorar eventos, expor provas, gerir estado de âncora. Especificação no Documento 10.
- **Atores**: serviço anchor-worker; Auditor; consulta pública (prova resumida).
- **Entidades**: BlockchainAnchor, Event.
- **Operações**: ancorar (assíncrono); consultar prova; verificar hash; reancorar após falha.
- **Erros**: `ERR-BLK-001` endosso insuficiente; `ERR-BLK-002` rede indisponível (retry).
- **Aceite**: evento aceito sem âncora após SLA gera alerta; prova retorna TxID, bloco, timestamp e organizações endossantes.

## 19. Auditoria

- **Objetivo**: trilha imutável de ações administrativas e acesso de leitura a todo o histórico para auditores.
- **Atores**: Auditor, Admin plataforma.
- **Entidades**: AuditLog.
- **Operações**: consulta com filtros (ator, org, período, tipo); exportação de dossiê (animal/lote/propriedade) com hashes verificáveis.
- **Regras**: R35 do Documento 6; AuditLog é append-only, sem endpoint de alteração; exportação registra quem exportou.
- **Aceite**: dossiê exportado permite verificação offline de todos os hashes contra as âncoras.

## 20. Notificações

- **Objetivo**: alertar usuários sobre divergências, falhas, carências, pendências de aceite.
- **Atores**: sistema (emite), usuários (recebem/configuram).
- **Operações**: push (FCM), e-mail, central de notificações no app; preferências por tipo.
- **Regras**: notificações críticas (divergência de recebimento, falha de integração) não são desativáveis para Admin org.
- **Aceite**: divergência de recebimento notifica expedidor e recebedor em ≤1min após sincronização.

## 21. Relatórios

- **Objetivo**: inventário, curva de peso/GMD, calendário sanitário, movimentações, dossiê de auditoria.
- **Atores**: Produtor, Técnico, Veterinário, Certificador, Auditor.
- **Operações**: geração assíncrona (fila), download em PDF/CSV, agendamento.
- **Regras**: relatório é sempre derivado de eventos; carimbado com data de geração e filtros; nunca fonte de verdade.
- **Aceite**: inventário de 10.000 animais gerado em ≤60s; dossiê de animal inclui trilha de âncoras.

## 22. Integração SISBOV

- **Objetivo**: reconciliar registros internos com a base oficial via `sisbov-adapter`. Especificação no Documento 12.
- **DEPENDÊNCIA EXTERNA**: credenciais e certificadora habilitada (D1/D2).
- **Aceite**: ver Documento 12, seção 8.

## 23. Integração com Sistemas Estaduais

- **Objetivo**: adaptadores por UF para GTA eletrônica e trânsito. Especificação no Documento 12.
- **DEPENDÊNCIA EXTERNA**: cada UF tem sistema, protocolo e acordo próprios.
- **Aceite**: arquitetura comporta novo adaptador de UF sem alteração no núcleo.

## 24. Frigorífico

- **Objetivo**: recepção de embarques, confirmação de identidade, abate, criação de carcaça.
- **Atores**: Operador de frigorífico, Veterinário oficial (registro de inspeção como documento).
- **Entidades**: Shipment, Animal, Carcass, Event.
- **Operações**: `SHIPMENT_RECEIVED`; `SLAUGHTER`; `CARCASS_CREATED` (com peso de carcaça, tipificação); anexo de documentos de inspeção.
- **Regras**: R32, R33 do Documento 6; abate bloqueado se carência ativa (parametrizável: bloqueio ou ocorrência grave); carcaça referencia exatamente 1 animal.
- **Erros**: `ERR-FRI-001` animal não recebido neste frigorífico; `ERR-FRI-002` carência ativa.
- **Aceite**: rendimento de carcaça calculado (peso carcaça / último peso vivo); animal encerrado após `SLAUGHTER`.

## 25. Rastreabilidade Pós-Abate

- **Objetivo**: manter vínculo carcaça → lote de processamento → lote de corte, com balanço de massa.
- **Atores**: Operador de frigorífico.
- **Entidades**: Carcass, ProcessingLot, CutLot.
- **Operações**: `CUT_LOT_CREATED`; composição de lote de processamento (n carcaças → m lotes de corte).
- **Regras**: R34 do Documento 6; soma dos pesos de saída ≤ soma das entradas + tolerância parametrizada; lote de corte lista todas as carcaças de origem.
- **Erros**: `ERR-POS-001` balanço de massa violado; `ERR-POS-002` carcaça inexistente.
- **Aceite**: dado um lote de corte, sistema retorna todos os animais de origem com trilhas completas.

## 26. Verificação Pública por QR

- **Objetivo**: consumidor/comprador escaneia QR (GS1 Digital Link) e vê trilha resumida + prova de integridade.
- **Atores**: público anônimo.
- **Entidades**: CutLot, Certificate, BlockchainAnchor (visões públicas).
- **Operações**: resolução do link; página pública com origem (município/UF, não coordenadas), certificações vigentes, datas-chave, verificação de hash.
- **Regras**: nenhum dado pessoal, preço ou documento integral; rate limit agressivo; conteúdo cacheável.
- **Erros**: `ERR-QRP-001` código inexistente (página neutra, sem enumeração).
- **Aceite**: página em ≤3s em 4G; tentativa de enumeração de códigos sequenciais bloqueada (códigos não sequenciais + rate limit).
