import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'lambda_demo.sdui.g.dart';

class LambdaDemoData {
  const LambdaDemoData({required this.items});
  final List<String> items;
}

/// Demonstrates lambda usage: filters non-empty items and maps them to
/// upper-case, then renders each in a Column.
@Screen('lambda_demo')
Widget lambdaDemo(LambdaDemoData data) {
  final nonEmpty = data.items.where((x) => x.isNotEmpty).toList();
  return Column(
    children: [
      for (final item in nonEmpty) Text(item),
    ],
  );
}
