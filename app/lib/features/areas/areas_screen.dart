import 'package:flutter/material.dart';
import 'package:traceagro_map/traceagro_map.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import 'area_detail_sheet.dart';
import 'area_editor_screen.dart';
import 'area_mapping.dart';

/// Áreas da propriedade.
///
/// O mapa é a visão principal: a pergunta que o produtor faz antes de qualquer
/// manejo — "onde tem restrição hoje?" — se responde de olhada, pela cor. A
/// lista continua disponível para comparar números lado a lado e para alcançar
/// os piquetes que ainda não têm contorno desenhado.
class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

enum _ViewMode { map, list }

class _AreasScreenState extends State<AreasScreen> {
  final GlobalKey<AreaMapViewState> _mapKey = GlobalKey();

  _ViewMode mode = _ViewMode.map;
  String? selectedId;
  TileSource tiles = TileSource.satellite;
  bool locating = false;

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);

    return MapThemeProvider(
      theme: const MapTheme(),
      child: Scaffold(
        backgroundColor: TaColors.paperDim,
        body: ListenableBuilder(
          listenable: services.herd,
          builder: (context, _) {
            final paddocks = services.herd.paddocks;
            if (paddocks.isEmpty) {
              return _EmptyAreas(onCreate: () => _createPaddock(services));
            }
            return mode == _ViewMode.map
                ? _buildMap(services, paddocks)
                : _buildList(services, paddocks);
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- mapa

  Widget _buildMap(AppServices services, List<Paddock> paddocks) {
    final areas = toMapAreas(paddocks);
    final withoutBoundary = paddocks.where((p) => !p.hasBoundary).length;
    final selected = _selectedPaddock(paddocks);

    return Stack(
      // Sem isto o Stack se dimensiona pelo cabeçalho (o único filho não
      // posicionado) e o mapa fica com a altura dele, escondido atrás.
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: areas.isEmpty
              ? _NoBoundaries(
                  count: paddocks.length,
                  onCreate: () => _createPaddock(services),
                )
              : AreaMapView(
                  key: _mapKey,
                  areas: areas,
                  selectedAreaId: selectedId,
                  tileSource: tiles,
                  onAreaSelected: (area) =>
                      setState(() => selectedId = area.id),
                ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Header(
          paddocks: paddocks,
          mode: mode,
          tiles: tiles,
          onToggleMode: () => setState(() => mode = _ViewMode.list),
          onToggleTiles: areas.isEmpty
              ? null
              : () => setState(() {
                    tiles = tiles == TileSource.satellite
                        ? TileSource.openStreetMap
                        : TileSource.satellite;
                  }),
            onFit: areas.isEmpty
                ? null
                : () => _mapKey.currentState?.fitAllAreas(),
            onLocate: locating ? null : _locateMe,
            locating: locating,
            onCreate: () => _createPaddock(services),
          ),
        ),

        if (areas.isNotEmpty)
          const Positioned(
            right: TaSpace.md,
            top: 128,
            child: AreaLegend(compact: true),
          ),

        // Aviso honesto: piquete sem contorno não aparece no mapa, e o operador
        // precisa saber que está olhando uma visão incompleta.
        if (withoutBoundary > 0 && selected == null && areas.isNotEmpty)
          Positioned(
            left: TaSpace.md,
            right: TaSpace.md,
            bottom: TaSpace.md,
            child: _MissingBoundaryBanner(
              count: withoutBoundary,
              onSeeList: () => setState(() => mode = _ViewMode.list),
            ),
          ),

        if (selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AreaDetailSheet(
              paddock: selected,
              services: services,
              onClose: () => setState(() => selectedId = null),
              onEditBoundary: () => _editBoundary(services, selected),
              onChanged: services.herd.refreshAreas,
            ),
          ),
      ],
    );
  }

  Paddock? _selectedPaddock(List<Paddock> paddocks) {
    if (selectedId == null) return null;
    for (final p in paddocks) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  // ------------------------------------------------------------------ lista

  Widget _buildList(AppServices services, List<Paddock> paddocks) {
    return Column(
      children: [
        _Header(
          paddocks: paddocks,
          mode: mode,
          tiles: tiles,
          onToggleMode: () => setState(() => mode = _ViewMode.map),
          onCreate: () => _createPaddock(services),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: services.herd.refreshAreas,
            child: ListView(
              padding: const EdgeInsets.all(TaSpace.md),
              children: [
                for (final paddock in paddocks)
                  _PaddockCard(
                    paddock: paddock,
                    onTap: () => _openDetail(services, paddock),
                    onDrawBoundary: paddock.hasBoundary
                        ? null
                        : () => _editBoundary(services, paddock),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ ações

  Future<void> _openDetail(AppServices services, Paddock paddock) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MapThemeProvider(
        theme: const MapTheme(),
        child: AreaDetailSheet(
          paddock: paddock,
          services: services,
          onClose: () => Navigator.of(sheetContext).pop(),
          onEditBoundary: () {
            Navigator.of(sheetContext).pop();
            _editBoundary(services, paddock);
          },
          onViewOnMap: paddock.hasBoundary
              ? () {
                  Navigator.of(sheetContext).pop();
                  _focusPaddockOnMap(services, paddock);
                }
              : null,
          onChanged: services.herd.refreshAreas,
        ),
      ),
    );
  }

  void _focusPaddockOnMap(AppServices services, Paddock paddock) {
    MapArea? area;
    for (final candidate in toMapAreas(services.herd.paddocks)) {
      if (candidate.id == paddock.id) {
        area = candidate;
        break;
      }
    }

    setState(() {
      mode = _ViewMode.map;
      selectedId = null;
    });

    if (area == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapKey.currentState?.focusArea(
        area!,
        padding: EdgeInsets.fromLTRB(
          TaSpace.xl,
          MediaQuery.paddingOf(context).top + 136,
          TaSpace.xl,
          TaSpace.xl,
        ),
      );
    });
  }

  /// Centraliza o mapa na posição atual do operador. A câmera só se move em
  /// caso de sucesso — falha (GPS desligado, permissão negada) não mexe no
  /// mapa, só avisa por que não deu.
  Future<void> _locateMe() async {
    setState(() => locating = true);
    final result = await _mapKey.currentState?.locateUser();
    if (!mounted) return;
    setState(() => locating = false);

    if (result is LocateFailure && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _createPaddock(AppServices services) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AreaEditorScreen(
          services: services,
          referenceAreas: toMapAreas(services.herd.paddocks),
        ),
      ),
    );
    if (created == true) {
      await services.herd.refreshAreas();
      if (mounted) setState(() => mode = _ViewMode.map);
    }
  }

  Future<void> _editBoundary(AppServices services, Paddock paddock) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AreaEditorScreen(
          services: services,
          paddock: paddock,
          referenceAreas: toMapAreas(
            services.herd.paddocks.where((p) => p.id != paddock.id),
          ),
        ),
      ),
    );
    if (saved == true) await services.herd.refreshAreas();
  }
}

// --------------------------------------------------------------------- peças

class _Header extends StatelessWidget {
  const _Header({
    required this.paddocks,
    required this.mode,
    required this.tiles,
    required this.onToggleMode,
    required this.onCreate,
    this.onToggleTiles,
    this.onFit,
    this.onLocate,
    this.locating = false,
  });

  final List<Paddock> paddocks;
  final _ViewMode mode;
  final TileSource tiles;
  final VoidCallback onToggleMode;
  final VoidCallback onCreate;
  final VoidCallback? onToggleTiles;
  final VoidCallback? onFit;

  /// Centraliza o mapa na posição atual do operador. Ausente na visão em
  /// lista, onde não há câmera para mover.
  final VoidCallback? onLocate;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final totalHa = paddocks.fold<double>(0, (s, p) => s + p.areaHa);
    final animals = paddocks.fold<int>(0, (s, p) => s + p.animalCount);
    final alerts = paddocks.where((p) => p.hasAlert).length;

    return Container(
      color: TaColors.pasture,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + TaSpace.xs,
        right: TaSpace.xs,
        bottom: TaSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: TaColors.paperInk),
                tooltip: 'Voltar',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Áreas', onDark: true),
                    Text(
                      '${paddocks.length} ${paddocks.length == 1 ? "piquete" : "piquetes"} · '
                      '${totalHa.toStringAsFixed(0)} ha · $animals animais',
                      style: t.titleMedium!.copyWith(color: TaColors.paperInk),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleMode,
                icon: Icon(
                  mode == _ViewMode.map ? Icons.view_list : Icons.map_outlined,
                  color: TaColors.paperInk,
                ),
                tooltip: mode == _ViewMode.map ? 'Ver em lista' : 'Ver no mapa',
              ),
              if (onToggleTiles != null)
                IconButton(
                  onPressed: onToggleTiles,
                  icon: const Icon(Icons.layers_outlined,
                      color: TaColors.paperInk),
                  tooltip: tiles == TileSource.satellite
                      ? 'Ver mapa de ruas'
                      : 'Ver satélite',
                ),
              if (onFit != null)
                IconButton(
                  onPressed: onFit,
                  icon: const Icon(Icons.fit_screen_outlined,
                      color: TaColors.paperInk),
                  tooltip: 'Enquadrar tudo',
                ),
              if (onLocate != null || locating)
                IconButton(
                  onPressed: onLocate,
                  icon: locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: TaColors.tagYellow,
                          ),
                        )
                      : const Icon(Icons.my_location,
                          color: TaColors.paperInk),
                  tooltip: 'Ir para minha localização',
                ),
              IconButton(
                onPressed: onCreate,
                icon: const Icon(Icons.add_location_alt_outlined,
                    color: TaColors.tagYellow),
                tooltip: 'Desenhar piquete',
              ),
            ],
          ),
          if (alerts > 0)
            Padding(
              padding: const EdgeInsets.only(left: TaSpace.md),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 15, color: TaColors.tagYellow),
                  const SizedBox(width: 5),
                  Text(
                    '$alerts ${alerts == 1 ? "área" : "áreas"} com restrição sanitária',
                    style: t.bodySmall!.copyWith(color: TaColors.tagYellow),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaddockCard extends StatelessWidget {
  const _PaddockCard({
    required this.paddock,
    required this.onTap,
    this.onDrawBoundary,
  });

  final Paddock paddock;
  final VoidCallback onTap;
  final VoidCallback? onDrawBoundary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final alert = paddock.hasAlert;

    return Padding(
      padding: const EdgeInsets.only(bottom: TaSpace.sm),
      child: TaCard(
        onTap: onTap,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: alert ? TaColors.clayBg : TaColors.sageBg,
                    borderRadius: const BorderRadius.all(TaRadius.rMd),
                  ),
                  child: Icon(Icons.grass,
                      color: alert ? TaColors.clay : TaColors.sage, size: 28),
                ),
                const SizedBox(width: TaSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paddock.name, style: t.titleMedium),
                      Text(
                        '${paddock.areaHa.toStringAsFixed(1).replaceAll('.', ',')} ha · '
                        '${paddock.animalCount} animais',
                        style: t.bodySmall,
                      ),
                      if (alert)
                        Text(
                          '${paddock.alertCount} com atenção sanitária',
                          style: t.bodySmall!.copyWith(
                            color: TaColors.clay,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  alert ? Icons.warning_amber_rounded : Icons.chevron_right,
                  color: alert ? TaColors.clay : TaColors.inkSoft,
                ),
              ],
            ),
            if (onDrawBoundary != null) ...[
              const Divider(height: TaSpace.lg),
              Row(
                children: [
                  const Icon(Icons.map_outlined,
                      size: 18, color: TaColors.inkSoft),
                  const SizedBox(width: TaSpace.sm),
                  Expanded(
                    child: Text('Sem contorno — não aparece no mapa.',
                        style: t.bodySmall),
                  ),
                  TextButton(
                    onPressed: onDrawBoundary,
                    child: const Text('Desenhar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingBoundaryBanner extends StatelessWidget {
  const _MissingBoundaryBanner({required this.count, required this.onSeeList});

  final int count;
  final VoidCallback onSeeList;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return TaCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: TaColors.inkSoft),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Text(
              count == 1
                  ? '1 piquete ainda não tem contorno e não aparece aqui.'
                  : '$count piquetes ainda não têm contorno e não aparecem aqui.',
              style: t.bodySmall,
            ),
          ),
          TextButton(onPressed: onSeeList, child: const Text('Ver lista')),
        ],
      ),
    );
  }
}

