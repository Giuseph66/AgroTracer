# Documento 20 — Perfis de Interface

Data de referência: 2026-10-06. Estado: **Entrega 2 (fundação) concluída** —
ver §15. Decisões da §14 aprovadas pelo responsável em 2026-10-06, com D5
revisada. Este documento cresce a cada entrega: as seções 9 a 13 passam de
"proposta" para "implementado" conforme o Doc 18 for atualizado.

Leia antes: `AGENTS.md`, Doc 7 (matriz de acesso), Doc 18 (o que existe).

## 1. Objetivo

Parte dos trabalhadores rurais usa pouco o celular. O app atual é bom para quem
já domina sistemas digitais, mas esconde ações em rolagem horizontal, mistura
vocabulário técnico (sincronização, hash, RFID, GMD) com vocabulário de campo e
trata a mesma tela da mesma forma para o produtor e para o boiadeiro.

**Perfil de interface** decide *como* as funções disponíveis são apresentadas.
**RBAC/ABAC** (Doc 7) continua decidindo *o que* o usuário pode fazer.

> Regra de ouro: um perfil de interface nunca concede permissão. Toda ação passa
> pelo filtro de permissão real da sessão antes de ser desenhada, e a decisão
> vinculante continua sendo da API.

Fora de escopo (não muda): eventos, canonicalização, `deviceSequence`, Outbox,
pipeline de sync, regras R1–R42, Fabric, projeções, contratos da API, RBAC.

## 2. Inventário das telas atuais

Medido em `app/lib/` (10 370 linhas no total; telas em `features/`).

| Tela | Arquivo | Papel hoje | Dificuldade para quem tem pouca prática |
|------|---------|-----------|------------------------------------------|
| Login | `auth/login_screen.dart` (645) | E-mail e senha, retentativa automática | Fora do escopo desta refatoração; já usa mensagens de trabalho. |
| Shell | `main.dart` (200) | 4 destinos + botão central "Ler" | O destino "Sincronizar" nomeia um mecanismo, não uma tarefa. Ícone de `sync` não diz "o que falta enviar". FAB aparece para qualquer papel. |
| Início | `home/home_screen.dart` (413) | Faixa de fila, 2 ações grandes, **fileira horizontal** com 4 ações, cartão "Hoje" | Vacinação, Embarque, Nascimento e Áreas ficam numa rolagem horizontal sem indício de que há mais. Nenhuma ação é filtrada por permissão. "Bom dia" fixo, "Hoje na Santa Rita" fixo. "Em carência" conta animais `quarantined`, não carência. |
| Animais | `animals/animals_screen.dart` (690) | Busca + 5 dropdowns + ordenação + lista | Cinco filtros abertos de saída; busca em placeholder de 4 siglas ("Brinco, RFID, SISBOV ou lote"). Linha mostra RFID bruto em mono. Ícones sem rótulo na barra (cadastrar, exportar CSV). Cadastro pede raça, data em `AAAA-MM-DD` com default fixo `2024-01-01`. |
| Ficha do animal | `animal/animal_screen.dart` (535) | Brinco, métricas, 4 botões, identificadores, linha do tempo | Quatro botões de peso igual (Vacinar / "Novo registro" / Trocar brinco / Dossiê). "Novo registro" abre vacinação *sem* o animal. "Piquete `<UUID>`" mostra id interno. Erro exibe `$err` cru. Dossiê abre JSON em diálogo. |
| Leitura | `read/read_screen.dart` (338) | Círculo de 200–220 px, 3 fases | Título "Leitura RFID". Desconhecido mostra RFID bruto como destaque e fala em "pendência de resolução na sincronização". Contador fixo `12` e rodapé "Lote Recria 12" são **dados fabricados** (viola AGENTS §2.5-4). Botão "Simular brinco desconhecido" visível. |
| Pesagem | `weighing/weighing_screen.dart` (474) | Fila de brete, peso grande, fita da sessão | Já é a melhor tela do app — preservar. Pendências: "Balança AT-2" fixo no título; "Descartar animal" e campo de peso manual competem com a ação principal; fita horizontal de pesagens da sessão. |
| Vacinação | `vaccination/vaccination_screen.dart` (166) | Formulário único: produto, dose, via, lote do frasco, lista plana de todo o rebanho | Siglas SC/IM/IV/POUR_ON cruas. Dose pré-preenchida "5 ml" (dado de relevância sanitária preenchido sem o usuário pedir). Lista plana sem busca: com 300 animais é inutilizável. Sem passos. |
| Nascimento | `birth/birth_screen.dart` (119) | Dropdown de matriz + raça + sexo + visual + data | Cartão explica "3 eventos ordenados" (jargão). Raça pré-preenchida "NELORE". Dropdown de mães sem busca. |
| Troca de brinco | `identifier/reidentification_screen.dart` (97) | Dropdown de identificador + novo RFID/visual + motivo | Título "Nova identificação"; motivos em inglês cru (`LOST`, `DAMAGED`); botão "Carimbar nova identificação". Dois campos novos lado a lado sem dizer qual é qual na prática. |
| Áreas | `areas/areas_screen.dart` (625) + `area_detail_sheet.dart` (628) + `area_editor_screen.dart` (239) | Mapa, lista, desenho de polígono, mover animais | Mapa e desenho são ferramenta de gestão; o ato "mover animais" está dentro de uma folha de detalhe. Para o boiadeiro o caminho é: mapa → tocar polígono → folha → botão. |
| Embarques | `shipment/shipment_screen.dart` (433) | Lista + formulário de expedição + folha de conferência | **Destino é um campo de UUID** ("ID da propriedade destino"). Finalidade em caixa alta crua. Status cru (`DISPATCHED`). Lista plana de todos os animais. Tela única mistura consultar, criar e conferir. |
| Sincronização | `sync/sync_screen.dart` (403) | Conexão, "Precisam de você", fila com SyncBadge | Título "Sincronização". Linha da fila mostra `prova <TxID>…`. Detalhe expõe eventId, hash, sequência, tentativas, JSON — correto para técnico, ruído para operador. Texto "Escolha manter, corrigir ou descartar" oferece só 2 saídas. |
| Ajustes | `settings/settings_screen.dart` (313) | Conta, Central de acesso, conexão, aparelho, sair | Sem lugar para preferências. "Dispositivo" mostra UUID truncado. Conexão e último erro misturados com identidade. |
| Central de acesso | `admin/admin_screen.dart` (873) | Gestão de pessoas e perfis (web responsiva) | Ferramenta de gestão. Só aparece com `users.manage` — **não simplificar**. |

