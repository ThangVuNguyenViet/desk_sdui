import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'pattern_demo.sdui.g.dart';

sealed class PatternState {}

class PatternLoading extends PatternState {}

class PatternLoaded extends PatternState {
  PatternLoaded(this.items);
  final List<String> items;
}

class PatternController {
  PatternState state = PatternLoading();
}

@Screen('pattern_demo')
Widget patternDemo(PatternController vm) {
  return switch (vm.state) {
    PatternLoading() => const CircularProgressIndicator(),
    PatternLoaded(:final items) => Text('Got ${items.length} items'),
    _ => const SizedBox.shrink(),
  };
}
