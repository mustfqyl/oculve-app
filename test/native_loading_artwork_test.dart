import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/features/auth/presentation/widgets/oculve_veil_artwork.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('native ${dark ? 'dark' : 'light'} artwork matches Flutter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(840, 564);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const key = ValueKey('artwork');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Opacity(
              opacity: .94,
              child: OculveVeilArtwork(
                progress: const AlwaysStoppedAnimation(.5),
                dark: dark,
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(key),
        matchesGoldenFile(
          '../android/app/src/main/res/drawable-nodpi/'
          'launch_veil_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}
