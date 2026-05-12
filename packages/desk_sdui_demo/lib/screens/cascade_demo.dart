import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'cascade_demo.sdui.g.dart';

class CascadeController {
  final TextEditingController controller = TextEditingController();
}

/// Demonstrates cascade lowering: `vm.controller..text = 'initial'` lowers to
/// a LetNode wrapping a SequenceNode whose single step is a setter MethodCallNode
/// named 'TextEditingController.text=' registered by the type collector.
@Screen('cascade_demo')
Widget cascadeDemo(CascadeController vm) {
  return TextField(
    controller: vm.controller..text = 'initial',
  );
}
