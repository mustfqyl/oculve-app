import 'dart:io';

import 'package:flutter/material.dart';

class OculveWordmark extends StatelessWidget {
  const OculveWordmark({
    super.key,
    required this.color,
    this.alignment = Alignment.centerLeft,
  });

  final Color color;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 108,
    height: 24,
    child: Align(
      alignment: alignment,
      child: Text(
        'oculve',
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontFamily: Platform.isMacOS || Platform.isIOS
              ? '.AppleSystemUIFont'
              : Platform.isWindows
              ? 'Segoe UI'
              : 'sans-serif',
          fontSize: 22.8,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
          height: 1,
        ),
      ),
    ),
  );
}
