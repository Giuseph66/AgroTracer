import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent;

/// Captura de leitor RFID USB físico em modo teclado (HID): o leitor manda
/// os dígitos do brinco e, dependendo do modelo, fecha com Enter — mas nem
/// todo leitor manda essa tecla de fechamento (confirmado com hardware real:
/// chega uma rajada de dígitos e para, sem terminador). Por isso a leitura
/// fecha por Enter **ou** por inatividade (sem tecla nova por 250ms).
///
/// Não exige plugin nativo nem permissão de USB: um leitor HID já entrega
/// as teclas pelo pipeline de teclado normal do Android: só precisa de um
/// [FocusNode] sempre com foco pra captar.
///
/// Uso: aplique a um `State`, dê `focusNode: rfidFocusNode` e
/// `onKeyEvent: onRfidKeyEvent` a um `Focus` envolvendo a tela, implemente
/// [onRfidScan], e chame [disposeRfidCapture] no `dispose()`.
mixin RfidHardwareCapture<T extends StatefulWidget> on State<T> {
  final FocusNode rfidFocusNode = FocusNode(debugLabel: 'rfid-hardware-capture');
  final StringBuffer _buffer = StringBuffer();
  Timer? _idleTimer;

  /// Um código completo chegou do leitor físico.
  void onRfidScan(String code);

  /// Enquanto true, teclas do leitor são ignoradas (ex.: tela já mostrando
  /// o resultado de uma leitura anterior, aguardando o operador confirmar).
  bool get rfidCapturePaused => false;

  KeyEventResult onRfidKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (rfidCapturePaused) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _idleTimer?.cancel();
      _finalize();
      return KeyEventResult.handled;
    }
    final char = event.character?.trim().isNotEmpty == true
        ? event.character
        // Leitor genérico (HID sem boot protocol) pode não popular
        // `character` para as teclas de dígito — cai para a tecla lógica.
        : _digitFor(key);
    if (char != null && char.isNotEmpty) {
      _buffer.write(char);
      _idleTimer?.cancel();
      _idleTimer = Timer(const Duration(milliseconds: 250), _finalize);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _finalize() {
    final code = _buffer.toString().trim();
    _buffer.clear();
    if (code.isEmpty || !mounted) return;
    onRfidScan(code);
  }

  /// Pede foco pro leitor de volta. Sempre adiado pro próximo frame — pedir
  /// no mesmo frame em que uma folha/diálogo com campo de texto ainda está
  /// sendo desmontada corre contra a limpeza de foco do próprio Flutter e
  /// derruba o app com `_dependents.isEmpty` (falha real, reproduzida ao
  /// cancelar o cadastro de animal com um campo focado).
  void requestRfidFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) rfidFocusNode.requestFocus();
    });
  }

  void disposeRfidCapture() {
    _idleTimer?.cancel();
    rfidFocusNode.dispose();
  }

  static String? _digitFor(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.digit0 || LogicalKeyboardKey.numpad0 => '0',
    LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => '1',
    LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => '2',
    LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => '3',
    LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => '4',
    LogicalKeyboardKey.digit5 || LogicalKeyboardKey.numpad5 => '5',
    LogicalKeyboardKey.digit6 || LogicalKeyboardKey.numpad6 => '6',
    LogicalKeyboardKey.digit7 || LogicalKeyboardKey.numpad7 => '7',
    LogicalKeyboardKey.digit8 || LogicalKeyboardKey.numpad8 => '8',
    LogicalKeyboardKey.digit9 || LogicalKeyboardKey.numpad9 => '9',
    _ => null,
  };
}