Referências visuais existentes: `design-review/` (85 capturas, baseline). Não há
`Design References/` nem equivalente. A imagem de referência fornecida
(grade 2×N de blocos coloridos com ícone + palavra) é usada como referência de
**hierarquia e descoberta**, não de cor.

## 3. Fluxo atual de navegação

```
AuthGate ──(sem sessão)──▶ LoginScreen
   └─(com sessão)──▶ AppShell  [IndexedStack: Início | Animais | Sincronizar | Ajustes]
                          │             FAB "Ler" ──▶ ReadScreen
        Início ──▶ Ler | Pesagem | (rolagem →) Vacinação | Embarque | Nascimento | Áreas
                   └─ cartão "Hoje" ──▶ Ficha (carência) | Embarques | Sync
        Animais ──▶ Ficha ──▶ Vacinação | Trocar brinco | Dossiê (diálogo)
                   └─ "+" Cadastrar (folha)  └─ "↓" Inventário CSV (diálogo)
        Ajustes ──▶ Central de acesso (se users.manage) | Sair
        Leitura ──▶ Ficha | Cadastro com brinco bruto (folha)
```

Profundidade até a ação mais usada: pesagem e leitura = 1 toque (bom).
Vacinação, nascimento, embarque e áreas = 1 toque **se** o usuário descobrir a
rolagem horizontal. Encontrar um animal = 2 toques (aba Animais → digitar).

## 4. Achados transversais

1. **Nenhuma ação é filtrada por permissão no app.** `AuthSession.can()` existe
   mas só `canManageUsers` é usado (Ajustes). Um operador vê "Vacinação",
   "Embarque" e "Nascimento" mesmo sem a permissão correspondente. Isto é
   pré-requisito do "nenhum perfil exibe ação não autorizada".
2. **O servidor aplica poucas permissões atômicas.** `@RequirePermission` só
   existe em `users.manage`. R17 é aplicada por *papel* (`VETE`) dentro do
   pipeline (`events.service.ts`, `ERR-SAN-001`), não pela permissão
   `health.private`. VACCINATION não é bloqueada no servidor para OPER.
   O espelho de permissões no app é, portanto, UX; a API continua decidindo.
