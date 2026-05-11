import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_actions.dart'
    show CounterController;
import 'package:flutter/material.dart';

part 'themed_counter.sdui.g.dart';

@Screen('themed_counter')
Widget themedCounter(BuildContext context, CounterController vm) => Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${vm.value}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: vm.decrement, child: const Text('-')),
                const SizedBox(width: 16),
                ElevatedButton(onPressed: vm.increment, child: const Text('+')),
              ],
            ),
          ],
        ),
      ),
    );
