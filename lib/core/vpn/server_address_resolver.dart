import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class ServerAddressResolutionSettings {
  const ServerAddressResolutionSettings({
    required this.dnsEndpoint,
    this.bootstrapAddress,
  });

  final Uri dnsEndpoint;
  final InternetAddress? bootstrapAddress;

  static const _keys = {
    'server-address-resolve-enable',
    'server-address-resolve-dns-domain',
    'server-address-resolve-dns-ip',
  };

  static ServerAddressResolutionSettings? fromSubscription({
    String body = '',
    Map<String, String> headers = const {},
  }) {
    final values = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key.trim().toLowerCase();
      if (_keys.contains(key)) values[key] = entry.value.trim();
    }
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf(':');
      if (separator < 2) continue;
      final key = trimmed.substring(1, separator).trim().toLowerCase();
      if (_keys.contains(key) && !values.containsKey(key)) {
        values[key] = trimmed.substring(separator + 1).trim();
      }
    }

    final enabled = switch (values['server-address-resolve-enable']
        ?.toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      _ => false,
    };
    if (!enabled) return null;

    final endpoint = Uri.tryParse(
      values['server-address-resolve-dns-domain'] ?? '',
    );
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        !endpoint.hasAuthority ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment ||
        endpoint.path.isEmpty) {
      return null;
    }

    final rawBootstrap = values['server-address-resolve-dns-ip'];
    final bootstrap = rawBootstrap == null || rawBootstrap.isEmpty
        ? null
        : InternetAddress.tryParse(rawBootstrap);
    if (rawBootstrap != null && bootstrap == null) return null;

    return ServerAddressResolutionSettings(
      dnsEndpoint: endpoint,
      bootstrapAddress: bootstrap,
    );
  }
}

typedef DnsOverHttpsExchange =
    Future<List<int>> Function(
      Uri endpoint,
      List<int> dnsMessage,
      InternetAddress? bootstrapAddress,
    );

/// Uses the resolver explicitly supplied by a subscription. When no resolver
/// is configured, callers should keep using the platform's normal DNS lookup.
class DohServerAddressResolver {
  DohServerAddressResolver({DnsOverHttpsExchange? exchange})
    : _exchange = exchange ?? _exchangeOverHttps;

  final DnsOverHttpsExchange _exchange;

  Future<List<InternetAddress>> lookup(
    String host,
    ServerAddressResolutionSettings settings,
  ) async {
    if (InternetAddress.tryParse(host) case final address?) return [address];

    final id = Random.secure().nextInt(0x10000);
    final ipv4Message = _query(host, 1, id);
    final ipv6Id = (id + 1) & 0xffff;
    final ipv6Message = _query(host, 28, ipv6Id);
    final responses = await Future.wait([
      _exchange(
        settings.dnsEndpoint,
        ipv4Message,
        settings.bootstrapAddress,
      ).timeout(const Duration(seconds: 4)),
      _exchange(
        settings.dnsEndpoint,
        ipv6Message,
        settings.bootstrapAddress,
      ).timeout(const Duration(seconds: 4)),
    ]);
    final addresses = <String, InternetAddress>{};
    for (final result in [
      ..._answers(responses[0], id, 1),
      ..._answers(responses[1], ipv6Id, 28),
    ]) {
      addresses[result.address] = result;
    }
    return addresses.values.toList(growable: false);
  }

  static List<int> _query(String host, int type, int id) {
    final labels = host.toLowerCase().split('.');
    if (host.isEmpty ||
        labels.any((label) => label.isEmpty || label.length > 63)) {
      throw const FormatException('The server domain is invalid.');
    }
    final name = <int>[];
    for (final label in labels) {
      final bytes = ascii.encode(label);
      name
        ..add(bytes.length)
        ..addAll(bytes);
    }
    name.add(0);
    return [
      id >> 8,
      id & 0xff,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      ...name,
      0x00,
      type,
      0x00,
      0x01,
    ];
  }

  static List<InternetAddress> _answers(List<int> bytes, int id, int type) {
    if (bytes.length < 12) return const [];
    final data = Uint8List.fromList(bytes);
    final view = ByteData.sublistView(data);
    if (view.getUint16(0) != id) return const [];
    final flags = view.getUint16(2);
    if ((flags & 0x8000) == 0 || (flags & 0x000f) != 0) return const [];

    final questionCount = view.getUint16(4);
    final answerCount = view.getUint16(6);
    var offset = 12;
    for (var index = 0; index < questionCount; index++) {
      offset = _skipName(data, offset);
      if (offset + 4 > data.length) return const [];
      offset += 4;
    }

    final results = <InternetAddress>[];
    for (var index = 0; index < answerCount; index++) {
      offset = _skipName(data, offset);
      if (offset + 10 > data.length) return results;
      final recordType = view.getUint16(offset);
      final recordClass = view.getUint16(offset + 2);
      final length = view.getUint16(offset + 8);
      final dataOffset = offset + 10;
      if (dataOffset + length > data.length) return results;
      if (recordClass == 1 && recordType == type) {
        if ((type == 1 && length == 4) || (type == 28 && length == 16)) {
          results.add(
            InternetAddress.fromRawAddress(
              Uint8List.sublistView(data, dataOffset, dataOffset + length),
            ),
          );
        }
      }
      offset = dataOffset + length;
    }
    return results;
  }

  static int _skipName(Uint8List data, int offset) {
    var cursor = offset;
    while (cursor < data.length) {
      final length = data[cursor];
      if ((length & 0xc0) == 0xc0) {
        if (cursor + 1 >= data.length) return data.length;
        return cursor + 2;
      }
      if ((length & 0xc0) != 0) return data.length;
      cursor++;
      if (length == 0) return cursor;
      cursor += length;
    }
    return data.length;
  }

  static Future<List<int>> _exchangeOverHttps(
    Uri endpoint,
    List<int> dnsMessage,
    InternetAddress? bootstrapAddress,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    if (bootstrapAddress != null) {
      client.connectionFactory = (uri, proxyHost, proxyPort) {
        final useBootstrap =
            proxyHost == null &&
            uri.host.toLowerCase() == endpoint.host.toLowerCase();
        final target = useBootstrap ? bootstrapAddress : proxyHost ?? uri.host;
        final port = proxyHost == null ? uri.port : proxyPort ?? uri.port;
        return Socket.startConnect(target, port);
      };
    }

    try {
      return await (() async {
        final request = await client.postUrl(endpoint);
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/dns-message',
        );
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/dns-message',
        );
        request.add(dnsMessage);
        final response = await request.close().timeout(
          const Duration(seconds: 4),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const HttpException('DoH resolver returned an error.');
        }
        final result = <int>[];
        await for (final chunk in response.timeout(
          const Duration(seconds: 4),
        )) {
          if (result.length + chunk.length > 16 * 1024) {
            throw const HttpException('DoH response is too large.');
          }
          result.addAll(chunk);
        }
        return result;
      })().timeout(const Duration(seconds: 4));
    } finally {
      client.close(force: true);
    }
  }
}
