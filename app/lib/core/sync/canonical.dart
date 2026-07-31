import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Serialização canônica JCS (RFC 8785), simplificada para os tipos usados nos
/// payloads de evento: objetos com chaves ordenadas, sem espaços, números na
/// forma mais curta que faz round-trip.
///
/// Gêmea de `api/src/events/canonical.ts`. Se as duas divergirem, todo evento
/// do app é rejeitado com ERR-EVT-HASH — por isso os vetores de teste são os
/// mesmos dos dois lados (`test/canonical_test.dart`).
String canonicalJson(Object? value) {
  if (value == null) return 'null';

  if (value is List) {
    return '[${value.map(canonicalJson).join(',')}]';
  }

  if (value is Map) {
    final keys = value.keys.map((k) => k as String).toList()..sort();
    final entries = keys
        .where((k) => value[k] != null || _explicitNull(value, k))
        .map((k) => '${jsonEncode(k)}:${canonicalJson(value[k])}');
    return '{${entries.join(',')}}';
  }

  if (value is num) {
    if (value is double && (value.isNaN || value.isInfinite)) {
      throw ArgumentError('canonicalJson: número não finito não é serializável');
    }
    // Inteiro representável sai sem ".0" — é assim que JSON.stringify emite no
    // lado TypeScript, e o hash precisa bater byte a byte.
    if (value is double && value == value.truncateToDouble() &&
        value.abs() < 1e21) {
      return value.toInt().toString();
    }
    return jsonEncode(value);
  }

  return jsonEncode(value);
}

/// Um `null` explícito no mapa é conteúdo; ausência é ausência. Ambos os lados
/// omitem `undefined`/ausente e mantêm `null`.
bool _explicitNull(Map<dynamic, dynamic> map, String key) =>
    map.containsKey(key);

String payloadHash(Object? payload) =>
    sha256.convert(utf8.encode(canonicalJson(payload))).toString();
