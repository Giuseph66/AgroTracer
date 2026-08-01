// This is the browser adapter selected only for Flutter Web builds.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<bool> downloadBytes(
  String filename,
  List<int> bytes,
  String mimeType,
) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  scheduleMicrotask(() => html.Url.revokeObjectUrl(url));
  return true;
}
