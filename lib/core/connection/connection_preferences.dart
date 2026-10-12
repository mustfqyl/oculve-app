import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionPreferences {
  const ConnectionPreferences({
    this.reconnect = true,
    this.shareLan = false,
    this.port = 10809,
    this.username = 'oculve',
    this.address = '',
  });
  final bool reconnect;
  final bool shareLan;
  final int port;
  final String username;
  final String address;
  static const _storage = FlutterSecureStorage();
  static const _passwordKey = 'oculve.lan.proxy.password.v1';
  static Future<ConnectionPreferences> read() async {
    final p = await SharedPreferences.getInstance();
    return ConnectionPreferences(
      reconnect: p.getBool('connection.reconnect') ?? true,
      shareLan: p.getBool('connection.lan') ?? false,
      port: p.getInt('connection.lan.port') ?? 10809,
      username: p.getString('connection.lan.user') ?? 'oculve',
      address: p.getString('connection.lan.address') ?? '',
    );
  }

  static Future<void> setReconnect(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        'connection.reconnect',
        value,
      );
  static Future<void> saveLan({
    required bool enabled,
    required int port,
    required String username,
    required String address,
    required String password,
  }) async {
    if (port < 1024 ||
        port > 65535 ||
        username.isEmpty ||
        username.length > 64 ||
        !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username) ||
        password.length < 12 ||
        password.length > 64 ||
        !RegExp(r'^[\x21-\x7E]+$').hasMatch(password)) {
      throw const FormatException(
        'Use a port from 1024 to 65535 and a password of at least 12 characters.',
      );
    }
    // Write the secret first: a failed Keychain write must not enable sharing.
    await _storage.write(key: _passwordKey, value: password);
    final p = await SharedPreferences.getInstance();
    await p.setInt('connection.lan.port', port);
    await p.setString('connection.lan.user', username);
    await p.setString('connection.lan.address', address);
    await p.setBool('connection.lan', enabled);
  }

  static Future<void> disableLan() async =>
      (await SharedPreferences.getInstance()).setBool('connection.lan', false);
  static Future<String> password() async =>
      await _storage.read(key: _passwordKey) ?? '';
  static String newPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(
      20,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
