import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Returns false when the user dismisses the native save/share dialog.
Future<bool> exportPrivateText(
  BuildContext context, {
  required String fileName,
  required String contents,
}) async {
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return false;
    await File(location.path).writeAsString(contents, flush: true);
    return true;
  }

  final directory = await Directory.systemTemp.createTemp('oculve-export-');
  try {
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(utf8.encode(contents), flush: true);
    if (!context.mounted) return false;
    final box = context.findRenderObject() as RenderBox?;
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    return result.status == ShareResultStatus.success;
  } finally {
    await directory.delete(recursive: true);
  }
}

String accessCodeFileContents(String code) =>
    'OCULVE ACCESS CODE\n------------------------\nCode: $code\n\n'
    'Keep this file private. Anyone with the code can access your account.\n';
