import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'loop_demo.sdui.g.dart';

class LoopController {
  LoopController({required this.numbers});
  final List<int> numbers;
}

/// Demonstrates imperative C-style for-loop lowering (Feature 10).
///
/// Counts the number of positive integers in [vm.numbers] using an
/// ImperativeForNode. Exercises: LetStatementNode, ImperativeForNode,
/// IndexAccessNode, IfStatementNode, AssignNode, ReturnNode.
@Screen('loop_demo')
Widget loopDemo(LoopController vm) {
  var positives = 0;
  for (var i = 0; i < vm.numbers.length; i = i + 1) {
    if (vm.numbers[i] > 0) {
      positives = positives + 1;
    }
  }
  return Text('Positives: $positives');
}
