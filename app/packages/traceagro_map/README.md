# traceagro_map

Componentes de mapa do TraceAgro: visualização da propriedade, desenho e
medição de piquetes, seleção de áreas e camada de situação sanitária.

Atende o item **B2** do `docs/19-BACKLOG-IMPLEMENTACAO.md`.

## Por que é um pacote separado

O pacote **não conhece** os modelos, o tema, a fila de eventos nem a camada de
dados do aplicativo. Ele define os próprios tipos (`GeoPoint`, `MapArea`) e
devolve contornos prontos para persistir. Isso permite:

- desenvolver e revisar o mapa sem subir API nem banco (veja `example/`);
- trocar a biblioteca de mapa sem que o app perceba;
- integrar sem conflito com trabalho em andamento no aplicativo — a ligação é
  uma linha no `pubspec.yaml` e uma função de conversão.

## Instalar

```yaml
# app/pubspec.yaml
dependencies:
  traceagro_map:
    path: packages/traceagro_map
```

## Usar

### Mapa da propriedade com situação sanitária

```dart
AreaMapView(
  areas: paddocks.map(toMapArea).toList(),
  markers: animaisLocalizados,
  selectedAreaId: selecionada?.id,
  onAreaSelected: (area) => setState(() => selecionada = area),
  onAreaLongPress: (area) => abrirAnimaisDaArea(area.id),
)
```

A cor do contorno vem de `MapArea.healthStatus`. A regra de agregação é do app,
não do pacote: o piquete inteiro assume o **pior** estado presente entre seus
animais, porque a decisão ("posso mandar esse lote para o embarque?") é tomada
por área. `AreaHealthStatus.worst(...)` faz essa conta.

### Desenhar ou editar um piquete

```dart
final controller = AreaDrawController();      // ou initialRing: ... para editar

AreaDrawMap(
  controller: controller,
  referenceAreas: outrosPiquetes,             // desenhados ao fundo
  onSave: (ring) => salvarPiquete(ring),      // só chama com contorno válido
  onCancel: () => Navigator.pop(context),
)
```

O botão de salvar só habilita quando o contorno passa na validação. Enquanto
isso, o painel mostra a medida ao vivo e, havendo problema, a frase que explica
o que fazer.

### Converter para os tipos do app

```dart
MapArea toMapArea(Paddock p) => MapArea(
      id: p.id,
      name: p.name,
      ring: p.geometry.map((c) => GeoPoint(c.lat, c.lon)).toList(),
      animalCount: p.animalCount,
      healthStatus: AreaHealthStatus.worst(p.animals.map(statusDoAnimal)),
    );

// Para a API (GeoJSON usa longitude primeiro)
final coordinates = ring.map((p) => p.toGeoJsonCoordinate()).toList();
```

## O que o pacote entrega

| Componente | O que faz |
|------------|-----------|
| `AreaMapView` | Mapa com áreas coloridas por situação, seleção por toque, enquadramento (`fitAllAreas`, `focusArea`) |
| `AreaDrawMap` | Desenho por toque, vértices arrastáveis, desfazer, limpar, medida ao vivo, validação com aviso |
| `AreaDrawController` | Máquina de estados do desenho, testável sem interface |
| `AreaSummarySheet` | Ficha da área: medida, animais, lotação, ações |
| `AreaLegend` | Legenda das cores |
| `AreaLabelsLayer` | Rótulos com resolução de colisão |
| `Geodesy` | Área em hectares, perímetro, distância, contém-ponto, formatação |
| `PolygonValidation` | Poucos vértices, cruzamento, ponto repetido, área degenerada |
| `TileSource` | Satélite, ruas ou modo offline |

## Medição

A área é calculada **sobre a esfera** (excesso esférico, raio médio IUGG), não
no plano: um piquete de 200 ha medido com fórmula planar erra o suficiente para
brigar com a matrícula do imóvel. O erro contra o modelo elipsoidal fica abaixo
de 0,5% nas dimensões de uma propriedade.

Isso é adequado para **manejo**. Medição com valor legal continua sendo
trabalho de georreferenciamento credenciado — o pacote não substitui isso e não
deve ser apresentado como se substituísse.

Os testes conferem os valores contra o cálculo analítico independente
(lado × lado sobre a esfera), não contra a própria implementação.

## Decisões

- **flutter_map + OSM/Esri** em vez de `google_maps_flutter`: dispensa chave paga e permite cache de tiles para uso offline (questão Q1 do Doc 19).
- **Tipos próprios** em vez dos modelos do app: mantém o pacote reutilizável e a integração explícita.
- **Rótulo que colide é omitido**, não empilhado: dois textos embaralhados são piores que um nome faltando. Áreas pequenas demais na tela também não recebem rótulo, e marcadores de animal reservam espaço antes dos rótulos.
- **Contorno cruzado mostra "—"**, não "0 m²": a área de uma gravata-borboleta é matematicamente nula, e exibir zero faria o operador achar que mediu algo.
- **Aviso, não recusa silenciosa**: desenho inválido explica o que fazer e desabilita o salvar.

## Rodar a vitrine

```bash
cd example
flutter run -d chrome
```

Duas abas: mapa da propriedade (seleção, ficha, troca satélite/ruas) e desenho
de piquete novo. Os dados de `example/lib/sample_areas.dart` são de demonstração
da vitrine — o aplicativo nunca preenche tela com dado inventado
(`AGENTS.md` §2.5).

## Testes

```bash
flutter test      # 41 testes: geodésia, validação, controlador de desenho
flutter analyze
```

## Pendente

- Cache de tiles para operação offline real (questão Q2 do Doc 19). Hoje o modo offline desenha as geometrias sobre fundo liso, sem base cartográfica.
- Captura de contorno por GPS (caminhar a cerca) como alternativa ao toque.
- Localização do usuário no mapa.
