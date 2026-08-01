import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/geo_point.dart';
import '../theme/map_theme.dart';

/// Posição do operador no mapa: círculo de precisão (em metros reais, escala
/// com o zoom) e um ponto central fixo — o padrão que qualquer app de mapa já
/// ensinou o usuário a reconhecer como "você está aqui".
///
/// Compartilhado entre [AreaMapView] (visualização) e [AreaDrawMap]
/// (desenho): o operador precisa se localizar nos dois contextos, e o
/// desenho é onde mais importa — é quando ele está andando a cerca.
class UserLocationLayer extends StatelessWidget {
  const UserLocationLayer({
    super.key,
    required this.position,
    required this.accuracyMeters,
    required this.theme,
  });

  final GeoPoint position;
  final double? accuracyMeters;
  final MapTheme theme;

  @override
  Widget build(BuildContext context) {
    final point = position.toLatLng();
    return Stack(
      children: [
        if (accuracyMeters != null && accuracyMeters! > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: point,
                radius: accuracyMeters!,
                useRadiusInMeter: true,
                color: theme.sky.withValues(alpha: 0.15),
                borderColor: theme.sky.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.sky,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.paper, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: theme.stamp.withValues(alpha: 0.35),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
