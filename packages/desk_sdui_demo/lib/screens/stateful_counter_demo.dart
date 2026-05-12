import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'stateful_counter_demo.sdui.g.dart';

/// Demo for Plan #11 (IrStatefulNode): a counter screen whose state lives
/// directly in the screen body — no separate ViewModel class.
///
/// The leading `var count = 0;` is recognized by the lowerer and emitted as
/// an `IrStatefulNode` field; the runtime host owns the cell across rebuilds
/// and the inline `onPressed` block-bodied lambda mutates it and triggers
/// `setState` so Flutter rebuilds the screen with the new value.
///
/// (Uses Center/Column/ElevatedButton rather than Scaffold/FloatingActionButton
/// so the registration emitter doesn't trip over private Flutter SDK
/// names referenced by those constructors' default-argument expressions.)
@Screen('stateful_counter_demo')
Widget statefulCounterDemo() {
  var count = 0;
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Count: $count',
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            count = count + 1;
          },
          child: const Text('+'),
        ),
      ],
    ),
  );
}
