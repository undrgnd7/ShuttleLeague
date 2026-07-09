import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Native platforms (Android/iOS/desktop): open the OS share sheet.
Future<void> saveOrShareBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'image/png',
  String? shareText,
}) async {
  await Share.shareXFiles(
    [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
    text: shareText,
  );
}
