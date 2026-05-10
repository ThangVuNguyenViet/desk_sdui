import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';

void main() {
  group('InputBinding', () {
    test('stores name and reader', () {
      final binding = InputBinding<int>(
        name: 'count',
        read: (input) => input! as int,
      );
      expect(binding.name, 'count');
      expect(binding.read(42), 42);
    });
  });

  group('Runtime', () {
    test('register and look up widget', () {
      final rt = Runtime();
      rt.registerWidget('Sentinel', (ctx, args) => const SizedBox());
      expect(rt.widgetFor('Sentinel'), isNotNull);
    });

    test('register and look up fn', () {
      final rt = Runtime();
      rt.registerFn('double', (int x) => x * 2);
      final fn = rt.fnFor('double');
      expect(fn, isNotNull);
      expect(Function.apply(fn!, [3]), 6);
    });

    test('register and look up screen', () {
      final rt = Runtime();
      const binding = ScreenBinding(
        name: 'home',
        ir: IrTree(name: 'home', version: 1, root: LiteralNode(null)),
        inputs: [],
      );
      rt.registerScreen(binding);
      expect(rt.screenFor('home')?.name, 'home');
    });
  });
}
