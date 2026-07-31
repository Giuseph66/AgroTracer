# AGENTS.md — TraceAgro

Guia obrigatório para qualquer agente ou pessoa que escreva código neste
repositório. Leia antes de tocar em qualquer arquivo. Ordem de leitura:
este arquivo → `docs/18-IMPLEMENTACAO-ATUAL.md` (o que existe) →
`docs/19-BACKLOG-IMPLEMENTACAO.md` (o que fazer) → documento de especificação
citado pelo item que você for implementar (`docs/00-INDICE.md` é o índice).

## 1. O que é o produto

Rastreabilidade bovina orientada a eventos, **offline-first no campo**, com
prova de integridade ancorada em blockchain permissionada. O usuário típico está
num curral, com luva, poeira e sol, sem internet. Tudo decorre disso.

---

## 2. Design system (obrigatório em toda tela)

### 2.1 Identidade

O conceito visual é o **brinco de gado**: placa amarela estampada, número preto,
furo de fixação. Ambiente: verde-pasto profundo e papel quente. O app deve
parecer equipamento de campo, não dashboard corporativo.

### 2.2 Tokens (fonte única: `app/lib/core/theme/tokens.dart`)

Nunca use hex solto em tela; sempre `TaColors.*`, `TaSpace.*`, `TaRadius.*`.

| Token | Valor | Uso |
|-------|-------|-----|
| `pasture` | `#1A2E1D` | Headers, telas imersivas de campo (leitura, pesagem), nav inferior |
| `pastureDeep` | `#122015` | Variação escura |
| `paper` | `#FAF7F0` | Superfícies de cartão |
| `paperDim` | `#F0EBDF` | Fundo de página |
| `tagYellow` | `#F2B90D` | **Assinatura**: ação primária, brinco, destaques. Uma voz — não pintar tudo de amarelo |
| `tagYellowDeep` | `#C79104` | Bordas/pressed do amarelo |
| `stamp` | `#17190F` | Texto sobre amarelo ("tinta estampada") |
| `clay` / `clayBg` | `#B4552D` / `#F6E3D9` | Alerta, carência, conflito, divergência |
| `sage` / `sageBg` | `#5F7A4E` / `#E4EADB` | Ok, sincronizado, comprovado |
| `sky` / `skyBg` | `#3E6B8C` / `#DFE9F0` | Informação, envio em curso |
| `ink` / `inkSoft` | `#1E211B` / `#5C6154` | Texto sobre claro |
| `paperInk` / `paperInkSoft` | `#F4F1E6` / `#B9C2B0` | Texto sobre pasture |
| `line` | `#DDD6C6` | Divisores |

Espaço: 4/8/16/24/32/48 (`TaSpace.xs..xxl`). Raios: 10/16/24 (`TaRadius`).

### 2.3 Tipografia (via google_fonts, configurada em `theme.dart`)

- **Archivo Black** — display/números grandes (peso na balança, número do brinco, contadores). É a voz "estampada" da marca.
- **Archivo** — corpo e títulos (w700 para títulos).
- **Spline Sans Mono** — códigos RFID, SISBOV, hashes, TxID, horários técnicos. Todo identificador técnico é mono, sempre.
- Eyebrow de seção: caixa alta, 12px, letterSpacing 1.2 (`SectionLabel`).

### 2.4 Componentes canônicos (reusar, não recriar)

| Componente | Arquivo | Regra |
|------------|---------|-------|
| `EarTag` | `core/widgets/ear_tag.dart` | Identidade do animal em destaque (ficha, leitura). Miniatura = quadrado amarelo com número (lista) |
| `SyncBadge` | `core/widgets/common.dart` | **Todo evento exibido carrega seu estado de sincronização.** Estados e cores já mapeados (Doc 8 §5) — não inventar variantes |
| `TaCard` | `common.dart` | Cartão padrão: paper, raio 24, borda `line`, sem sombra |
| `ConnectivityPill` | `common.dart` | Estado de rede no header. Offline **não é erro** — é modo de operação, tom neutro |
| `SectionLabel` | `common.dart` | Título de seção |

### 2.5 Princípios de UX de campo (não negociáveis)

