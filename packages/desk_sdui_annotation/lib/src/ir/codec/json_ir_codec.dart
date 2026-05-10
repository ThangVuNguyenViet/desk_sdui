import 'dart:convert';

import 'json_decoder.dart';
import 'json_encoder.dart';
import '../ir_node.dart';
import '../ir_tree.dart';

class JsonIrCodec {
  const JsonIrCodec();

  final _encoder = const JsonIrEncoder();
  final _decoder = const JsonIrDecoder();

  Map<String, Object?> encode(IrNode node) => _encoder.encode(node);

  IrNode decode(Map<String, Object?> map) => _decoder.decode(map);

  IrTree decodeBytes(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final name = json['name']! as String;
    final version = json['version']! as int;
    final root = decode(json['root']! as Map<String, Object?>);
    return IrTree(name: name, version: version, root: root);
  }
}
