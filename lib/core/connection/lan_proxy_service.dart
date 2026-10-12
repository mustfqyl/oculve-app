import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyEndpoint {
  const ProxyEndpoint(this.port, this.username, this.password);
  final int port;
  final String username;
  final String password;
  static Future<ProxyEndpoint> native() async {
    final data = await const MethodChannel('flutter_vless')
        .invokeMapMethod<String, dynamic>('getLocalProxyEndpoint')
        .timeout(const Duration(seconds: 5));
    if (data == null ||
        data['port'] is! int ||
        data['username'] is! String ||
        data['password'] is! String) {
      throw StateError('The VPN is not ready for sharing.');
    }
    return ProxyEndpoint(
      data['port'] as int,
      data['username'] as String,
      data['password'] as String,
    );
  }
}

final lanProxyProvider = ChangeNotifierProvider<LanProxyService>(
  (ref) => LanProxyService(),
);

/// Authenticated TCP relay. Every destination is opened through the active
/// tunnel's managed SOCKS endpoint; it never resolves destinations locally.
class LanProxyService extends ChangeNotifier {
  ServerSocket? _server;
  final Set<Socket> _sockets = {};
  int _generation = 0;
  bool _disposed = false;
  bool get running => _server != null;
  String? get address => _server?.address.address;
  int? get port => _server?.port;
  String? error;
  void reportFailure(String message) {
    error = message;
    if (!_disposed) notifyListeners();
  }

  static bool isPrivateAddress(String value) {
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    return parts[0] == 10 ||
        parts[0] == 192 && parts[1] == 168 ||
        parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31;
  }

