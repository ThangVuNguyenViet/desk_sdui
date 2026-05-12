import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'let_demo.sdui.g.dart';

class LetDemoData {
  const LetDemoData({required this.title});
  final String title;
}

@Screen('let_demo')
Widget letDemo(LetDemoData data) {
  final title = data.title;
  final greeting = 'Hello, $title!';
  return Center(child: Text(greeting));
}
