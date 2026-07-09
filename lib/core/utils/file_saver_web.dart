import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: the Web Share API doesn't support file attachments in most desktop
/// browsers (only some mobile ones), so a direct browser download works
/// everywhere instead.
Future<void> saveOrShareBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'image/png',
  String? shareText,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
