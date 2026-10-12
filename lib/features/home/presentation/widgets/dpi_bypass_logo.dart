import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DpiBypassLogo extends StatelessWidget {
  const DpiBypassLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/dpi_bypass_packet.svg',
    width: size,
    height: size,
  );
}
