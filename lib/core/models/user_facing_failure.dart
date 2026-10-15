import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../network/oculve_api.dart';

/// Only reviewed messages can cross from exceptions into the interface.
/// Server payloads, native exceptions and stack traces remain diagnostic data.
class UserFacingFailure {
  UserFacingFailure._();

  static const linuxSupportMissingMessage =
      'Linux VPN support is not installed. Finish the Linux setup steps before connecting.';
  static const windowsAdministratorRequiredMessage =
      'Windows needs administrator permission to create the VPN tunnel. Close Oculve and reopen it with Run as administrator.';

  static String permissionDeniedMessage({
    required bool isWindows,
    required bool isLinux,
  }) => switch ((isWindows, isLinux)) {
    (true, _) => windowsAdministratorRequiredMessage,
    (_, true) => linuxSupportMissingMessage,
    _ => 'VPN permission was not granted.',
  };

  static bool requiresPlatformSetup({
    required Object error,
    required bool isWindows,
    required bool isLinux,
  }) {
    if (error is! StateError) return false;
    final message = error.message.toString();
    return (isWindows && message == windowsAdministratorRequiredMessage) ||
        (isLinux && message == linuxSupportMissingMessage);
  }

  static const _messages = {
    'Passkey is unavailable on this device. Use your authenticator code.',
    'No matching passkey is available on this device. Use your authenticator code.',
    'Passkey is not configured for this app yet. Use your authenticator code.',
    'Passkey verification failed. Try again or use your authenticator code.',
    'Something went wrong. Please try again.',
    'The service returned an invalid response. Please try again.',
    'The request could not be completed. Please try again.',
    'The service is temporarily unavailable. Please try again.',
    'Could not reach the service securely. Check your connection.',
    'Could not generate an access code.',
    'Your access code or session is invalid. Please sign in again.',
    'Access denied. Check your account status.',
    'Subscription access was rejected. Your device limit may be reached.',
    'Could not read your device identity. Please restart the app and try again.',
    'Your subscription is not active.',
    'No compatible servers are available.',
    'VPN permission was not granted.',
    linuxSupportMissingMessage,
    windowsAdministratorRequiredMessage,
    'The VPN profile is incompatible. Refresh your server list or try another location.',
    'Could not resolve the VPN server. Check your internet connection and try again.',
    'Could not securely save the VPN profile. Restart the app and try again.',
    'Android could not start the VPN. Keep the app open and try again.',
    'Complete the Android permission prompt before trying again.',
    'The VPN runtime failed. Check permissions and connection settings.',
    'VPN disconnected. Reconnect to protect your traffic.',
    'The VPN could not be stopped. Check the system VPN settings.',
    'Connection timed out. Please try another location.',
    'Could not establish the VPN. Check your account, VPN permission and server availability.',
    'Could not establish the VPN. Please try again.',
    'Choose a place to save your code before continuing.',
    'Your account was created, but server setup is still finishing. Sign in again shortly.',
    'Choose a supported DNS provider.',
    'Enter a valid HTTPS DNS URL without credentials or a fragment.',
    'Enter valid numeric ranges for fragment length, delay and splits.',
    'Add at most 32 bypass domains.',
    'Choose at most 100 apps to bypass.',
  };

  static String message(Object error, {String? fallback}) {
    final safeFallback = fallback ?? 'Something went wrong. Please try again.';
    if (error is PlatformException) {
      // Only fixed native codes are rendered, never configuration or server data.
      return switch (error.code) {
        'INVALID_CONFIG' || 'NATIVE_VALIDATION_FAILED' =>
          'The VPN profile is incompatible. Refresh your server list or try another location.',
        'ENDPOINT_RESOLUTION_FAILED' =>
          'Could not resolve the VPN server. Check your internet connection and try again.',
        'PROFILE_SAVE_FAILED' =>
          'Could not securely save the VPN profile. Restart the app and try again.',
        'SERVICE_START_FAILED' || 'NO_ACTIVITY' =>
          'Android could not start the VPN. Keep the app open and try again.',
        'PERMISSION_REQUEST_IN_PROGRESS' =>
          'Complete the Android permission prompt before trying again.',
        'VPN_PERMISSION_REQUIRED' => 'VPN permission was not granted.',
        _ => safeFallback,
      };
    }
    if (error is SocketException || error is TimeoutException) {
      return 'Could not connect to the service. Check your internet connection and try again.';
    }
    if (error is ApiFailure) {
      if (error.status == 429) {
        return 'Too many attempts. Please wait and try again.';
      }
      if ((error.status ?? 0) >= 500) {
        return 'The service is temporarily unavailable. Please try again.';
      }
      final detail = error.message.trim();
      if (_messages.contains(detail)) return detail;
      return switch (error.status) {
        401 => 'Your access code or session is invalid. Please sign in again.',
        403 => 'Access denied. Check your account status.',
        400 =>
          'The service rejected this request. Check your details and try again.',
        _ => safeFallback,
      };
    }
    final detail = switch (error) {
      String value => value.trim(),
      FormatException value => value.message.trim(),
      StateError value => value.message.toString().trim(),
      _ => '',
    };
    if (_messages.contains(detail)) return detail;
    if (error is FormatException) {
      if (detail.startsWith('Invalid domain:')) {
        return 'Enter valid website domains, such as example.com.';
      }
      return fallback ??
          'The service returned an invalid response. Please try again.';
    }
    return safeFallback;
  }
}
