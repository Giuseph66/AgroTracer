# Documento 1 — Visão Executiva

## 1. Problema de negócio

1.1. A pecuária bovina brasileira opera sob pressão crescente de três frentes:
mercados importadores que exigem prova de origem (Europa/EUDR, China, cotas de
carne premium), programas nacionais de identificação individual obrigatória em
expansão (PNIB, com horizonte de obrigatoriedade progressiva), e compradores
domésticos (frigoríficos, varejo) que precisam demonstrar cadeias livres de
desmatamento e de irregularidades sanitárias.

1.2. O registro de campo hoje é feito em papel, planilhas ou sistemas isolados,
com três falhas estruturais:

- **Perda de dados na origem** — curral sem internet, anotação manual, digitação tardia.
- **Ausência de trilha confiável** — dados sobrescritos, sem histórico, sem autoria comprovável.
- **Fragmentação** — SISBOV, GTA estadual, controle interno da fazenda e frigorífico não conversam; a reconciliação é manual e cara.

1.3. O custo dessa falha é concreto: desqualificação de lotes para mercados premium,
retrabalho de certificação, fraudes de identidade animal (troca de brinco), e
incapacidade de responder a auditorias em prazo hábil.

## 2. Justificativa do projeto

2.1. Existe uma janela regulatória e comercial: o PNIB caminha para identificação
individual obrigatória, e os programas privados de certificação (carne carbono
neutro, cota Hilton, protocolos de frigoríficos) pagam prêmio por rastreabilidade
comprovável. Quem chegar com plataforma operacional, offline-first e auditável
captura esse mercado antes da comoditização.

2.2. Nenhuma solução dominante no mercado brasileiro combina, hoje:
aplicativo de campo genuinamente offline, modelo orientado a eventos imutáveis,
e camada de prova criptográfica multi-organização. As soluções existentes são
ou ERPs de fazenda (sem prova de integridade), ou pilotos de blockchain
(sem operação de campo real).

## 3. Visão do produto

> **TraceAgro é a plataforma que registra a vida completa de cada bovino como uma
> sequência de eventos assinados, verificáveis e imutáveis — do nascimento ao corte —
> funcionando no curral sem internet e provando, para qualquer parte autorizada,
> quem registrou o quê, quando e com qual dispositivo.**

3.1. O produto tem três camadas de valor:

| Camada | Entrega | Cliente que paga |
|--------|---------|------------------|
| Operação de campo | App offline-first com RFID, balança, manejo, sanidade | Produtor |
| Conformidade | Reconciliação SISBOV/GTA, dossiê de auditoria, certificação | Produtor, certificadora |
| Prova | Âncora blockchain multi-organização, verificação pública por QR | Frigorífico, exportador, varejo |

## 4. Objetivos

| # | Objetivo | Horizonte |
|---|----------|-----------|
| O1 | Registrar 100% dos eventos do ciclo de vida bovino em modelo evento-histórico | MVP |
| O2 | Operar 48h+ sem conectividade sem perda de dados | Fase 2 |
| O3 | Ancorar hash de todo evento aceito em Hyperledger Fabric multi-org | Fase 4 |
| O4 | Reconciliar registros com SISBOV/GTA quando houver credenciais | Fase 5 |
| O5 | Rastreabilidade pós-abate: animal → carcaça → lote de corte → QR público | Fase 6 |
| O6 | Base extensível para cadeias agrícolas (grãos, café) | Fase 8 |

## 5. Benefícios esperados

- **Produtor**: gestão zootécnica digital, elegibilidade a mercados premium, dossiê pronto para auditoria.
- **Certificadora**: verificação remota de integridade, redução de visitas de conferência.
- **Frigorífico**: recebimento com histórico verificável, redução de risco de compra irregular.
- **Comprador/varejo**: prova de origem por lote de corte.
- **Consumidor**: consulta pública por QR Code com dados não sensíveis.
- **Ecossistema**: trilha de auditoria que sobrevive à troca de fornecedor de software.

## 6. Participantes

| Participante | Papel na rede |
|--------------|---------------|
| Fundação/entidade gestora (OrgFundacao) | Governança da rede Fabric, operação da plataforma |
| Produtores rurais (OrgProdutores) | Origem dos eventos de campo |
| Certificadora (OrgCertificadora) | Endosso de eventos críticos, certificação, ponte SISBOV |
| Frigorífico (OrgFrigorifico) | Recebimento, abate, transformação |
| Auditoria independente (OrgAuditoria, opcional) | Peer observador, verificação |
| Transportadores | Custódia em trânsito |
| Órgãos oficiais (MAPA, agências estaduais) | **DEPENDÊNCIA EXTERNA** — não operam nós; recebem dados por adaptadores |

## 7. Limites da solução

**FORA DE ESCOPO** (fase atual):

- Substituir SISBOV, GTA ou qualquer sistema oficial — a plataforma **complementa e reconcilia**, não emite documentos oficiais.
- Emissão de GTA — a GTA é registrada e associada, nunca emitida pela plataforma.
- Criptomoeda, token negociável, mineração — inexistem no desenho.
- iOS no MVP (Android primeiro; iOS avaliado pós-piloto).
- Gestão financeira/comercial da fazenda (preços ficam off-chain e fora do produto).
- Outras espécies além de bovinos/bubalinos antes da Fase 8.

