import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'counter_minimal.sdui.g.dart';

class CounterData {
  const CounterData({required this.value, this.chips = const []});
  final int value;
  final List<int> chips;
}

@Screen('counter_minimal')
Widget counterMinimal(CounterData data) => Center(
      child: Text(
        '${data.value}',
        style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
      ),
    );
