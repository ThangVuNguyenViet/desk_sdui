import 'package:flutter/services.dart';
import 'ir_fetcher.dart';

class AssetBundleIrFetcher implements IrFetcher {
  AssetBundleIrFetcher({required this.bundle, this.prefix = 'sdui'});
  final AssetBundle bundle;
  final String prefix;

  @override
  Future<List<int>> fetch(String name) async {
    final key = '$prefix/$name.uib';
    final data = await bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
