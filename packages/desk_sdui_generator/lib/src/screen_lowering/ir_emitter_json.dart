import 'dart:convert';

import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

List<int> emitJson(IrTree tree) {
  final codec = const JsonIrCodec();
  final map = <String, Object?>{
    'name': tree.name,
    'version': tree.version,
    'root': _encodeNode(codec, tree.root),
  };
  return utf8.encode(jsonEncode(map));
}

Map<String, Object?> _encodeNode(JsonIrCodec codec, IrNode node) {
  if (node is ConstNode) {
    final demoted = _demoteConst(node);
    return codec.encode(demoted);
  }
  return codec.encode(node);
}

IrNode _demoteConst(ConstNode node) {
  return WidgetNode(name: 'ConstPlaceholder', args: {}, key: null);
}
