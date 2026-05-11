import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

part 'counter_math.sdui.g.dart';

@Screen('counter_math')
Widget counterMath(CounterData data) {
  return Center(
    child: Text(
      '${(data.value * 2 + 1) ~/ 3}',
      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
    ),
  );
}
