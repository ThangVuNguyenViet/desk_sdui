import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:desk_sdui/src/payload_class.dart';
import 'package:desk_sdui/src/runtime.dart';

void main() {
  group('PayloadMixin', () {
    setUp(() {
      clearPayloadClassesForTest();
    });

    test('Mixin method dispatch via MRO (rightmost priority)', () {
      // mixin Loggable { String tag() => 'log'; }
      final loggable = PayloadClass(
        name: 'Loggable',
        isMixin: true,
        methods: {
          'tag': PayloadFunctionNode(
            name: 'tag',
            params: [],
            body: LiteralNode('log'),
          ),
        },
      );
      registerPayloadMixin('Loggable', loggable);

      // class Order with Loggable { }
      final order = PayloadClass(
        name: 'Order',
        mixins: [loggable],
        methods: {},
        fieldInitializers: {},
        ctors: {},
      );
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: 'tag',
        args: {},
      );

      expect(evalExpression(node, {}, Runtime()), 'log');
    });

    test('Cannot instantiate mixin', () {
      final loggable = PayloadClass(
        name: 'Loggable',
        isMixin: true,
      );
      registerPayloadMixin('Loggable', loggable);

      final node = PayloadInstanceCreationNode(
        className: 'Loggable',
        args: {},
      );

      expect(
        () => evalExpression(node, {}, Runtime()),
        throwsA(isA<StateError>()),
      );
    });

    test('Mixin field initializer contributes to instance fields', () {
      final timestamped = PayloadClass(
        name: 'Timestamped',
        isMixin: true,
        fieldInitializers: {'createdAt': LiteralNode(42)},
        methods: {},
        ctors: {},
      );
      registerPayloadMixin('Timestamped', timestamped);

      final order = PayloadClass(
        name: 'Order',
        mixins: [timestamped],
        methods: {},
        fieldInitializers: {},
        ctors: {
          '': PayloadCtor(
            name: '',
            params: [],
            fieldInits: {},
          ),
        },
      );
      registerPayloadClass(order);

      final node = PayloadInstanceCreationNode(
        className: 'Order',
        args: {},
      );

      final inst = evalExpression(node, {}, Runtime()) as PayloadInstance;
      expect(inst.fields['createdAt']?.value, 42);
    });
  });
}