3. **Não existe permissão de leitura** (`animals.read`). O catálogo
   (`policy.service.ts`) só tem `field.operate`, `health.apply`,
   `health.private`, `reports.export`, `users.read|manage`, `devices.manage`,
   `shipment.receive|transport`, `slaughter.operate`, `audit.read`,
   `certification.review`, `platform.manage`, `public.read`. AUDI, CERT, FRIG e
   TRAN têm leitura no Doc 7 mas nenhuma permissão que a represente.
4. **Sessão antiga pode ter `permissions` vazio** (comentário em
   `auth_session.dart`). Uma filtragem estrita deixaria o app sem ações até o
   próximo contato com a API.
5. **Vocabulário técnico na superfície**: "Sincronizar", "RFID", "GMD 30d",
   "prova", "evento aguardando envio", "payload"-adjacentes na folha de detalhe.
6. **Dados preenchidos sem pedido** (AGENTS §2.5-4): contador `12` e "Lote
   Recria 12" na leitura; "Balança AT-2" na pesagem; dose "5 ml"; raça
   "NELORE"; nascimento `2024-01-01`. Cada um é corrigido na entrega da tela
   correspondente, com teste de regressão.
7. **Rolagem horizontal escondendo função principal**: fileira de ações do
   Início. (A fita da pesagem é informativa e pode ficar.)
8. **Copy de botão genérica**: "Descartar leitura", "Usar", "Fechar",
   "Novo registro", "Colocar na fila". Padrão-alvo: verbo + objeto.
9. **Há módulos pedidos que não existem no app**: Saúde/Tratamentos (o app só
   tem vacinação; DIAGNOSIS/TREATMENT/QUARANTINE/RELEASE não têm tela — Doc 18
   §6.7), Lotes (só o texto `lot` do animal), Reprodução além do nascimento,
   Indicadores, Alertas. Ver decisão D3.
10. Simulação de RFID/balança (`_simulateRead`, `_readTag` com sorteio, peso
    aleatório) continua no código de produção. Fora desta refatoração (B10),
    mas o botão "Simular brinco desconhecido" não pode aparecer para operador.

## 5. Personas e ações essenciais

| Persona | Papel típico | Faz todo dia | Precisa raramente |
|---------|--------------|--------------|-------------------|
| Gestor / proprietário | PROD, ADMO | Ver rebanho, alertas, embarques, pendências | Mapa, exportar, acesso |
| Fazendeiro / capataz | TECN, TRAN, FRIG | Ler, pesar, vacinar, mover, nascimento | Relatório |
| Operador / boiadeiro | OPER | **Ler brinco, pesar, mover, ver animal**, às vezes vacinar/nascimento | Quase nada além disso |
| Técnico / veterinário | VETE (e TECN) | Sanidade, carência, histórico, animais | Pesagem |

## 6. Perfis propostos

`UiProfile { management, field, operator, technical }`. "Automático" **não é um
perfil**: é a ausência de preferência gravada (`null`), resolvida pelos papéis.
Em Ajustes aparecem 5 cartões (Automático + 4).

| Perfil | Rótulo | Ideia | Densidade |
|--------|--------|-------|-----------|
| `management` | Gestão | Visão geral, números, ferramentas. Mais próximo do app atual. | Alta |
| `field` | Campo | Grade de blocos grandes com todas as funções; sem rolagem horizontal. | Média |
| `operator` | Operador | 1 ação principal por contexto, texto curto, sem jargão, sem filtros abertos. | Baixa |
| `technical` | Técnico | Sanidade, carência e histórico em destaque. | Média |

### 6.1 Perfil padrão por papel (sem preferência gravada)

Avaliação em ordem; o primeiro papel presente vence ("mais capaz vence"):

| Ordem | Papéis | Perfil padrão |
|-------|--------|---------------|
| 1 | ADMO, ADMP, PROD | `management` |
| 2 | VETE | `technical` |
| 3 | TECN | `field` |
| 4 | OPER | `operator` |
| 5 | AUDI, CERT | `management` (leitura ampla) |
| 6 | TRAN, FRIG | `field` |
| 7 | nenhum reconhecido | `field` |

Preferência manual, quando existe, **sempre** vence o padrão. Se os papéis
mudarem depois (ex.: promoção), a preferência continua; a escolha "Automático"
reavalia na hora.

### 6.2 Persistência

