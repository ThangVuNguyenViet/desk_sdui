import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/src/loader/asset_bundle_ir_fetcher.dart';
import 'package:desk_sdui/src/loader/remote_ir_fetcher.dart';

void main() {
  group('AssetBundleIrFetcher', () {
    test('reads <prefix>/<name>.uib from bundle', () async {
      final bundle = _FakeBundle({
        'sdui/cart.uib':
            '{"name":"cart","version":1,"root":{"\$type":"literal","value":null}}',
      });
      final fetcher = AssetBundleIrFetcher(
        bundle: bundle,
        prefix: 'sdui',
      );
      final bytes = await fetcher.fetch('cart');
      expect(utf8.decode(bytes), contains('"name":"cart"'));
    });
  });

  group('RemoteIrFetcher', () {
    test('GETs <endpoint>/<name>.uib', () async {
      late Uri capturedUri;
      final fetcher = RemoteIrFetcher(
        endpoint: Uri.parse('https://api.example.com/sdui'),
        client: (uri) async {
          capturedUri = uri;
          return utf8.encode('{"ok":true}');
        },
      );
      final bytes = await fetcher.fetch('home');
      expect(
        capturedUri.toString(),
        'https://api.example.com/sdui/home.uib',
      );
      expect(utf8.decode(bytes), '{"ok":true}');
    });
  });
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._files);
  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final s = _files[key];
    if (s == null) throw FlutterError('not found: $key');
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(s)),
    );
  }
}
