import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Opens the share sheet with [content] as a text file named [name]. The
/// user chooses where it goes; nothing is sent anywhere otherwise.
Future<void> shareTextFile(
  String content, {
  required String name,
  String mimeType = 'application/json',
}) => SharePlus.instance.share(
  ShareParams(
    files: [
      XFile.fromData(
        Uint8List.fromList(utf8.encode(content)),
        mimeType: mimeType,
        name: name,
      ),
    ],
    fileNameOverrides: [name],
  ),
);