class _NoBoundaries extends StatelessWidget {
  const _NoBoundaries({required this.count, required this.onCreate});

  final int count;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: TaColors.paperDim,
      padding: const EdgeInsets.fromLTRB(
          TaSpace.xl, 140, TaSpace.xl, TaSpace.xl),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: TaColors.inkSoft),
          const SizedBox(height: TaSpace.md),
          Text('Nenhum piquete tem contorno desenhado',
              style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: TaSpace.sm),
          Text(
            count == 1
                ? 'O piquete cadastrado não tem área no mapa. Desenhe o contorno '
                    'para acompanhar lotação e sanidade por local.'
                : 'Os $count piquetes cadastrados não têm área no mapa. Desenhe '
                    'os contornos para acompanhar lotação e sanidade por local.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TaSpace.md),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Desenhar no mapa'),
          ),
        ],
      ),
    );
  }
}

class _EmptyAreas extends StatelessWidget {
  const _EmptyAreas({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(TaSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 52, color: TaColors.inkSoft),
              const SizedBox(height: TaSpace.md),
              Text('Nenhum piquete cadastrado', style: t.titleLarge),
              const SizedBox(height: TaSpace.sm),
              Text(
                'Desenhe as áreas no mapa para acompanhar lotação e alertas '
                'sanitários por local.',
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
              const SizedBox(height: TaSpace.md),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Desenhar primeiro piquete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
