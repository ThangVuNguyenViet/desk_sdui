import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'imperative_demo.sdui.g.dart';

class ImpController {
  ImpController({required this.items});
  final List<String> items;
}

/// Demonstrates imperative block lowering: if/else + local binding + return.
/// Exercises BlockNode, IfStatementNode, ReturnNode, and LetStatementNode.
///
/// Note: the full count-with-for-loop version (using `for (final item in ...)`)
/// requires Feature 10 (statement-loops). That section is left as a
/// // SCAFFOLD comment until Feature 10 ships.
@Screen('imperative_demo')
Widget imperativeDemo(ImpController vm) {
  if (vm.items.isEmpty) {
    return const Text('No items');
  }
  final summary = '${vm.items.length} items';
  return Text(summary);
}
