// Tests for key_infer_pass.dart
//
// Focuses on the NPE-guard fix: a destructured ForNode whose item type has no
// `id`/`uuid` field (so _synthesizeDestructuredKey returns null) must NOT
// crash and must produce a ForNode.destructured, not a ForNode (variable form).
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/key_infer_pass.dart';
import 'package:test/test.dart';

void main() {
  group('inferKeys – destructured ForNode fallthrough', () {
    // A lookupType that resolves variable names to a type with no id/uuid field.
    List<String>? noIdLookup(String loopVar) => ['name', 'value'];

    // A lookupType that returns null (type not found).
    List<String>? nullLookup(String loopVar) => null;

    test(
      'destructured ForNode with no-id type: result is ForNode.destructured, not a crash',
      () {
        final node = ForNode.destructured(
          variables: ['i', 'x'],
          source: RefNode(['items']),
          body: WidgetNode(name: 'Text', args: {'data': RefNode(['x'])}),
        );

        final result = inferKeys(node, lookupType: noIdLookup);

        // Must be a ForNode.destructured — variable must be null.
        expect(result, isA<ForNode>());
        final forNode = result as ForNode;
        expect(forNode.variable, isNull);
        expect(forNode.variables, equals(['i', 'x']));
      },
    );

    test(
      'destructured ForNode with null lookupType: result is ForNode.destructured',
      () {
        final node = ForNode.destructured(
          variables: ['idx', 'item'],
          source: RefNode(['data']),
          body: WidgetNode(name: 'Card', args: {'child': RefNode(['item'])}),
        );

        // No lookupType at all → _synthesizeDestructuredKey returns null.
        final result = inferKeys(node);

        expect(result, isA<ForNode>());
        final forNode = result as ForNode;
        expect(forNode.variable, isNull);
        expect(forNode.variables, equals(['idx', 'item']));
      },
    );

    test(
      'destructured ForNode with null-returning lookupType: result is ForNode.destructured',
      () {
        final node = ForNode.destructured(
          variables: ['i', 'v'],
          source: RefNode(['list']),
          body: WidgetNode(name: 'Tile', args: {'label': RefNode(['v'])}),
        );

        final result = inferKeys(node, lookupType: nullLookup);

        expect(result, isA<ForNode>());
        final forNode = result as ForNode;
        expect(forNode.variable, isNull);
        expect(forNode.variables, equals(['i', 'v']));
      },
    );

    // Sanity check: the single-variable fallthrough still works.
    test(
      'single-variable ForNode with no-id type: result is ForNode (variable form)',
      () {
        final node = ForNode(
          variable: 'item',
          source: RefNode(['items']),
          body: WidgetNode(name: 'Text', args: {'data': RefNode(['item'])}),
        );

        final result = inferKeys(node, lookupType: noIdLookup);

        expect(result, isA<ForNode>());
        final forNode = result as ForNode;
        expect(forNode.variable, equals('item'));
        expect(forNode.variables, isNull);
      },
    );
  });
}