1. **Alvos de luva**: ação primária ≥56px de altura; o gesto mais frequente da tela ganha o maior alvo (ex.: círculo de 200px na leitura/pesagem).
2. **Telas imersivas de campo** (leitura, pesagem): fundo `pasture`, foco único, zero navegação concorrente. Telas de consulta/gestão: fundo `paperDim` com cartões.
3. **Estado de sync sempre visível**: o operador precisa saber o que subiu, o que espera e o que precisa dele, sem procurar.
4. **Nunca dado fabricado**: tela sem dados distingue explicitamente *carregando* / *busca sem resultado* / *sem rede (não sei)* / *realmente vazio*. Proibido preencher com exemplo (ver bug 4 no Doc 18 §5 — já aconteceu, não repetir).
5. **Fluxo de brete é fila**: confirmar uma operação prepara imediatamente a próxima (padrão da tela de pesagem: confirma → volta a "passar animal" → fita da sessão registra o anterior).
6. **Variação suspeita alerta, não bloqueia** (peso ±30%): o animal está na balança e a fila não espera; marca para revisão.
7. **Copy em pt-BR, voz de trabalho**: frases curtas, verbo no botão dizendo o que acontece ("Confirmar e liberar", "Registrar com brinco bruto"). Erros dizem o que houve e o que fazer, sem pedir desculpa. Nada de jargão de sistema na tela (nunca "payload", "sync job"); códigos técnicos (`IDENTIFIER_TAKEN`) aparecem pequenos e em mono, como referência.
8. **Acessível sob sol**: manter contrastes altos dos tokens; não introduzir cinza-sobre-cinza.

---

## 3. Convenções de engenharia (não negociáveis)

### 3.1 Eventos são a verdade

- Todo fato de domínio é um **evento imutável** do catálogo (Doc 5), criado no dispositivo com UUIDv7, hash canônico e `deviceSequence`.
- **Não existe endpoint de CRUD para fatos** (animal, pesagem, vacinação...). Escrita = evento pelo pipeline. Leitura = projeções.
- Projeções (`read_model.*`) são recalculadas **pelo servidor** e regeráveis por replay. O cliente nunca informa "peso atual" ou "status".
- Correção = novo evento com `correctionOf`. Nada se apaga (R7/R8).
- `core.event` e `core.audit_log` são append-only por **grants** — se precisar de uma transição de estado legítima, crie função `SECURITY DEFINER` estreita (exemplo: migração 004), nunca conceda UPDATE amplo.

### 3.2 Paridade do hash canônico (crítico)

`app/lib/core/sync/canonical.dart` (Dart) e `api/src/events/canonical.ts` (TS)
devem produzir **bytes idênticos**. Vetores compartilhados:
`api/test/vectors.json`, gerados por `api/test/generate-vectors.js`.
Mudou canonicalização ⇒ regenerar vetores ⇒ `npm test` E `flutter test` verdes.
Divergência de um byte rejeita todo evento do campo (ERR-EVT-HASH).

### 3.3 Idempotência e ordem

- Dedup por `eventId` e `(deviceId, deviceSequence)`; reenvio devolve o veredicto original com `duplicate: true` (R22/R23).
- Lote processado em ordem de `deviceSequence` (R27); dependências entre eventos do mesmo lote se resolvem por essa ordem.
- Sequência do dispositivo nunca retrocede; ao abrir, o app adota `GET /v1/devices/:id/sync-state` (bug 3 do Doc 18 §5).

### 3.4 Regras de domínio no servidor

Validação local no app é UX; **a decisão vinculante é sempre da API**. Regras
numeradas (R1–R42) estão no Doc 6 — cite o número no código quando implementar
uma (`// R3: um RFID ativo nunca...`). Novos códigos de erro seguem
`ERR-<MÓDULO>-<NNN>` (catálogo no Doc 3) ou conflictTypes do Doc 8 §7.

### 3.5 Identificadores nunca se misturam

`animalId` (UUIDv7 interno) ≠ `officialAnimalId` (SISBOV) ≠ `rfidCode` ≠
`visualTagNumber` ≠ `payloadHash` ≠ `blockchainTxId`. Campos separados sempre,
em banco, API, app e tela (Regra Fundamental, Doc 0/4).

### 3.6 Dados sensíveis

CPF, nomes de pessoa, coordenadas precisas, documentos, preços: **nunca**
on-chain (R21, lista proibitiva no Doc 11 §3), nunca em tela pública, nunca em
log. Coordenadas de propriedade são P3.

### 3.7 Qualidade mínima por entrega

- `flutter analyze` limpo; `flutter test` verde; `npm test` verde; se tocou ingestão/regras: `npm run test:e2e` verde (exige compose + API no ar).
- Bug encontrado ⇒ teste de regressão junto da correção (padrão do Doc 18 §5).
- Interface do `Outbox` e contratos da API são estáveis: mudar exige atualizar Doc 18 e os testes dos dois lados.
- Commits/PRs em inglês convencional; código comentado apenas onde há regra de domínio ou restrição não óbvia (citar R-número/Doc).

### 3.8 Stack fixada

