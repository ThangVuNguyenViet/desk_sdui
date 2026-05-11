import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'counter_actions.sdui.g.dart';

class CounterController extends ChangeNotifier {
  int _value = 0;
  int get value => _value;

  void increment() {
    _value++;
    notifyListeners();
  }

  void decrement() {
    _value--;
    notifyListeners();
  }
}

@Screen('counter_actions')
Widget counterActions(CounterController vm) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${vm.value}',
            style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
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
    );