Chave `traceagro.ui.profile.<actorId>` em `SharedPreferences` (valor: nome do
perfil; ausência = automático). Por **usuário**, não por aparelho: aparelho
compartilhado entre trabalhadores. Trocar de conta recarrega a preferência do
novo `actorId`. Logout não apaga a preferência (o próximo login do mesmo usuário
a reencontra).

## 7. Matriz Perfil × Funcionalidade (Início)

● bloco grande/destaque amarelo (no máx. 2 por perfil) · ○ bloco comum ·
— ausente. Toda célula ●/○ ainda depende de permissão (seção 8).

| Função (rótulo no Operador) | Gestão | Campo | Operador | Técnico |
|-----------------------------|:-----:|:-----:|:--------:|:-------:|
| Ler brinco | ○ | ● | ● | ○ |
| Pesagem (**Pesar**) | ○ | ● | ○ | — |
| Animais (**Ver animal**) | ● | ○ | ○ | ○ |
| Vacinação (**Vacinar**) | ○ | ○ | ○ | ● |
| Nascimento (**Registrar nascimento**) | ○ | ○ | ○ | — |
| Piquetes / Áreas (**Mover animais**) | ○ | ○ | ○ | ○ |
| Embarques | ○ | ○ | ○ | — |
| Alertas | ● | ○ | faixa no topo | ● |
| Pendências | faixa + aba | bloco | bloco + faixa | aba |
| Relatórios / exportar | ○ | — | — | ○ |
| Central de acesso | ○ | — | — | — |
| Cartão "Hoje" (números) | sim | não | não | sim (carências) |

No Operador o conjunto completo cabe em 2 colunas × 4 linhas em 412×915 sem
rolar. Troca de brinco não tem bloco próprio em nenhum perfil: vive na ficha
("Trocar brinco") e na leitura de brinco danificado.

### 7.1 Como cada perfil muda as telas internas (Entregas 4–6)

| Tela | Gestão | Campo | Operador | Técnico |
|------|--------|-------|----------|---------|
| Leitura | igual | título "Ler brinco" | idem + desconhecido com 3 ações grandes; RFID bruto secundário | igual a Campo |
| Pesagem | igual | igual | igual (já é a referência) | n/a |
| Vacinação | formulário atual + busca de animais | idem | 4 passos (produto → animais → conferir → registrar); via com rótulo explicado | formulário atual |
| Nascimento | atual + nota dos 3 eventos | mãe, sexo, data, brinco opcional | idem, "brinco pode ser colocado depois" em destaque | n/a |
| Troca de brinco | termos atuais | "Trocar brinco" | animal → novo brinco → motivo (PT-BR) → confirmar | termos atuais |
| Animais | todos os filtros | busca em destaque + "Mais filtros" | campo grande "Digite ou leia o brinco" + lista simples | filtro de carência/sanidade em destaque |
| Ficha | estatísticas, identificadores, linha do tempo, dossiê, prova | resumo + ações | brinco, status, peso, piquete, alerta + Pesar/Vacinar/Mover; "Ver histórico" e "Mais informações" recolhidos | carência, sanidade e histórico no topo |
| Áreas | mapa + editor | lista + mapa simples | escolher piquete → Mover animais (sem editor) | consulta sanitária por área |
| Embarques | atual | atual | tarefa guiada (destino → animais → conferir → Expedir; recebimento → ler → faltantes → Finalizar) | n/a |
| Pendências | atual | atual com vocabulário de campo | "3 registros esperando internet", "Tentar enviar", "Resolver"; técnico atrás de "Detalhes técnicos" | atual |
| Ajustes | + Modo da interface | idem | idem | idem |

## 8. Permissões: espelho de UX

**Regra (D5, aprovada):** uma ação só aparece quando **as duas fontes de
autorização concordam** — o catálogo de permissões da API (`policy.service.ts`,
vindo da sessão) **e** a coluna "C"/"V" do Doc 7 para algum papel vigente da
sessão. Havendo conflito, vale o mais restritivo. Uma permissão ampla como
`field.operate` **não** é lida como autorização implícita para todo ato de
campo. Nunca por perfil.

`UiAction.access` = `anyPermission` **e** `roles` (Doc 7). Sessão antiga com
`permissions` vazio: a verificação de permissão é substituída pela de papel
(papéis também vêm da API); sem papel, nada aparece.

