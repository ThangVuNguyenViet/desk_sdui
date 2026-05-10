import 'json_decoder.dart';
import 'json_encoder.dart';
import '../ir_node.dart';

/// Public API for encoding/decoding IR nodes to/from JSON.
///
/// Use [encode] to serialize an [IrNode] to a map, and [decode] to
/// reconstruct an [IrNode] from a map.
class JsonIrCodec {
  const JsonIrCodec();

  final _encoder = const JsonIrEncoder();
  final _decoder = const JsonIrDecoder();

  /// Encodes an [IrNode] to a JSON-serializable map.
  Map<String, Object?> encode(IrNode node) => _encoder.encode(node);

  /// Decodes a JSON map back into an [IrNode].
  IrNode decode(Map<String, Object?> map) => _decoder.decode(map);
}
