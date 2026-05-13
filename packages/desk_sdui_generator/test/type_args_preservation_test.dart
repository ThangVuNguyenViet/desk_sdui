// Tests that typeArgs are forwarded through reactive_hoist_pass and
// key_infer_pass rewrites of MethodCallNode and ValueCtorNode.
//
// The reactive hoist pass rebuilds MethodCallNode/ValueCtorNode as it walks
// the tree; if it drops typeArgs the round-trip equality check will fail.
// Same for key_infer_pass.
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/key_infer_pass.dart';
import 'package:desk_sdui_generator/src/screen_lowering/reactive_hoist_pass.dart';
import 'package:test/test.dart';

void main() {
  group('typeArgs preserved through reactive_hoist_pass', () {
    test('MethodCallNode typeArgs survive hoist rewrite', () {
      // Build a WidgetNode whose arg is a MethodCallNode with typeArgs.
      // reactiveHoist rebuilds the MethodCallNode; it must keep typeArgs.
      const methodCall = MethodCallNode(
        receiver: RefNode(['vm']),
        name: 'fetch',
        args: [],
        typeArgs: ['MyModel'],
      );
      const widget = WidgetNode(
        name: 'Builder',
        args: {'child': methodCall},
      );

      final result = reactiveHoist(widget) as WidgetNode;
      final hoisted = result.args['child']! as MethodCallNode;

      // Key assertion: typeArgs must be preserved.
      expect(hoisted.typeArgs, equals(['MyModel']));
    });

    test('ValueCtorNode typeArgs survive hoist rewrite', () {
      const ctor = ValueCtorNode(
        name: 'List',
        args: [],
        typeArgs: ['String'],
      );
      const widget = WidgetNode(
        name: 'Builder',
        args: {'value': ctor},
      );

      final result = reactiveHoist(widget) as WidgetNode;
      final hoistedCtor = result.args['value']! as ValueCtorNode;

      // Key assertion: typeArgs must be preserved.
      expect(hoistedCtor.typeArgs, equals(['String']));
    });

    test('MethodCallNode with null typeArgs: null is preserved (not converted to empty)', () {
      const methodCall = MethodCallNode(
        receiver: RefNode(['vm']),
        name: 'load',
        args: [],
        // typeArgs: null (default)
      );
      const widget = WidgetNode(
        name: 'Builder',
        args: {'child': methodCall},
      );

      final result = reactiveHoist(widget) as WidgetNode;
      final hoisted = result.args['child']! as MethodCallNode;

      expect(hoisted.typeArgs, isNull);
    });
  });

  group('typeArgs preserved through key_infer_pass', () {
    test('MethodCallNode typeArgs survive inferKeys rewrite', () {
      const methodCall = MethodCallNode(
        receiver: RefNode(['api']),
        name: 'query',
        args: [],
        typeArgs: ['Result'],
      );
      const widget = WidgetNode(
        name: 'Builder',
        args: {'data': methodCall},
      );

      final result = inferKeys(widget) as WidgetNode;
      final inferred = result.args['data']! as MethodCallNode;

      // Key assertion: typeArgs must be preserved.
      expect(inferred.typeArgs, equals(['Result']));
    });

    test('ValueCtorNode typeArgs survive inferKeys rewrite', () {
      const ctor = ValueCtorNode(
        name: 'Map',
        args: [],
        typeArgs: ['String', 'int'],
      );
      const widget = WidgetNode(
        name: 'Builder',
        args: {'map': ctor},
      );

      final result = inferKeys(widget) as WidgetNode;
      final inferredCtor = result.args['map']! as ValueCtorNode;

      // Key assertion: multi-arg typeArgs must be preserved.
      expect(inferredCtor.typeArgs, equals(['String', 'int']));
    });
  });
}
