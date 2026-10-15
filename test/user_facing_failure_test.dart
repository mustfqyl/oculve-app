import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/models/user_facing_failure.dart';

void main() {
  test('Windows permission denial explains how to enable the VPN', () {
    final message = UserFacingFailure.permissionDeniedMessage(
      isWindows: true,
      isLinux: false,
    );

    expect(message, UserFacingFailure.windowsAdministratorRequiredMessage);
    expect(
      UserFacingFailure.message(StateError(message)),
      UserFacingFailure.windowsAdministratorRequiredMessage,
    );
    expect(
      AppStrings.translate(message, 'tr'),
      'Windows’ta VPN tüneli için yönetici izni gerekir. Oculve’yi kapatıp “Yönetici olarak çalıştır” seçeneğiyle yeniden aç.',
    );
    expect(
      AppStrings.translate(message, 'es'),
      'Windows necesita permisos de administrador para crear el túnel VPN. Cierra Oculve y vuelve a abrirlo con “Ejecutar como administrador”.',
    );
    expect(
      UserFacingFailure.permissionDeniedMessage(
        isWindows: false,
        isLinux: true,
      ),
      UserFacingFailure.linuxSupportMissingMessage,
    );
    expect(
      UserFacingFailure.permissionDeniedMessage(
        isWindows: false,
        isLinux: false,
      ),
      'VPN permission was not granted.',
    );
    expect(
      UserFacingFailure.requiresPlatformSetup(
        error: StateError(message),
        isWindows: true,
        isLinux: false,
      ),
      isTrue,
    );
    expect(
      UserFacingFailure.requiresPlatformSetup(
        error: StateError(UserFacingFailure.linuxSupportMissingMessage),
        isWindows: false,
        isLinux: true,
      ),
      isTrue,
    );
    expect(
      UserFacingFailure.requiresPlatformSetup(
        error: StateError(message),
        isWindows: false,
        isLinux: true,
      ),
      isFalse,
    );
  });

  test('missing Linux VPN support gives a localized setup instruction', () {
    final error = StateError(UserFacingFailure.linuxSupportMissingMessage);

    expect(
      UserFacingFailure.message(error),
      UserFacingFailure.linuxSupportMissingMessage,
    );
    expect(
      AppStrings.translate(UserFacingFailure.message(error), 'tr'),
      'Linux VPN desteği yüklü değil. Bağlanmadan önce Linux kurulum adımlarını tamamlayın.',
    );
    expect(
      AppStrings.translate(UserFacingFailure.message(error), 'es'),
      'El soporte VPN de Linux no está instalado. Completa los pasos de configuración de Linux antes de conectar.',
    );
  });
}
