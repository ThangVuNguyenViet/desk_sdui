import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'payload_fn_demo.sdui.g.dart';

/// VM exposing a list of items for the demo to summarize.
class PayloadFnController {
  PayloadFnController({required this.items});
  final List<String> items;
}

/// Payload-private helper: pluralizes an item count into a label string.
/// This is a top-level function in the same file as the @Screen — the
/// codegen recognizes it as a payload function and lowers call sites in
/// the @Screen body to a [PayloadFunctionCallNode].
String describe(int count) {
  if (count == 0) return 'No items';
  if (count == 1) return '1 item';
  return '$count items';
}

@Screen('payload_fn_demo')
Widget payloadFnDemo(PayloadFnController vm) {
  return Text(describe(vm.items.length));
}