| Ação | `anyPermission` | `roles` (Doc 7 §3) | Observação |
|------|-----------------|--------------------|------------|
| Ler brinco | `field.operate` | OPER, PROD, TECN | identificadores V/C |
| Pesagem | `field.operate` | **OPER, TECN** | Doc 7 nega "C" de pesagem a PROD (D5): PROD só não vê |
| Nascimento | `field.operate` | OPER, PROD, TECN | Doc 7 dá "C" a VETE, catálogo não dá `field.operate` → oculto |
| Piquetes / mover animais | `field.operate` | OPER, PROD, TECN | idem para VETE (manejo "V C") |
| Vacinação | `health.apply` | OPER, TECN, VETE | OPER é "A (delegação)": precisa também de `health.apply` (D4) |
| Troca de brinco | `field.operate` | OPER, PROD, TECN | aprovação por 2º usuário é do servidor (Doc 7 §4.4) |
| Embarques — expedir | `field.operate` | OPER, PROD, TECN | |
| Embarques — ver/receber | `field.operate`, `shipment.receive`, `shipment.transport` | OPER, PROD, TECN, TRAN, FRIG | |
| Animais (consulta) | — | todos exceto PUBL | D2: não existe permissão de leitura |
| Exportar inventário/dossiê | `reports.export` | PROD, TECN, VETE, CERT, FRIG, AUDI, ADMO, ADMP | hoje sem gate na tela de Animais |
| Central de acesso | `users.manage` | ADMO, ADMP | já existe: `canManageUsers` |
| Alertas, Pendências, Ajustes | — | qualquer sessão | sempre |

### 8.1 Inconsistências catálogo × Doc 7 (QUESTÃO EM ABERTO)

Registradas para decisão posterior de segurança; até lá a UI segue a regra
acima (mais restritiva) e a API continua sendo a decisão vinculante.

| # | Papel | Catálogo da API | Doc 7 | Efeito na UI hoje |
|---|-------|-----------------|-------|-------------------|
| I1 | PROD | `field.operate` | Pesagens "V X Ex" (sem C) | Pesagem oculta para quem é só PROD |
| I2 | VETE | sem `field.operate` | Manejo "V C", Reprodução "V C E X" | Mover animais e Nascimento ocultos |
| I3 | OPER | sem `health.apply` | Vacinação "A (delegação)" | Vacinar oculto; o servidor hoje **aceita** VACCINATION de OPER (não há gate) |
| I4 | ADMO/ADMP | só `users.*`, `devices.manage`, `platform.manage` | "V" em quase tudo | Só consulta (Animais) e Central de acesso |
| I5 | todos | — | — | O servidor só aplica `users.manage` por permissão; R17 é por papel (`VETE`). A UI pode ser mais restritiva que a API |

Implementação: `AuthSession.can()` e `canManageUsers` permanecem como estão.
Acrescentam-se apenas helpers de leitura (`canAny`, `hasAnyRole`) — sem alterar
RBAC.

## 9. Arquitetura (proposta)

Princípio: **dados declarativos + componentes genéricos**. Nenhuma tela de Home
por perfil; uma `HomeScreen` que lê a configuração do perfil efetivo.

```
core/ui_profile/
  ui_profile.dart           enum UiProfile + metadados (rótulo, descrição, ícone)
  ui_profile_config.dart    UiProfileConfig: colunas, altura mínima do bloco,
                            vocabulário (simples|técnico), seções do Início,
                            filtros progressivos, detalhes técnicos visíveis
  ui_profile_resolver.dart  defaultProfileFor(List<String> roles) — função pura
  ui_preferences.dart       UiPreferences (ChangeNotifier): actorId, preferência
                            (UiProfile?), effective; persistência por actorId;
                            reage a AuthSession (troca de usuário/papéis)
  ui_profile_scope.dart     InheritedNotifier acima do MaterialApp →
                            context.uiProfile / context.uiConfig; rebuild imediato
  ui_action.dart            UiAction (id, label por perfil, icon, builder da
                            rota, access, category, prioridade por perfil)
  ui_action_catalog.dart    lista const de UiAction + visibleFor(profile, auth)
core/widgets/
  profile_action_tile.dart  bloco grande: ícone + rótulo, Semantics(button),
                            área toda tocável, altura mínima, escala de texto
  profile_action_grid.dart  grade responsiva (2 col < 600, 3 < 900, 4 ≥ 900),
                            sem rolagem horizontal
  task_status_card.dart     "3 registros esperando internet" / "Tudo enviado" /
                            "1 precisa da sua atenção" (usa SyncBadge no técnico)
  simple_page_header.dart   cabeçalho de tela simples (título curto + voltar)
  ui_profile_selector.dart  5 cartões de "Modo da interface"
```

