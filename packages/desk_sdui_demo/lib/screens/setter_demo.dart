import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'setter_demo.sdui.g.dart';

@Register([SetterDemoController])
class SetterDemoController {
  int count = 0;
  String message = 'idle';
}

@Screen('setter_demo')
Widget setterDemo(SetterDemoController vm) {
  return Column(
    children: [
      Text('Count: ${vm.count}'),
      Text('Message: ${vm.message}'),
      ElevatedButton(
        onPressed: () {
          vm.count = vm.count + 1;
        },
        child: const Text('Increment'),
      ),
    ],
  );
}
