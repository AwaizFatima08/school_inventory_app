import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves [content] through the browser's download mechanism. The UTF-8 BOM
/// makes Excel read non-English names correctly.
void downloadTextFile(String fileName, String content) {
  final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}
