import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_app/core/sync/canonical.dart';

/// Paridade Dart ↔ TypeScript.
///
/// O app calcula o hash do payload; a API recalcula e compara. Se as duas
/// implementações divergirem em um único byte, todo evento vindo do campo é
/// rejeitado com ERR-EVT-HASH. Por isso os dois lados leem o mesmo arquivo de
/// vetores, gerado por `api/test/generate-vectors.js`.
void main() {
  final file = File('../api/test/vectors.json');
  final vectors = (jsonDecode(file.readAsStringSync()) as Map)['vectors']
      as List<dynamic>;

  test('vetores compartilhados existem', () {
    expect(vectors, isNotEmpty);
  });

  for (final raw in vectors) {
    final v = raw as Map<String, Object?>;
    final name = v['name'] as String;

    test('canonicalização: $name', () {
      expect(canonicalJson(v['value']), v['canonical']);
    });

    test('hash: $name', () {
      expect(payloadHash(v['value']), v['sha256']);
    });
  }

  test('ordem das chaves de entrada não muda o hash', () {
    final a = {'weightKg': 301.5, 'weightSource': 'SCALE', 'scaleId': 'AT-2'};
    final b = {'scaleId': 'AT-2', 'weightSource': 'SCALE', 'weightKg': 301.5};
    expect(payloadHash(a), payloadHash(b));
  });

  test('inteiro em double sai sem casa decimal, como no JavaScript', () {
    expect(canonicalJson({'weightKg': 300.0}), '{"weightKg":300}');
    expect(canonicalJson({'weightKg': 300}), '{"weightKg":300}');
  });

  test('número não finito não é serializável', () {
    expect(() => canonicalJson({'x': double.infinity}), throwsArgumentError);
    expect(() => canonicalJson({'x': double.nan}), throwsArgumentError);
  });
}