Decisões de desenho:

- **Perfil efetivo** = `preference ?? defaultProfileFor(auth.roles)`.
  `UiPreferences` escuta `AuthSession`; quando `actorId`/`roles` mudam, recarrega.
  Troca em Ajustes chama `notifyListeners()` → `InheritedNotifier` reconstrói a
  árvore, inclusive rotas já empilhadas. Sem logout, sem reinício.
- **Sem fork de eventos.** Telas simplificadas (vacinação em passos, nascimento,
  troca de brinco, embarque guiado) **reutilizam a mesma função que monta o
  payload e chama `outbox.enqueue`**, extraída da tela atual para uma função
  pura/testável. Teste de regressão compara payload gerado por cada apresentação.
- **Rótulos** vêm de `UiAction.labelFor(profile)`; textos de vocabulário
  (ex.: "Sincronizar" × "Pendências") vêm de `UiProfileConfig.vocabulary`.
- **Shell não é bifurcado.** Mesmos 4 destinos + botão central; mudam rótulo
  ("Sincronizar" → "Pendências"; FAB "Ler" → "Ler brinco" no Operador) e a
  visibilidade do FAB por permissão. Menos código, menos regressão.
- **Cores:** nenhum token novo na partida. Bloco primário = `tagYellow`
  (no máx. 2 por tela, "uma voz"); demais = `paper` + borda `line` + ícone
  `pasture`; alertas = `clay`/`clayBg`; informação = `sky`/`skyBg`.
  Significado nunca só por cor: sempre ícone + texto. Token novo só se a revisão
  visual (Entrega 7) mostrar necessidade, registrado em `tokens.dart` e AGENTS §2.2.
- **Alvos:** bloco ≥ 96 px (Campo/Técnico) e ≥ 120 px (Operador), crescendo com
  `textScaler`; ação primária de formulário ≥ 56 px (já no tema).
- **Offline:** `ConnectivityPill` permanece no cabeçalho de todos os perfis; no
  Operador o texto é "Sem internet · salvando no aparelho", tom neutro.

## 10. Arquivos

**Criar** (Entregas 2–3): os 13 da seção 9, mais
`app/test/ui_profile_resolver_test.dart`, `ui_preferences_test.dart`,
`ui_action_catalog_test.dart`, `home_profiles_test.dart`.

**Modificar:**

| Arquivo | Entrega | Mudança |
|---------|---------|---------|
| `core/auth/auth_session.dart` | 2 | `canAny(Iterable<String>)`; sem alterar `can`/`canManageUsers` |
| `core/services.dart` | 2 | instanciar `UiPreferences` ligado a `auth` |
| `main.dart` | 2–3 | `UiProfileScope` acima do `MaterialApp`; rótulos e FAB do shell por perfil |
| `features/settings/settings_screen.dart` | 2, 6 | seção "Modo da interface"; reordenar (Quem usa → Modo → Conexão → Aparelho → Acesso → Trocar de conta) |
| `features/home/home_screen.dart` | 3 | compor por `UiProfileConfig` + `ProfileActionGrid` |
| `features/read`, `vaccination`, `birth`, `identifier` | 4 | linguagem, passos, remoção de dados fabricados |
| `features/animals`, `animal`, `areas` | 5 | apresentação progressiva |
| `features/shipment`, `sync` | 6 | fluxos guiados; vocabulário; detalhes técnicos recolhidos |
| `AGENTS.md` | 3 e 7 | regras permanentes novas (ver seção 12) |
| `docs/18`, `docs/19`, `docs/00-INDICE.md` | cada entrega | estado atual / backlog / índice |

**Não tocar:** `core/sync/*`, `data/api_client.dart` (contratos), `domain/models.dart`
(salvo se a Entrega 3 precisar de um getter de leitura), qualquer coisa em `api/`.

## 11. Plano em entregas

