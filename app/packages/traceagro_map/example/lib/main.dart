import 'package:flutter/material.dart';
import 'package:traceagro_map/traceagro_map.dart';

import 'sample_areas.dart';

/// Vitrine dos componentes de mapa.
///
/// Serve para desenvolver e revisar visualmente os widgets sem depender do
/// aplicativo — é aqui que se confere se o mapa continua legível depois de uma
/// mudança, sem subir API nem banco.
void main() => runApp(const MapGalleryApp());

class MapGalleryApp extends StatelessWidget {
  const MapGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const theme = MapTheme();
    return MaterialApp(
      title: 'TraceAgro · componentes de mapa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: theme.paperDim,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.pasture,
          primary: theme.tagYellow,
          surface: theme.paper,
        ),
      ),
      home: const MapThemeProvider(theme: theme, child: GalleryHome()),
    );
  }
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [PropertyMapDemo(), DrawPaddockDemo()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Propriedade',
          ),
          NavigationDestination(
            icon: Icon(Icons.draw_outlined),
            selectedIcon: Icon(Icons.draw),
            label: 'Desenhar',
          ),
        ],
      ),
    );
  }
}

/// Mapa da propriedade com situação sanitária por área.
class PropertyMapDemo extends StatefulWidget {
  const PropertyMapDemo({super.key});

  @override
  State<PropertyMapDemo> createState() => _PropertyMapDemoState();
}

class _PropertyMapDemoState extends State<PropertyMapDemo> {
  final GlobalKey<AreaMapViewState> _mapKey = GlobalKey();
  MapArea? selected;
  TileSource source = TileSource.satellite;

  @override
  Widget build(BuildContext context) {
    final theme = MapTheme.of(context);
    final areas = sampleAreas;

    return Stack(
      children: [
        Positioned.fill(
          child: AreaMapView(
            key: _mapKey,
            areas: areas,
            markers: sampleMarkers,
            tileSource: source,
            selectedAreaId: selected?.id,
            initialZoom: 14.2,
            onAreaSelected: (area) => setState(() => selected = area),
          ),
        ),

        // Barra de contexto: nome da propriedade e troca da base cartográfica.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              bottom: 14,
            ),
            color: theme.pasture,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAZENDA SANTA RITA',
                        style: TextStyle(
                          color: theme.paperInk.withValues(alpha: 0.6),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${areas.length} áreas · ${areas.fold<int>(0, (s, a) => s + a.animalCount)} animais',
                        style: TextStyle(
                          color: theme.paperInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: source == TileSource.satellite
                      ? 'Ver mapa de ruas'
                      : 'Ver satélite',
                  onPressed: () => setState(() {
                    source = source == TileSource.satellite
                        ? TileSource.openStreetMap
                        : TileSource.satellite;
                  }),
                  icon: Icon(Icons.layers_outlined, color: theme.paperInk),
                ),
                IconButton(
                  tooltip: 'Enquadrar tudo',
                  onPressed: () => _mapKey.currentState?.fitAllAreas(),
                  icon: Icon(Icons.fit_screen_outlined, color: theme.paperInk),
                ),
              ],
            ),
          ),
        ),

        const Positioned(right: 16, top: 110, child: AreaLegend(compact: true)),

        if (selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AreaSummarySheet(
              area: selected!,
              onClose: () => setState(() => selected = null),
              onShowAnimals: () => _showAnimals(selected!),
              onEditBoundary: () => _editBoundary(selected!),
            ),
          ),
      ],
    );
  }

  void _showAnimals(MapArea area) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${area.animalCount} animais em ${area.name}'),
      ),
    );
  }

  void _editBoundary(MapArea area) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: AreaDrawMap(
            controller: AreaDrawController(initialRing: area.ring),
            referenceAreas:
                sampleAreas.where((a) => a.id != area.id).toList(),
            title: 'Editar ${area.name}',
            saveLabel: 'Salvar contorno',
            onCancel: () => Navigator.of(context).pop(),
            onSave: (ring) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Contorno com ${ring.length} pontos · '
                    '${Geodesy.formatArea(Geodesy.polygonAreaHectares(ring))}',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Desenho de um piquete novo, do zero.
class DrawPaddockDemo extends StatefulWidget {
  const DrawPaddockDemo({super.key});

  @override
  State<DrawPaddockDemo> createState() => _DrawPaddockDemoState();
}

class _DrawPaddockDemoState extends State<DrawPaddockDemo> {
  final controller = AreaDrawController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AreaDrawMap(
      controller: controller,
      referenceAreas: sampleAreas,
      initialCenter: propertyCenter,
      initialZoom: 14.5,
      title: 'Novo piquete',
      onSave: (ring) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Piquete de ${Geodesy.formatArea(Geodesy.polygonAreaHectares(ring))} '
              'pronto para salvar',
            ),
          ),
        );
        controller.clear();
      },
    );
  }
}
