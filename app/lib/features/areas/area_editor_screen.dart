import 'package:flutter/material.dart';
import 'package:traceagro_map/traceagro_map.dart';

import '../../core/services.dart';
import '../../core/sync/event_envelope.dart';
import '../../core/theme/tokens.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import 'area_mapping.dart';

/// Desenha ou redesenha o contorno de um piquete.
///
/// Substitui a digitação de latitude e longitude: ninguém no curral sabe a
/// coordenada de um canto de cerca, mas todo mundo reconhece a cerca na
/// imagem de satélite. O operador toca nos cantos e o app mede.
///
/// Sem `paddock`, cria um piquete novo (pede o nome ao salvar). Com `paddock`,
/// redesenha o contorno — o servidor arquiva a versão anterior.
class AreaEditorScreen extends StatefulWidget {
  const AreaEditorScreen({
    super.key,
    required this.services,
    this.paddock,
    this.referenceAreas = const [],
  });

  final AppServices services;
  final Paddock? paddock;
  final List<MapArea> referenceAreas;

  bool get isEditing => paddock != null;

  @override
  State<AreaEditorScreen> createState() => _AreaEditorScreenState();
}

class _AreaEditorScreenState extends State<AreaEditorScreen> {
  late final AreaDrawController controller;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.paddock?.boundary ?? const <List<double>>[];
    controller = AreaDrawController(
      initialRing: existing.map((c) => GeoPoint(c[1], c[0])).toList(),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Centro inicial: o próprio contorno quando há um, senão a vizinhança já
  /// desenhada. Abrir o mapa longe da propriedade obrigaria o operador a
  /// procurar a fazenda antes de conseguir desenhar.
  GeoPoint? get _initialCenter {
    if (widget.paddock?.hasBoundary ?? false) {
      final ring = widget.paddock!.boundary;
      return Geodesy.center(ring.map((c) => GeoPoint(c[1], c[0])).toList());
    }
    if (widget.referenceAreas.isNotEmpty) {
      return Geodesy.center(
        widget.referenceAreas.expand((a) => a.ring).toList(),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MapThemeProvider(
      theme: const MapTheme(),
      child: Scaffold(
        backgroundColor: TaColors.pasture,
        body: Stack(
          children: [
            AreaDrawMap(
              controller: controller,
              referenceAreas: widget.referenceAreas,
              initialCenter: _initialCenter,
              initialZoom: widget.isEditing ? 15.5 : 14.5,
              title: widget.isEditing
                  ? 'Redesenhar ${widget.paddock!.name}'
                  : 'Novo piquete',
              saveLabel: widget.isEditing ? 'Salvar contorno' : 'Continuar',
              onCancel: saving ? null : () => _confirmExit(),
              onSave: saving ? null : _handleSave,
            ),
            if (saving)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x88122015),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Sair com desenho na tela pede confirmação: o contorno só existe na
  /// memória e some sem aviso se a tela fechar.
  Future<void> _confirmExit() async {
    if (controller.isEmpty) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar desenho?'),
        content: const Text(
          'O contorno marcado até aqui não foi salvo e será perdido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar desenhando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TaColors.clay,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _handleSave(List<GeoPoint> ring) async {
    final name = widget.isEditing
        ? widget.paddock!.name
        : await _askName(Geodesy.polygonAreaHectares(ring));

    if (name == null || !mounted) return;

    setState(() => saving = true);
    try {
      if (widget.isEditing) {
        await widget.services.api.updatePaddockBoundary(
          DevIdentity.propertyId,
          widget.paddock!.id,
          ringToApi(ring),
        );
      } else {
        await widget.services.api.createPaddock(
          DevIdentity.propertyId,
          name,
          ringToApi(ring),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on PaddockBoundaryRejected catch (err) {
      _reportFailure(err.message);
    } catch (_) {
      _reportFailure(
        'Não foi possível salvar agora. O desenho continua aqui — '
        'tente de novo quando houver conexão.',
      );
    }
  }

  void _reportFailure(String message) {
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: TaColors.clay,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Pede o nome só no fim: interromper para digitar antes de desenhar tira o
  /// operador do mapa sem necessidade.
  Future<String?> _askName(double hectares) async {
    final field = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nome do piquete'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Área medida: ${Geodesy.formatArea(hectares)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: TaSpace.md),
              TextFormField(
                controller: field,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Recria 12',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Dê um nome para reconhecer o piquete depois'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Voltar ao desenho'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(field.text.trim());
            },
            child: const Text('Salvar piquete'),
          ),
        ],
      ),
    );

    field.dispose();
    return name;
  }
}
