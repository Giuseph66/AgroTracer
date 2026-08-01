import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import 'outbox.dart';

const _uuid = Uuid();

/// Tamanho máximo do lote de envio (Doc 8 §3).
const _batchSize = 500;

/// Backoff exponencial com teto (Doc 8 §4). Evento nunca expira.
const _backoff = [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 45),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

enum ConnectivityState { offline, online, syncing }

/// Cliente de sincronização: leva a fila local até `POST /v1/sync/batches` e
/// aplica os veredictos de volta na fila.
///
/// A decisão vinculante é sempre do servidor: o app antecipa validações para a
/// UX, mas quem aceita, rejeita ou marca conflito é a API.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.outbox,
    required this.baseUrl,
    this.tokenProvider,
    this.onUnauthorized,
    http.Client? client,
  })
      : _client = client ?? http.Client();

  final Outbox outbox;
  final String baseUrl;
  final String? Function()? tokenProvider;
  final VoidCallback? onUnauthorized;
  final http.Client _client;

  ConnectivityState _connectivity = ConnectivityState.offline;
  ConnectivityState get connectivity => _connectivity;

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  String? _lastError;
  String? get lastError => _lastError;

  int _failureStreak = 0;
  Timer? _retryTimer;
  bool _inFlight = false;

  /// Desvio entre o relógio do aparelho e o do servidor (Doc 8 §9).
  int _clockSkewMs = 0;
  int get clockSkewMs => _clockSkewMs;

  void start() {
    _retryTimer?.cancel();
    unawaited(_bootstrap());
    _retryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (outbox.pending.isNotEmpty) {
        unawaited(sync());
      } else {
        unawaited(ping());
      }
      // A âncora confirma segundos depois do aceite; sem esta repescagem o
      // evento ficaria eternamente exibido como "enviando" na tela.
      unawaited(refreshAnchors(_awaitingProof));
    });
  }

  void stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _connectivity = ConnectivityState.offline;
    notifyListeners();
  }

  /// Antes de enviar qualquer coisa, alinha a numeração com o servidor.
  /// Enviar primeiro e perguntar depois produziria uma leva inteira de
  /// ORDER_VIOLATION na primeira sincronização após reinstalar o app.
  Future<void> _bootstrap() async {
    await adoptServerSequence();
    await ping();
    await sync();
  }

  Future<void> adoptServerSequence() async {
    try {
      final res = await _client
          .get(
            Uri.parse('$baseUrl/v1/devices/${outbox.identity.deviceId}/sync-state'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (_expireSessionFor(res)) return;
      if (res.statusCode != 200) return;
      final state = jsonDecode(res.body) as Map<String, Object?>;
      final last = state['lastSequence'];
      if (last is int) outbox.adoptServerSequence(last);
    } catch (_) {
      // Sem rede o app continua numerando a partir do que tem localmente;
      // o alinhamento acontece na primeira sincronização bem-sucedida.
    }
  }

  List<OutboxEntry> get _awaitingProof => outbox.entries
      .where((e) =>
          e.state == SyncState.acceptedByApi ||
          e.state == SyncState.pendingBlockchain)
      .toList();

  /// Verificação barata de alcance do servidor. Sem isso o app só descobre que
  /// tem rede quando há algo para enviar, e mostra "offline" com a fila vazia.
  Future<void> ping() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/v1/anchors'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (_expireSessionFor(res)) return;
      if (res.statusCode == 200) {
        _readClockSkew(res.headers);
        _connectivity = ConnectivityState.online;
        _lastError = null;
      } else {
        _connectivity = ConnectivityState.offline;
      }
    } catch (_) {
      _connectivity = ConnectivityState.offline;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _client.close();
    super.dispose();
  }

  /// Envia o que está pendente. Seguro chamar a qualquer momento: nunca há dois
  /// envios simultâneos, e reenviar é inofensivo por idempotência (R23).
  Future<void> sync() async {
    if (_inFlight) return;
    final batch = outbox.pending.take(_batchSize).toList();
    if (batch.isEmpty) return;

    _inFlight = true;
    _connectivity = ConnectivityState.syncing;
    outbox.markSyncing(batch);
    notifyListeners();

    try {
      final body = jsonEncode({
        'batchId': _uuid.v7(),
        'deviceId': outbox.identity.deviceId,
        'clockSkewMs': _clockSkewMs,
        'events': batch.map((e) => e.envelope.toJson()).toList(),
      });

      final res = await _client
          .post(
            Uri.parse('$baseUrl/v1/sync/batches'),
            headers: {'content-type': 'application/json', ..._headers},
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (_expireSessionFor(res)) {
        throw http.ClientException('sessão expirada');
      }
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw http.ClientException('HTTP ${res.statusCode}: ${res.body}');
      }

      _readClockSkew(res.headers);

      final decoded = jsonDecode(res.body) as Map<String, Object?>;
      final results = (decoded['results'] as List).cast<Map<String, Object?>>();
      for (final r in results) {
        outbox.applyVerdict(
          r['eventId'] as String,
          state: _stateFor(r['status'] as String),
          code: r['code'] as String?,
          detail: r['detail'] as String?,
        );
      }

      _failureStreak = 0;
      _lastError = null;
      _lastSyncAt = DateTime.now();
      _connectivity = ConnectivityState.online;

      unawaited(refreshAnchors(batch));
    } catch (err) {
      // Falha de transporte devolve tudo para a fila: nada se perde, nada
      // duplica no reenvio (Doc 8 §4).
      outbox.requeue(batch);
      _failureStreak++;
      _lastError = err.toString();
      _connectivity = ConnectivityState.offline;
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }

  /// Consulta a prova de ancoragem dos eventos aceitos. A âncora é assíncrona:
  /// o evento já vale mesmo antes de confirmar (Doc 8 §5).
  Future<void> refreshAnchors(List<OutboxEntry> batch) async {
    if (batch.isEmpty) return;
    for (final entry in batch) {
      if (entry.state != SyncState.acceptedByApi &&
          entry.state != SyncState.pendingBlockchain) {
        continue;
      }
      try {
        final res = await _client
            .get(
              Uri.parse('$baseUrl/v1/anchors/${entry.eventId}/proof'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));
        if (_expireSessionFor(res)) return;
        if (res.statusCode != 200) continue;
        final anchor = jsonDecode(res.body) as Map<String, Object?>;
        if (anchor['status'] == 'CONFIRMED' && anchor['txId'] != null) {
          outbox.updateAnchor(entry.eventId, anchor['txId'] as String);
        }
      } catch (_) {
        // Prova é informação adicional; falhar aqui não afeta o evento.
      }
    }
    notifyListeners();
  }

  void _readClockSkew(Map<String, String> headers) {
    final dateHeader = headers['date'];
    if (dateHeader == null) return;
    final serverTime = DateTime.tryParse(dateHeader);
    if (serverTime == null) return;
    _clockSkewMs = DateTime.now().toUtc().difference(serverTime).inMilliseconds;
  }

  Map<String, String> get _headers {
    final token = tokenProvider?.call();
    return token == null || token.isEmpty
        ? const {}
        : {'authorization': 'Bearer $token'};
  }

  bool _expireSessionFor(http.Response response) {
    if (response.statusCode != 401) return false;
    onUnauthorized?.call();
    return true;
  }

  Duration get nextRetryDelay =>
      _backoff[_failureStreak.clamp(0, _backoff.length - 1)];

  static SyncState _stateFor(String status) => switch (status) {
        'ACCEPTED' => SyncState.acceptedByApi,
        'CONFLICT' => SyncState.conflict,
        'REJECTED' => SyncState.rejectedByApi,
        _ => SyncState.pendingSync,
      };
}