  static Future<List<String>> addresses() async => [
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    ))
      if (!RegExp(r'^(utun|tun|tap|lo)').hasMatch(interface.name))
        for (final address in interface.addresses)
          if (isPrivateAddress(address.address)) address.address,
  ];
  Future<void> start({
    required String address,
    required int port,
    required String username,
    required String password,
    required bool Function() ready,
    Future<ProxyEndpoint> Function()? endpoint,
    bool allowLoopbackForTest = false,
  }) async {
    await stop();
    final generation = ++_generation;
    error = null;
    if ((!isPrivateAddress(address) &&
            !(allowLoopbackForTest && address == '127.0.0.1')) ||
        password.length < 12 ||
        !ready()) {
      throw StateError(
        'Connect to the VPN and choose a local network address before sharing.',
      );
    }
    final server = await ServerSocket.bind(address, port, shared: false);
    if (generation != _generation || !ready()) {
      await server.close();
      return;
    }
    _server = server;
    if (!_disposed) notifyListeners();
    server.listen(
      (client) {
        if (generation != _generation ||
            !ready() ||
            _sockets.length >= 64 ||
            (!isPrivateAddress(client.remoteAddress.address) &&
                !allowLoopbackForTest)) {
          client.destroy();
          return;
        }
        _sockets.add(client);
        unawaited(
          _handle(
            client,
            generation,
            username,
            password,
            ready,
            endpoint ?? ProxyEndpoint.native,
          ),
        );
      },
      onError: (_) {
        error = 'LAN sharing stopped. Check your local network.';
        unawaited(stop());
      },
    );
  }

  Future<void> stop() async {
    ++_generation;
    final server = _server;
    _server = null;
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    _sockets.clear();
    if (server != null) {
      await server.close();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _handle(
    Socket client,
    int generation,
    String user,
    String pass,
    bool Function() ready,
    Future<ProxyEndpoint> Function() endpoint,
  ) async {
    final incoming = _ProxyReader(client);
    Socket? upstream;
    _ProxyReader? outgoing;
    bool active() => generation == _generation && ready();
    try {
      final first = (await incoming.take(1))[0];
      late String host;
      late int targetPort;
      List<int>? httpRequest;
      final socks = first == 5;
      if (socks) {
        final methods = await incoming.take((await incoming.take(1))[0]);
        if (!methods.contains(2)) {
          client.add([5, 255]);
          await client.flush();
          return;
        }
        client.add([5, 2]);
        await client.flush();
        if ((await incoming.take(1))[0] != 1) return;
        final suppliedUser = utf8.decode(
          await incoming.take((await incoming.take(1))[0]),
        );
        final suppliedPass = utf8.decode(
          await incoming.take((await incoming.take(1))[0]),
        );
        if (!_equal(suppliedUser, user) || !_equal(suppliedPass, pass)) {
          client.add([1, 1]);
          await client.flush();
          return;
        }
        client.add([1, 0]);
        await client.flush();
        final header = await incoming.take(4);
        if (header[0] != 5 || header[1] != 1 || header[2] != 0) {
          client.add([5, 7, 0, 1, 0, 0, 0, 0, 0, 0]);
          await client.flush();
          return;
        }
        host = await incoming.socksAddress(header[3]);
        final bytes = await incoming.take(2);
        targetPort = bytes[0] * 256 + bytes[1];
      } else {
        final bytes = <int>[first];
        while (bytes.length < 16384 &&
            !(bytes.length >= 4 &&
                bytes.sublist(bytes.length - 4).join(',') == '13,10,13,10')) {
          bytes.addAll(await incoming.take(1));
        }
        if (bytes.length >= 16384) return;
        final lines = latin1.decode(bytes).split('\r\n');
        final auth = lines.firstWhere(
          (line) => line.toLowerCase().startsWith('proxy-authorization:'),
          orElse: () => '',
        );
        final expected = 'Basic ${base64.encode(utf8.encode('$user:$pass'))}';
        if (!_equal(
          auth.substring(auth.isEmpty ? 0 : auth.indexOf(':') + 1).trim(),
          expected,
        )) {
          client.add(
            latin1.encode(
              'HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic realm="Oculve"\r\nConnection: close\r\nContent-Length: 0\r\n\r\n',
            ),
          );
          await client.flush();
          return;
        }
        final request = lines.first.split(' ');
        if (request.length != 3) return;
        final connect = request[0] == 'CONNECT';
        final uri = Uri.tryParse(
          connect ? 'https://${request[1]}' : request[1],
        );
        if (uri == null ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            !connect && uri.scheme != 'http') {
          return;
        }
        host = uri.host;
        targetPort = uri.port;
        if (!connect) {
          final headers = lines
              .skip(1)
              .where(
                (line) =>
                    line.isNotEmpty &&
                    !line.toLowerCase().startsWith('proxy-') &&
                    !line.toLowerCase().startsWith('connection:') &&
                    !line.toLowerCase().startsWith('host:'),
              );
          httpRequest = latin1.encode(
            '${request[0]} ${uri.path.isEmpty ? '/' : uri.path}${uri.hasQuery ? '?${uri.query}' : ''} ${request[2]}\r\nHost: ${uri.authority}\r\n${headers.join('\r\n')}\r\nConnection: close\r\n\r\n',
          );
        }
      }
      if (!active() || targetPort <= 0 || targetPort > 65535) return;
      final local = await endpoint();
      if (!active()) return;
      upstream = await Socket.connect(
        '127.0.0.1',
        local.port,
        timeout: const Duration(seconds: 5),
      );
      _sockets.add(upstream);
      if (!active()) return;
      outgoing = _ProxyReader(upstream);
      upstream.add([5, 1, 2]);
      await upstream.flush();
      if ((await outgoing.take(2)).join(',') != '5,2') return;
      final u = utf8.encode(local.username), p = utf8.encode(local.password);
      upstream.add([1, u.length, ...u, p.length, ...p]);
      await upstream.flush();
      if ((await outgoing.take(2)).join(',') != '1,0') return;
      final target = utf8.encode(host);
      if (target.isEmpty || target.length > 255) return;
      upstream.add([
        5,
        1,
        0,
        3,
        target.length,
        ...target,
        targetPort ~/ 256,
        targetPort % 256,
      ]);
      await upstream.flush();
      final reply = await outgoing.take(4);
      if (reply[0] != 5 || reply[1] != 0) return;
      await outgoing.socksAddress(reply[3]);
      await outgoing.take(2);
      if (!active()) return;
      client.add(
        socks
            ? [5, 0, 0, 1, 0, 0, 0, 0, 0, 0]
            : httpRequest == null
            ? latin1.encode('HTTP/1.1 200 Connection Established\r\n\r\n')
            : const [],
      );
      await client.flush();
      if (httpRequest != null) {
        upstream.add(httpRequest);
        await upstream.flush();
      }
      // A half-close or failure tears down both sides; active sockets are also
      // forcibly closed on disconnect, recovery, settings change or shutdown.
      await Future.any([
        incoming.forward(upstream, active),
        outgoing.forward(client, active),
      ]);
    } catch (_) {
      // Never log proxy headers, destinations or either credential pair.
    } finally {
      client.destroy();
      upstream?.destroy();
      _sockets.remove(client);
      if (upstream != null) _sockets.remove(upstream);
      await incoming.close();
      await outgoing?.close();
    }
  }

  static bool _equal(String a, String b) {
    final left = utf8.encode(a), right = utf8.encode(b);
    int difference = left.length ^ right.length;
    for (var i = 0; i < left.length && i < right.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}

class _ProxyReader {
  _ProxyReader(Socket socket) : _iterator = StreamIterator(socket);
  final StreamIterator<List<int>> _iterator;
  final List<int> _pending = [];
  Future<List<int>> take(int count) async {
    if (count < 0 || count > 16384) {
      throw const FormatException('Invalid proxy frame');
    }
    while (_pending.length < count) {
      if (!await _iterator.moveNext().timeout(const Duration(seconds: 10))) {
        throw const FormatException('Closed proxy frame');
      }
      _pending.addAll(_iterator.current);
      if (_pending.length > 262144) {
        throw const FormatException('Proxy frame too large');
      }
    }
    final result = _pending.sublist(0, count);
    _pending.removeRange(0, count);
    return result;
  }

  Future<String> socksAddress(int type) async {
    if (type == 1) return (await take(4)).join('.');
    if (type == 3) return utf8.decode(await take((await take(1))[0]));
    if (type == 4) {
      return InternetAddress.fromRawAddress(
        Uint8List.fromList(await take(16)),
      ).address;
    }
    throw const FormatException('Unsupported proxy address');
  }

  Future<void> forward(Socket target, bool Function() active) async {
    if (_pending.isNotEmpty && active()) {
      target.add(_pending.toList());
      _pending.clear();
      await target.flush();
    }
    while (active() && await _iterator.moveNext()) {
      target.add(_iterator.current);
      await target.flush();
    }
  }

  Future<void> close() => _iterator.cancel();
}