| # | Entrega | Saída verificável | Commits previstos |
|---|---------|-------------------|-------------------|
| 1 | Auditoria (este doc) | Doc 20, índice, backlog | `docs(app)` |
| 2 | Fundação | `UiProfile`, resolver, `UiPreferences` por actorId, escopo, seletor em Ajustes; Início ainda igual | `feat(app)`, `test(app)` |
| 3 | Início + navegação | Início por perfil, grade, filtro por permissão, shell com rótulos/FAB; capturas 360×640, 412×915, tablet, web | `feat(app)` ×2–3, `test(app)` |
| 4 | Fluxos de campo | Leitura, vacinação (passos), nascimento, troca de brinco; remove dados fabricados | `refactor(app)` por tela |
| 5 | Consulta | Animais, ficha, áreas | `refactor(app)` por tela |
| 6 | Operações | Embarques guiados, Pendências, Ajustes | `refactor(app)` por tela |
| 7 | Revisão | Capturas novas em `design-review/profiled-ui/`, comparação com baseline, Doc 18 | `docs`, `test` |

Cada entrega: `flutter analyze` limpo, `flutter test` verde; se tocar API,
`npm test` + `npm run build` (+ `test:e2e`). Um assunto por commit; push ao fim.

## 12. Estratégia de testes

- **Resolver** (puro): matriz papel → perfil, multi-papel, vazio, desconhecido.
- **Preferências:** manual vence automático; persiste e reabre; chaves por
  `actorId` (A e B no mesmo aparelho); trocar de usuário recarrega; logout não
  vaza preferência do anterior; "Automático" apaga a chave.
- **Catálogo:** para **cada** papel × perfil, nenhuma ação visível sem a
  permissão; OPER com perfil Gestão não vê Central de acesso; sessão com
  `permissions` vazio usa `fallbackRoles` e nada além.
- **Widgets:** cada perfil renderiza seus blocos esperados; troca de perfil
  reconstrói sem reiniciar; grade em 360, 412, 800 e 1280 de largura sem
  overflow, com `textScaler` 1.0 e 1.6; `Semantics(button: true, label)` em todo
  bloco; nenhuma `Scrollable` horizontal na Home dos perfis simples.
- **Regressão de payload:** vacinação/nascimento/troca/embarque simplificados
  geram o mesmo envelope que as telas atuais (mesmo `payloadHash` para mesmos
  inputs).
- **Regressão de dado fabricado:** leitura sem lido não mostra contador nem lote.
- **Visual:** capturas Playwright (Flutter web é canvas — por coordenada ou
  semantics) comparadas ao baseline de `design-review/`.

Regras permanentes a promover para o AGENTS.md na Entrega 3: (a) toda ação nova
nasce como `UiAction` com `access`; (b) nenhum perfil concede permissão;
(c) proibida rolagem horizontal para função principal; (d) rótulo de botão é
verbo + objeto; (e) vocabulário técnico só em modo Gestão/Técnico ou atrás de
"Detalhes técnicos".

## 13. Riscos

| Risco | Mitigação |
|-------|-----------|
| Filtro estrito esconde tudo para sessão antiga com `permissions` vazio | `fallbackRoles` só nesse caso; `/auth/me` renova a cada boot online |
| Espelho de permissões diverge do servidor (R17 por papel, VACCINATION sem gate) | Documentar; API segue vinculante; nunca prometer na UI que a ação será aceita |
| Duplicar lógica de evento ao simplificar telas | Extrair construtor de payload único; teste de igualdade de envelope |
| Perfil Operador esconde informação que muda decisão (carência, conflito) | Alerta importante sempre sobe como faixa; carência continua banner na ficha |
| Troca de perfil com tela de brete aberta | Telas imersivas (leitura, pesagem) não dependem do perfil para fluxo; só rótulos |
| `IndexedStack` mantém telas vivas e o perfil muda por baixo | `InheritedNotifier` acima do `MaterialApp`: todas reconstroem |
| Dois perfis aparentemente iguais (Campo × Técnico) | Matriz da seção 7 define diferenças; revisar após Entrega 3 com usuários reais |
| Capturas de Flutter web em canvas | Playwright por coordenada/semantics (AGENTS §6) |
| Escala de texto grande quebra grade | Altura do bloco em função do `textScaler`; teste a 1.6 |

## 14. Decisões

