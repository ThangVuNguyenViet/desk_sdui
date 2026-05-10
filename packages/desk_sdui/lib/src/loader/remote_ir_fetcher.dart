import 'package:http/http.dart' as http;
import 'ir_fetcher.dart';

typedef HttpGet = Future<List<int>> Function(Uri uri);

class RemoteIrFetcher implements IrFetcher {
  RemoteIrFetcher({required this.endpoint, HttpGet? client})
      : _client = client ?? _defaultGet;

  final Uri endpoint;
  final HttpGet _client;

  @override
  Future<List<int>> fetch(String name) async {
    final uri = endpoint.replace(
      pathSegments: [...endpoint.pathSegments, '$name.uib'],
    );
    return _client(uri);
  }

  static Future<List<int>> _defaultGet(Uri uri) async {
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw StateError('GET $uri failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}
