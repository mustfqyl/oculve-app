import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Render the same flag on every platform instead of relying on emoji fonts.
class CountryIcon extends StatelessWidget {
  const CountryIcon({super.key, required this.flag, this.size = 23});

  final String? flag;
  final double size;

  String? get _countryCode {
    final runes = flag?.runes.toList() ?? const <int>[];
    if (runes.length != 2 ||
        runes.any((rune) => rune < 0x1F1E6 || rune > 0x1F1FF)) {
      return null;
    }
    return String.fromCharCodes(runes.map((rune) => rune - 0x1F1E6 + 0x61));
  }

  @override
  Widget build(BuildContext context) {
    final code = _countryCode;
    if (code == null) return _fallback(context);
    return SvgPicture.asset(
      'assets/flags/$code.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) => Icon(
    Icons.public,
    size: size * .85,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