Flutter/Dart (app) · NestJS+Fastify+TypeScript (API) · PostgreSQL+PostGIS ·
Drift+SQLCipher (local, backlog B11) · Hyperledger Fabric (Fase 4; gateway
simulado até lá — não introduzir outra chain). Não adicionar framework/ORM
novo sem registrar DECISÃO em doc.

---

## 4. Como rodar e testar

```bash
docker compose -f compose.dev.yml up -d          # Postgres 5433 (schema+seed)
cd api && npm install && npm run build && PORT=3999 npm start
cd app && flutter run                             # ou -d chrome
# API alternativa p/ dispositivo físico:
flutter run --dart-define=TRACEAGRO_API=http://<ip>:3999
```

Testes: `api: npm test | npm run test:e2e | npm run vectors` ·
`app: flutter analyze && flutter test`.
Migrações novas: arquivo numerado em `api/db/migrations/` + aplicar com `psql`
(runner é pendência registrada — Doc 18 §6.6).

Identidade de laboratório (org/usuário/dispositivo/animais seed): Doc 18 §4.
Será substituída pelo login (backlog B1).

## 5. Versionamento — obrigatório ao concluir qualquer implementação

Repositório: `https://github.com/Giuseph66/AgroTracer` (branch `main`).

**Toda implementação concluída termina com commit e push.** Não deixe trabalho
pronto fora do controle de versão: sem push, o histórico do projeto fica
incompleto e a próxima pessoa/agente não sabe o que já existe.

### 5.1 Autoria: sempre do dono do repositório

O autor de todo commit é **Giuseph Giangareli**
(`giusephgangareli@gmail.com`), que dirige o trabalho e responde pelo código.

- **Nunca** use conta, credencial, e-mail ou identidade própria de assistente.
- **Nunca** adicione trailer `Co-Authored-By` de assistente, nem cite ferramenta de IA na mensagem, no corpo do commit ou na descrição de PR.
- **Nunca** use API/integração de terceiros para criar o commit. Use exclusivamente **comandos `git` no terminal (Bash)**, para que o registro na linha do tempo do GitHub seja do usuário, com a credencial dele já configurada na máquina.

A identidade já está no `git config` global da máquina; não sobrescreva.
Confira antes de commitar:

```bash
git config user.name    # Giuseph_Giangareli
git config user.email   # giusephgangareli@gmail.com
```

### 5.2 Como commitar

Commits **separados por assunto** — um commit que mistura schema, API e telas é
impossível de revisar ou reverter. Conventional Commits, em inglês, imperativo:

```bash
git add <arquivos do assunto>
git commit -m "feat(api): add vaccination batch projection"
git push origin main
```

Prefixos: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`, `perf`.
Escopos usados: `api`, `app`, `db`, `docs`, `infra`.

O corpo do commit (quando houver) explica **por que**, não o que — o diff já
mostra o que mudou. Bug corrigido: descreva causa e efeito, como no
`docs/18-IMPLEMENTACAO-ATUAL.md` §5.

### 5.3 Antes do push, sempre

1. `flutter analyze` limpo e `flutter test` verde.
2. `npm run build` e `npm test` verdes na API; se tocou ingestão/regras, `npm run test:e2e` também.
3. **Nunca commitar código que não compila.** Se encontrar a árvore quebrada por trabalho de outro, conserte ou pare e relate — não empacote o defeito.
4. Conferir `git status` e o diff staged: nenhum segredo, nenhum `node_modules/`, `build/`, `.dart_tool/`, `.env` ou material de Fabric (o `.gitignore` cobre, mas confira).
5. Atualizar `docs/18-IMPLEMENTACAO-ATUAL.md` quando o estado do sistema mudar, e marcar o item concluído em `docs/19-BACKLOG-IMPLEMENTACAO.md`.

### 5.4 Segredos

Credenciais reais nunca entram no repositório (Doc 13). As senhas presentes em
`compose.dev.yml` e no seed SQL são de laboratório local, valem só na máquina do
desenvolvedor e não devem ser reaproveitadas em nenhum outro ambiente —
homologação e produção usam Vault/KMS conforme Doc 13 §4.2.

## 6. Armadilhas conhecidas

- `eventId` é UUID**v7** — v4 falha na validação do DTO.
- Porta do Postgres é **5433** (não 5432).
- Duas pesagens no mesmo dia **não** geram GMD (regra de domínio, não bug).
- Animal `IN_TRANSIT`/encerrado rejeita eventos incompatíveis (R14) — é comportamento esperado nos testes de embarque.
- Playwright contra Flutter web: renderização em canvas ⇒ sem DOM; interações por coordenada ou semantics.