Revisadas pelo responsável em 2026-10-06. D2–D8 aprovadas explicitamente;
D1, D9 e D10 seguem o padrão recomendado, sem objeção ("está quase tudo
certo").

| # | Questão | Decisão |
|---|---------|---------|
| D1 | Perfil padrão de AUDI/CERT e TRAN/FRIG | `management` e `field` (padrão, sem objeção) |
| D2 | Não há permissão de leitura de animais | **Aprovada.** "Animais" para qualquer papel exceto PUBL. Criar `animals.read` é mudança de RBAC → backlog |
| D3 | Módulos pedidos sem tela (Saúde/Tratamentos, Lotes, Reprodução, Indicadores, Alertas) | **Aprovada.** Nada inventado. **Alertas** só com dados reais já no app (carência, conflitos, embarques aguardando). Demais ficam fora até a API sustentar; "Lotes/Piquetes" aponta para Áreas |
| D4 | OPER sem `health.apply` | **Aprovada.** Permissão manda, não o perfil: "Vacinar" oculto para OPER sem `health.apply` |
| D5 | PROD tem `field.operate` no catálogo, mas o Doc 7 lhe nega criar pesagem | **Revisada pelo responsável.** Em conflito entre catálogo e RBAC/Doc 7, prevalece o mais restritivo; `field.operate` não é autorização implícita para criar pesagem. PROD não recebe a ação de pesagem até a inconsistência ser resolvida. Regra geral na §8; inconsistências na §8.1 |
| D6 | Tela "Escolher piquete" (lista, sem mapa) para Operador/Campo | **Aprovada.** Reutiliza `PADDOCK_CHANGE` e a folha de mover existente |
| D7 | Embarque guiado sem destino por nome | **Aprovada.** Documentar o contrato necessário na Entrega 6 antes de alterar backend; não inventar destino no app |
| D8 | Simulação/dado fabricado na leitura | **Aprovada.** Remover da interface real qualquer simulação ou dado fabricado (Entrega 4) |
| D9 | Perfil de quem já usa o app | Padrão por papel na primeira abertura (sem objeção) |
| D10 | Rótulo do menu inferior no Operador | "Pendências" (sem objeção) |

## 15. Estado das entregas

| # | Entrega | Estado |
|---|---------|--------|
| 1 | Auditoria | Concluída (2026-10-06) |
| 2 | Fundação | Concluída (2026-10-06) — abaixo |
| 3–7 | Início, fluxos, consulta, operações, revisão | Pendentes |

### 15.1 Entrega 2 — o que existe

- `app/lib/core/ui_profile/ui_profile.dart` — enum `UiProfile` (rótulo,
  descrição, ícone, valor gravado = nome do enum).
- `ui_profile_resolver.dart` — `defaultUiProfileFor(roles)`, tabela da §6.1.
- `ui_preferences.dart` — `UiPreferences` (ChangeNotifier): segue a
  `AuthSession` sozinho (troca de conta recarrega a escolha do novo
  `actorId`), grava em `traceagro.ui.profile.<actorId>`; `null` = Automático
  (a chave é apagada). `init()` roda antes do boot da sessão em
  `AppServices._start` para o shell já nascer no perfil certo.
- `ui_profile_scope.dart` — `InheritedNotifier` acima do `MaterialApp`
  (`main.dart`): a troca reconstrói rotas abertas e abas do `IndexedStack`.
- `core/widgets/ui_profile_selector.dart` — "Modo da interface" em Ajustes,
  logo abaixo de quem está usando: 5 cartões (Automático mostra "Agora: …"),
  seleção por borda + ícone + "Em uso" (não só cor), `Semantics` com toque e
  estado selecionado, 1 coluna no telefone e 2 a partir de 640 px.
- Nenhuma tela além de Ajustes muda de comportamento ainda; o Início é a
  Entrega 3.
- Testes: `app/test/ui_profile_test.dart` (15) — mapa papel → perfil,
  multi-papel, manual vence automático, persistência após reabrir, usuários
  distintos no mesmo aparelho, Automático apaga a chave, sem sessão não grava,
  valor gravado inválido, perfil não altera papéis/permissões, seletor
  renderiza, troca sem reiniciar com semântica correta, 360 px com texto 1,6×.
- Validação visual (web, API de laboratório, usuário ADMO): capturas em
  `design-review/profiled-ui/` — `00-before-home-admo-412.png` (baseline do
  Início atual: ADMO vê Pesagem sem `field.operate`; "Áreas" cortado na
  rolagem), `01`/`02`/`03-settings-mode-*` (412, 1024, 360). Troca para
  Operador refletiu na hora e sobreviveu a recarregar a página.
