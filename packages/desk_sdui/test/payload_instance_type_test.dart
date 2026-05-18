import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:desk_sdui/src/payload_class.dart';
import 'package:desk_sdui/src/runtime.dart';

void main() {
  group('PayloadInstance type tests', () {
    setUp(() {
      clearPayloadClassesForTest();
    });

    test('IsTypeNode returns true for own class', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {'id': Cell('x')},
      );

      final node = IsTypeNode(
        receiver: LiteralNode(instance),
        typeName: 'Order',
      );
      expect(evalExpression(node, {}, Runtime()), true);
    });

    test('IsTypeNode returns true for supertype', () {
      final parent = PayloadClass(name: 'Parent');
      registerPayloadClass(parent);

      final child = PayloadClass(name: 'Child', supertype: parent);
      registerPayloadClass(child);

      final instance = PayloadInstance(
        type: child,
        fields: {},
      );

      final node = IsTypeNode(
        receiver: LiteralNode(instance),
        typeName: 'Parent',
      );
      expect(evalExpression(node, {}, Runtime()), true);
    });

    test('IsTypeNode returns false for unrelated type', () {
      final a = PayloadClass(name: 'A');
      final b = PayloadClass(name: 'B');
      registerPayloadClass(a);
      registerPayloadClass(b);

      final instance = PayloadInstance(
        type: a,
        fields: {},
      );

      final node = IsTypeNode(
        receiver: LiteralNode(instance),
        typeName: 'B',
      );
      expect(evalExpression(node, {}, Runtime()), false);
    });

    test('AsTypeNode returns operand on match', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {'id': Cell('x')},
      );

      final node = AsTypeNode(
        operand: LiteralNode(instance),
        typeName: 'Order',
      );
      expect(evalExpression(node, {}, Runtime()), same(instance));
    });

    test('AsTypeNode throws TypeError on mismatch', () {
      final a = PayloadClass(name: 'A');
      final b = PayloadClass(name: 'B');
      registerPayloadClass(a);
      registerPayloadClass(b);

      final instance = PayloadInstance(
        type: a,
        fields: {},
      );

      final node = AsTypeNode(
        operand: LiteralNode(instance),
        typeName: 'B',
      );
      expect(
        () => evalExpression(node, {}, Runtime()),
        throwsA(isA<TypeError>()),
      );
    });

    test('AsTypeNode with nullable allows null', () {
      final node = AsTypeNode(
        operand: LiteralNode(null),
        typeName: 'Order',
        nullable: true,
      );
      expect(evalExpression(node, {}, Runtime()), null);
    });

    test('RuntimeTypeRefNode returns PayloadTypeValue', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {},
      );

      final node = RuntimeTypeRefNode(operand: LiteralNode(instance));
      final result = evalExpression(node, {}, Runtime());
      expect(result, isA<PayloadTypeValue>());
      expect((result as PayloadTypeValue).toString(), 'Order');
    });

    test('RuntimeTypeRefNode equality by class name', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance1 = PayloadInstance(type: order, fields: {});
      final instance2 = PayloadInstance(type: order, fields: {});

      final node1 = RuntimeTypeRefNode(operand: LiteralNode(instance1));
      final node2 = RuntimeTypeRefNode(operand: LiteralNode(instance2));

      final result1 = evalExpression(node1, {}, Runtime());
      final result2 = evalExpression(node2, {}, Runtime());

      expect(result1, equals(result2));
    });

    test('PayloadInstanceCreationNode with fields and ctor', () {
      final order = PayloadClass(
        name: 'Order',
        fieldInitializers: {},
        ctors: {
          '': PayloadCtor(
            name: '',
            params: ['id', 'total'],
            fieldInits: {
              'id': RefNode(['id']),
              'total': RefNode(['total']),
            },
          ),
        },
      );
      registerPayloadClass(order);

      final node = PayloadInstanceCreationNode(
        className: 'Order',
        args: {
          'id': LiteralNode('abc'),
          'total': LiteralNode(9.99),
        },
      );

      final result = evalExpression(node, {}, Runtime());
      expect(result, isA<PayloadInstance>());
      final instance = result as PayloadInstance;
      expect(instance.type.name, 'Order');
      expect(instance.fields['id']?.value, 'abc');
      expect(instance.fields['total']?.value, 9.99);
    });

    test('PayloadInstanceCreationNode with named ctor', () {
      final order = PayloadClass(
        name: 'Order',
        fieldInitializers: {},
        ctors: {
          'empty': PayloadCtor(
            name: 'empty',
            params: [],
            fieldInits: {
              'id': LiteralNode(''),
              'total': LiteralNode(0.0),
            },
          ),
        },
      );
      registerPayloadClass(order);

      final node = PayloadInstanceCreationNode(
        className: 'Order',
        ctorName: 'empty',
        args: {},
      );

      final result = evalExpression(node, {}, Runtime());
      expect(result, isA<PayloadInstance>());
      final instance = result as PayloadInstance;
      expect(instance.fields['id']?.value, '');
      expect(instance.fields['total']?.value, 0.0);
    });
  });
}
