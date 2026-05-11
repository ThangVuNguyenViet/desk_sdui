import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'ir_fetcher.dart';

typedef HttpGet = Future<Uint8List> Function(Uri uri);

class RemoteIrFetcher implements IrFetcher {
  RemoteIrFetcher({required this.endpoint, HttpGet? client})
      : _client = client ?? _defaultGet;

  final Uri endpoint;
  final HttpGet _client;

  @override
  Future<Uint8List> fetch(String name) async {
    final uri = endpoint.replace(
      pathSegments: [...endpoint.pathSegments, '$name.sdui.json'],
    );
    return _client(uri);
  }

  static Future<Uint8List> _defaultGet(Uri uri) async {
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw StateError('GET $uri failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}
