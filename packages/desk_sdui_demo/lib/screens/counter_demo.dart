import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'counter_demo.sdui.g.dart';

/// Mutable VM with various field types exercising @Register.
@Register([Counter, CounterActions])
class Counter {
  int count = 0;
  int step = 1;
  List<int> history = [];
  bool busy = false;
  String mode = 'add';
}

/// Actions class exercising async patterns and stateful operations.
class CounterActions {
  final ValueNotifier<Counter> _notifier;

  CounterActions(this._notifier);

  void _notify() {
    _notifier.value = _notifier.value;
  }

  Future<void> save(Counter c) async {
    c.busy = true;
    _notify();
    await Future.delayed(const Duration(milliseconds: 100));
    c.busy = false;
    _notify();
  }

  void reset(Counter c) {
    c.count = 0;
    c.step = 1;
    c.history = [];
    c.mode = 'add';
    _notify();
  }

  void incrementCount(Counter c) {
    c.count = c.count + 1;
    _notify();
  }

  void setMode(Counter c, String m) {
    c.mode = m;
    _notify();
  }

  void setStep(Counter c, int s) {
    c.step = s;
    _notify();
  }

  void decrementCount(Counter c) {
    c.count = c.count - c.step;
    _notify();
  }

  void handleSaveError(Counter c) {
    c.mode = 'error';
    _notify();
  }
}

/// Payload function: used later in the screen.
int tripled(int x) => x * 3;

@Screen('counter_demo')
Widget counterDemo(BuildContext context, Counter c, CounterActions a) {
  /// Mutable local variable (reassigned).
  var label = 'Counter';
  label = '${c.count}';

  /// Let bindings (immutable locals).
  final theme = Theme.of(context);
  final doubled = c.count * 2;
  final tripled_val = tripled(c.count);

  /// Pattern matching (switch expression).
  final status = switch (c.mode) {
    'add' => 'Adding',
    'sub' => 'Subtracting',
    _ => 'Idle',
  };

  /// C-style for loop to compute sum.
  var historySum = 0;
  for (var i = 0; i < c.history.length; i = i + 1) {
    historySum = historySum + c.history[i];
  }

  /// While loop to build countdown.
  var countdown = 5;
  var countdownStr = '';
  while (countdown > 0) {
    countdownStr = '$countdownStr$countdown,';
    countdown = countdown - 1;
  }

  return Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          /// Display counter value.
          Text(label, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Mode: $status', style: theme.textTheme.labelLarge),
          const SizedBox(height: 16),

          /// Show derived values.
          Text('Doubled: $doubled'),
          Text('Tripled: $tripled_val'),
          Text('Sum: $historySum'),
          const SizedBox(height: 16),

          /// Increment buttons: compound += and plain setter (via methods).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                /// Plain setter via method
                onPressed: () => a.decrementCount(c),
                child: const Text('-'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                /// Compound += on registered field via method
                onPressed: () => a.incrementCount(c),
                child: const Text('+'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// Step control buttons: expression-bodied lambdas.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => a.setStep(c, 1),
                child: const Text('Step +1'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => a.setStep(c, 5),
                child: const Text('Step +5'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// Mode toggle: expression-bodied lambdas.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => a.setMode(c, 'add'),
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => a.setMode(c, 'sub'),
                child: const Text('Sub'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// Add to history and increment count (via method).
          ElevatedButton(
            onPressed: () => a.incrementCount(c),
            child: const Text('Add to history'),
          ),
          const SizedBox(height: 16),

          /// Save button with async / try-catch.
          ElevatedButton(
            onPressed: () async {
              try {
                await a.save(c);
              } catch (e) {
                a.handleSaveError(c);
              }
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 12),

          /// Reset button.
          ElevatedButton(
            onPressed: () => a.reset(c),
            child: const Text('Reset'),
          ),
          const SizedBox(height: 16),

          /// History display with for-in loop.
          if (c.history.isNotEmpty)
            Column(
              children: [
                const Text('History:'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final v in c.history) Text('$v,'),
                  ],
                ),
              ],
            )
          else
            const Text('(empty)'),
          const SizedBox(height: 8),

          /// Countdown from while loop.
          Text('Countdown: $countdownStr'),
        ],
      ),
    ),
  );
}
