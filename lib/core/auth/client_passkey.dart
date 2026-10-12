import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import '../network/oculve_api.dart';

final clientPasskeyProvider = Provider((ref) => ClientPasskey());

/// Native WebAuthn only. Availability checks never open an authentication UI.
class ClientPasskey {
  ClientPasskey({
    Future<bool> Function()? hasEnrolledBiometrics,
    Future<bool> Function()? supportsPasskeys,
    Future<AuthenticateResponseType> Function(AuthenticateRequestType)?
    authenticate,
    Future<void> Function()? cancel,
    bool? supportedPlatform,
  }) : _hasEnrolledBiometrics = hasEnrolledBiometrics ?? _deviceHasBiometrics,
       _supportsPasskeys = supportsPasskeys ?? _deviceSupportsPasskeys,
       _authenticate = authenticate ?? _nativeAuthenticate,
       _cancel = cancel ?? _nativeCancel,
       _supportedPlatform =
           supportedPlatform ??
           (Platform.isIOS ||
               Platform.isMacOS ||
               Platform.isAndroid ||
               Platform.isWindows);

  final Future<bool> Function() _hasEnrolledBiometrics;
  final Future<bool> Function() _supportsPasskeys;
  final Future<AuthenticateResponseType> Function(AuthenticateRequestType)
  _authenticate;
  final Future<void> Function() _cancel;
  final bool _supportedPlatform;
  static final _authenticator = PasskeyAuthenticator();

  static Future<bool> _deviceHasBiometrics() async {
    if (Platform.isWindows) {
      // local_auth's Windows check also accepts a PIN. Require actual enrolled
      // biometric factors for the current Windows user instead.
      return await const MethodChannel(
            'oculve/passkey_capability',
          ).invokeMethod<bool>('hasEnrolledBiometrics') ??
          false;
    }
    final auth = LocalAuthentication();
    return await auth.canCheckBiometrics &&
        (await auth.getAvailableBiometrics()).isNotEmpty;
  }

  static Future<bool> _deviceSupportsPasskeys() async {
    final availability = _authenticator.getAvailability();
    if (Platform.isAndroid) {
      return (await availability.android()).hasPasskeySupport;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return (await availability.iOS()).hasPasskeySupport;
    }
    if (Platform.isWindows) {
      return (await availability.windows()).hasPasskeySupport;
    }
    return false;
  }

  static Future<AuthenticateResponseType> _nativeAuthenticate(
    AuthenticateRequestType request,
  ) => _authenticator.authenticate(request);
  static Future<void> _nativeCancel() =>
      _authenticator.cancelCurrentAuthenticatorOperation();

  Future<bool> isAvailable() async {
    if (!_supportedPlatform) return false;
    try {
      return await _hasEnrolledBiometrics() && await _supportsPasskeys();
    } catch (_) {
      // Missing plugins, unenrolled sensors and blocked system policy all hide
      // the option. A capability probe must never interfere with TOTP login.
      return false;
    }
  }

  Future<Map<String, dynamic>?> authenticate(
    Map<String, dynamic> options,
  ) async {
    if (!await isAvailable()) {
      throw const ApiFailure(
        'Passkey is unavailable on this device. Use your authenticator code.',
      );
    }
    final request = AuthenticateRequestType.fromJson(
      {...options, 'userVerification': 'required'},
      preferImmediatelyAvailableCredentials: true,
      canBeSecurityKey: false,
    );
    if (request.challenge.isEmpty ||
        request.relyingPartyId.isEmpty ||
        request.allowCredentials == null ||
        request.allowCredentials!.isEmpty) {
      throw const ApiFailure(
        'The service returned an invalid response. Please try again.',
      );
    }
    try {
      return (await _authenticate(request)).toJson();
    } on PasskeyAuthCancelledException {
      return null;
    } on NoCredentialsAvailableException {
      throw const ApiFailure(
        'No matching passkey is available on this device. Use your authenticator code.',
      );
    } on DomainNotAssociatedException {
      throw const ApiFailure(
        'Passkey is not configured for this app yet. Use your authenticator code.',
      );
    } on DeviceNotSupportedException {
      throw const ApiFailure(
        'Passkey is unavailable on this device. Use your authenticator code.',
      );
    } on PasskeyUnsupportedException {
      throw const ApiFailure(
        'Passkey is unavailable on this device. Use your authenticator code.',
      );
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') return null;
      throw const ApiFailure(
        'Passkey verification failed. Try again or use your authenticator code.',
      );
    }
  }

  Future<void> cancel() async {
    try {
      await _cancel();
    } catch (_) {}
  }
}