## 8. O que a blockchain garante — e o que não garante

**Este ponto é inegociável na comunicação do produto.**

A blockchain **não garante que o dado é verdadeiro na origem**. Se um operador
registrar uma pesagem falsa, a blockchain provará apenas que *aquele operador,
daquela organização, com aquele dispositivo, registrou aquele valor naquele momento —
e que ninguém alterou o registro depois*.

A confiança do sistema vem da **combinação em camadas**:

| Camada | Mecanismo |
|--------|-----------|
| Identificação física | Brinco RFID + número visual + número oficial, com histórico de reidentificação |
| Autenticação | OIDC + MFA; credencial profissional para atos veterinários |
| Dispositivo confiável | Registro e atestação do dispositivo; revogação remota |
| Assinatura | Assinatura digital do evento no dispositivo, validada na API |
| Regras | Validações de negócio (quarentena, carência, ciclo encerrado) antes do aceite |
| Auditoria | AuditLog imutável de toda ação administrativa |
| Endosso multi-organização | Eventos críticos exigem endosso de ≥2 organizações independentes |
| Reconciliação oficial | Confronto com SISBOV/GTA quando disponível |

A blockchain é a camada de **prova de integridade e não-repúdio**, não de veracidade.

## 9. Riscos estratégicos

| # | RISCO | Probabilidade | Impacto | Mitigação |
|---|-------|---------------|---------|-----------|
| R1 | Acesso à API SISBOV nunca liberado ao projeto | Média | Alto | Arquitetura por adaptadores; valor do produto não depende da integração; parceria com certificadora credenciada |
| R2 | PNIB muda regras de identificação | Média | Médio | Modelo separa identificadores; officialAnimalId é campo próprio, adaptável |
| R3 | Adoção baixa no campo (usabilidade, cultura) | Alta | Alto | Piloto com produtor real na Fase 3; app desenhado para operador de curral, não para escritório |
| R4 | Rede Fabric com uma só instituição real (descentralização de fachada) | Alta no início | Alto para credibilidade | Roadmap exige 3 organizações independentes na Fase 4; comunicar honestamente o estágio |
| R5 | Custo de operação da rede supera receita no início | Média | Médio | Fase 1–3 com topologia mínima; Fabric só entra plenamente na Fase 4 |
| R6 | Vazamento de dados sensíveis de produtores | Baixa | Muito alto | Documento 13; dados pessoais nunca on-chain; PDC para dados restritos |
| R7 | Fraude física (brinco trocado entre animais) | Média | Alto | REIDENTIFICATION obrigatória, trilha de identificadores, cruzamento peso/idade, alertas de inconsistência |
| R8 | Dependência de fornecedor único de brincos/leitores | Média | Médio | Comunicação por padrões (ISO 11784/11785, Bluetooth SPP/BLE); camada de driver abstraída |

## 10. Critérios de sucesso

| Fase | Critério mensurável |
|------|---------------------|
| MVP | Ciclo completo de 1 animal (registro → pesagem → sanidade → movimentação → abate) registrado por eventos, com hash ancorado |
| Piloto | 1 propriedade real, ≥500 animais, 30 dias de operação, ≥95% dos eventos sincronizados sem intervenção manual |
| Rede | 3 organizações com peers próprios endossando; nenhuma transação aceita com endosso de uma única org |
| Homologação | ≥99% de reconciliação automática SISBOV em ambiente de homologação |
| Pós-abate | QR de lote de corte resolve para trilha verificável em <3s |
| Negócio | **QUESTÃO EM ABERTO** — metas comerciais (nº de fazendas, receita) a definir pela diretoria |

## 11. Dependências externas

| # | DEPENDÊNCIA EXTERNA | Impacto se ausente |
|---|---------------------|--------------------|
| D1 | Credenciamento junto a certificadora habilitada SISBOV | Fase 5 bloqueada; produto opera sem reconciliação oficial |
| D2 | Credenciais/ambiente de homologação SISBOV 2.0 (Access Key, Secret Key, IP liberado) | Idem D1 |
| D3 | Acordos com agências estaduais (GTA eletrônica varia por UF) | Registro de GTA permanece manual/por upload |
| D4 | Frigorífico parceiro para Fase 6 | Pós-abate fica em ambiente simulado |
| D5 | Organizações dispostas a operar peers próprios | Rede permanece centralizada de fato |
| D6 | Fornecimento de brincos RFID homologados e leitores compatíveis | Operação de campo degradada para digitação manual |

## 12. Decisões que precisam ser tomadas pela diretoria

Lista completa e consolidada no `17-DECISOES-DIRETORIA.md`. Resumo das críticas:

1. Modelo de governança da rede (fundação própria vs. consórcio) — define OrgFundacao.
2. Modelo comercial (SaaS por cabeça, licença por propriedade, taxa de certificação).
3. Parceria com certificadora específica (destrava D1/D2).
4. Orçamento e prazo-alvo do piloto (Fase 3).
5. Postura pública sobre o estágio de descentralização (transparência vs. marketing).
6. Contratação/designação de DPO e responsável jurídico LGPD.
7. Aprovação da política de dados on-chain/off-chain (Documento 11) — irreversível após produção.
