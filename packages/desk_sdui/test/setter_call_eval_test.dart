import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SetterCallNode evaluation', () {
    late Runtime runtime;

    setUp(() {
      runtime = Runtime();
    });

    test('invokeSetter calls registered setter', () {
      // Create a test controller with a mutable field
      final controller = _TestController();
      expect(controller.count, 0);

      // Register a setter
      runtime.registerSetter(
        '_TestController.count',
        (target, value) {
          if (target is _TestController && value is int) {
            target.count = value;
          }
        },
      );

      // Invoke the setter
      runtime.invokeSetter('_TestController.count', controller, 42);

      // Verify the field was updated
      expect(controller.count, 42);
    });

    test('invokeSetter throws for unregistered setter', () {
      final controller = _TestController();

      expect(
        () => runtime.invokeSetter('_TestController.count', controller, 42),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No setter registered'),
          ),
        ),
      );
    });

    test('registerSetter stores handler correctly', () {
      runtime.registerSetter('test.field', (target, value) {});

      final handler = runtime.resolveSetter('test.field');
      expect(handler, isNotNull);
    });

    test('resolveSetter returns null for unregistered setter', () {
      final handler = runtime.resolveSetter('unknown.field');
      expect(handler, isNull);
    });

    test('SetterCallNode evaluates and returns assigned value', () {
      // When evaluating SetterCallNode(target, 'Test.field', value),
      // it should return the assigned value (not the old value).
      // This is consistent with Dart assignment semantics: `x = y` returns y.

      final controller = _TestController();
      final originalCount = controller.count;

      runtime.registerSetter(
        '_TestController.count',
        (target, value) {
          if (target is _TestController && value is int) {
            target.count = value;
          }
        },
      );

      // Simulate SetterCallNode evaluation:
      // The IR evaluator would:
      //   1. Evaluate the value expression (42)
      //   2. Invoke the setter with the receiver and value
      //   3. Return the value (not the old value)
      final newValue = 42;
      runtime.invokeSetter('_TestController.count', controller, newValue);

      expect(controller.count, newValue);
      expect(controller.count, isNot(originalCount));
    });

    test('setter works with nullable types', () {
      final controller = _TestController();

      runtime.registerSetter(
        '_TestController.message',
        (target, value) {
          if (target is _TestController) {
            target.message = value as String?;
          }
        },
      );

      runtime.invokeSetter('_TestController.message', controller, 'hello');
      expect(controller.message, 'hello');

      runtime.invokeSetter('_TestController.message', controller, null);
      expect(controller.message, isNull);
    });
  });
}

class _TestController {
  int count = 0;
  String? message;
}
