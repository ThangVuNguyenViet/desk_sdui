import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

part 'counter_shorthand.sdui.g.dart';

@Screen('counter_shorthand')
Widget counterShorthand(CounterData data) => Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          '${data.value}',
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
        ),
      ),
    );
